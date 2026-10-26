/// 源论坛 (Discuz! X3.5) 接口封装。
///
/// 站点没有公开 JSON API，因此全部通过解析 HTML 实现；
/// 所有选择器都在 recon/ 抓取的真实页面上做过离线回归。
library;

import 'dart:math' as math;

import '../core/discuz_client.dart';
import '../models/models.dart';
import 'parsers.dart';

class ForumApi {
  ForumApi(this.client);

  final DiscuzClient client;

  // ---------------------------------------------------------------- 版块

  Future<List<BoardGroup>> boards() async {
    final r = await client.get('forum.php');
    final groups = parseBoards(r.body);
    if (groups.isEmpty) {
      throw ForumException('未能解析版块列表，站点模板可能已更新');
    }
    return groups;
  }

  Future<ThreadPage> threads({required int fid, int page = 1}) async {
    final r = await client.get('forum-$fid-$page.html', referer: '$kBaseUrl/forum-$fid-1.html');
    final tp = parseThreadList(r.body, page: page);
    return ThreadPage(
      items: [
        for (final t in tp.items)
          t.fid == null
              ? ThreadItem(
                  tid: t.tid,
                  title: t.title,
                  url: t.url,
                  author: t.author,
                  authorId: t.authorId,
                  avatar: t.avatar,
                  replies: t.replies,
                  views: t.views,
                  timeText: t.timeText,
                  typeName: t.typeName,
                  hasAttachment: t.hasAttachment,
                  isSticky: t.isSticky,
                  fid: fid,
                )
              : t,
      ],
      page: tp.page,
      totalPages: tp.totalPages,
    );
  }

  /// view: newthread(最新发表) / hot(最新热门) / new(最新回复) / digest(最新精华)
  Future<ThreadPage> guide(String view, {int page = 1}) async {
    final r = await client.get('forum.php?mod=guide&view=$view&page=$page');
    return parseThreadList(r.body, page: page);
  }

  Future<List<ThreadItem>> search(String keyword, {int page = 1}) async {
    final kw = Uri.encodeQueryComponent(keyword);
    final r = await client.get(
      'plugin.php?id=twpx_xunsearch&q=$kw&m=&syn=yes&f=_all&s=relevance&fid=0&p=$page',
      referer: '$kBaseUrl/forum.php',
    );
    final parsed = parseXunsearchResults(r.body, page: page);
    if (parsed.items.isEmpty && r.body.contains('两次搜索')) {
      throw ForumException('搜索太频繁，请稍后再试');
    }
    return parsed.items;
  }

  // ---------------------------------------------------------------- 帖子

  Future<ThreadDetail> thread(int tid, {int page = 1, String? title}) async {
    final r = await client.get('thread-$tid-$page-1.html');
    final d = parseThread(r.body, tid: tid, page: page);
    return ThreadDetail(
      tid: d.tid,
      fid: d.fid,
      title: d.title.isEmpty ? (title ?? '帖子') : d.title,
      posts: d.posts,
      page: d.page,
      totalPages: d.totalPages,
      lockedText: d.lockedText,
      needsReply: d.needsReply,
      needsPurchase: d.needsPurchase,
      needsLogin: d.needsLogin,
      isLocked: d.isLocked,
      payUrl: d.payUrl,
      payPriceText: d.payPriceText,
      payBuyers: d.payBuyers,
      supportUrl: d.supportUrl,
      supportCount: d.supportCount,
      favoriteUrl: d.favoriteUrl,
    );
  }

  /// 应用内购买付费主题。
  ///
  /// Discuz 流程：GET `forum.php?mod=misc&action=pay&tid=&pid=` 弹窗页 →
  /// 解析 formhash 与表单 action → POST `paysubmit=yes` →
  /// 重新拉取帖子验证是否解锁（最终以此为准，不依赖弹窗文案）。
  Future<BuyResult> buyThread(ThreadDetail d) async {
    final payUrl = d.payUrl;
    if (payUrl == null) {
      return const BuyResult(success: false, message: '该主题没有购买入口');
    }
    final referer = '$kBaseUrl/thread-${d.tid}-1-1.html';

    // 1. 打开购买弹窗（与浏览器 showWindow 一致：infloat + handlekey + inajax），
    //    响应为 <root> 包裹的确认表单，取 formhash 与提交地址
    final dialogUrl =
        payUrl.contains('infloat=') ? payUrl : '$payUrl&infloat=yes&handlekey=pay&inajax=1';
    final dialog = await client.get(dialogUrl, referer: referer);
    final body = dialog.body;
    if (looksLoggedOut(body) ||
        dialog.url.toString().contains('mod=logging') ||
        body.contains('guestmessage')) {
      return const BuyResult(success: false, message: '购买前请先登录');
    }
    final fh = parseFormhash(body);
    if (fh == null) {
      // 弹窗不是表单而是站点消息：已购买过 / 余额不足 / 权限不足等，透传原文
      final tip = parseAjaxMessage(body);
      if (tip.contains('购买过') || tip.contains('已经购买')) {
        return BuyResult(success: true, alreadyOwned: true, message: _shorten(tip));
      }
      if (tip.contains('余额') || tip.contains('不足') || tip.contains('权限')) {
        return BuyResult(success: false, message: tip.isEmpty ? '余额不足或无购买权限' : _shorten(tip));
      }
      return BuyResult(
        success: false,
        message: tip.isEmpty ? '无法获取购买令牌，请稍后重试' : _shorten(tip),
      );
    }

    // 表单 action 里一般带 paysubmit=yes；缺失则补上。
    // 注意：Discuz 的 pay 表单 action（forum/pay.htm）是
    //   forum.php?mod=misc&action=pay&paysubmit=yes&infloat=yes
    // 本身不含 tid —— tid 由表单隐藏域 POST。因此无论 action 是否带 tid，
    // 都要在 URL 与 body 双侧补齐，否则服务端 $_G['tid'] 为空，
    // 会报「指定的主题不存在或已被删除或正在被审核」。
    String action = '';
    final formRe = RegExp(r'''<form[^>]+action=["']([^"']+)["'][^>]*>''');
    for (final f in formRe.allMatches(body)) {
      final a = f.group(1)!.replaceAll('&amp;', '&');
      if (a.contains('action=pay')) {
        action = a;
        break;
      }
    }
    if (action.isEmpty) {
      action = 'forum.php?mod=misc&action=pay&paysubmit=yes&infloat=yes';
    }
    if (!action.contains('paysubmit=')) {
      action = action.contains('?') ? '$action&paysubmit=yes' : '$action?paysubmit=yes';
    }
    if (!action.contains('tid=')) {
      action = '$action&tid=${d.tid}';
    }
    if (!action.contains('inajax=')) action = '$action&inajax=1';

    // 2. 提交购买（tid 必须带：服务端 loadforum() 从 GET/POST 读 tid 加载主题）
    final submitUrl = action.startsWith('http') ? action : '$kBaseUrl/$action';
    final r = await client.post(
      submitUrl,
      {
        'formhash': fh,
        'paysubmit': 'yes',
        'handlekey': 'pay',
        'tid': '${d.tid}',
        'referer': '$kBaseUrl/thread-${d.tid}-1-1.html',
      },
      referer: referer,
    );
    final msg = parseAjaxMessage(r.body);
    final okByMsg =
        msg.contains('成功') || msg.contains('已经购买') || msg.contains('购买过');

    // 3. 重新拉帖验证：购买入口消失、正文回到 #postmessage 即视为已解锁
    try {
      final check = await client.get('thread-${d.tid}-1-1.html', referer: '$kBaseUrl/forum.php');
      final re = parseThread(check.body, tid: d.tid, page: 1);
      if (!re.needsPurchase) {
        return BuyResult(
          success: true,
          alreadyOwned: msg.contains('已经购买') || msg.contains('购买过'),
          message: okByMsg ? _shorten(msg) : '购买成功，内容已解锁',
        );
      }
    } catch (_) {
      // 校验只是加分项：拉帖失败时用站点回调文案兜底，别把成功误判成失败
    }

    // 站点已明确返回成功回调（succeedhandle_*('…', '主题购买成功', {})）
    if (okByMsg) {
      return BuyResult(success: true, message: msg.isEmpty ? '购买成功，内容已解锁' : _shorten(msg));
    }
    if (msg.contains('余额') || msg.contains('不足') || msg.contains('积分')) {
      return BuyResult(success: false, message: _shorten(msg));
    }

    return BuyResult(
      success: false,
      message: msg.isEmpty ? '购买未完成，请稍后在网页端重试' : _shorten(msg),
    );
  }

  Future<ReplyResult> reply({
    required int tid,
    required int fid,
    required String message,
    String? formhash,
  }) async {
    // 回复必须带上页面里 fastpostform 的完整参数（extra / handlekey / posttime），
    // 否则 Discuz 会走到「来路不正确」或直接不认这次提交。
    final page = await client.get('thread-$tid-1-1.html', referer: '$kBaseUrl/forum.php');
    if (looksLoggedOut(page.body)) {
      return const ReplyResult(success: false, message: '登录状态已失效，请重新登录');
    }
    final form = parseReplyForm(page.body);
    final fh = formhash ?? form?.formhash ?? parseFormhash(page.body);
    if (fh == null) {
      return const ReplyResult(success: false, message: '无法获取回复令牌，请刷新后重试');
    }

    final baseAction = form?.action ??
        'forum.php?mod=post&action=reply&fid=$fid&tid=$tid'
            '&extra=page%3D1&replysubmit=yes&infloat=yes&handlekey=fastpost';
    final url = baseAction.contains('inajax=') ? baseAction : '$baseAction&inajax=1';

    final r = await client.post(
      url,
      {
        'formhash': fh,
        'message': message,
        'subject': '  ',
        'usesig': '1',
        if (form?.posttime != null) 'posttime': form!.posttime!,
      },
      referer: '$kBaseUrl/thread-$tid-1-1.html',
    );

    final msg = parseAjaxMessage(r.body);
    final ok = r.body.contains('succeedhandle_fastpost') ||
        r.body.contains('succeedhandle_reply') ||
        r.body.contains('succeedhandle_post') ||
        msg.contains('回复发布成功') ||
        msg.contains('感谢您的回复') ||
        msg.contains('发布成功');

    if (ok) {
      // 需要审核时站点也会返回成功回调，单独提示一下
      final pending = msg.contains('审核');
      return ReplyResult(
        success: true,
        message: pending ? '回复已提交，等待审核通过' : '回复成功',
      );
    }
    if (msg.contains('验证码') || msg.contains('seccode') || msg.contains('安全验证')) {
      return const ReplyResult(
        success: false,
        message: '站点要求输入验证码，请到网页端回复一次后重试',
        needCaptcha: true,
      );
    }
    if (msg.contains('登录') || msg.contains('游客')) {
      return const ReplyResult(success: false, message: '登录状态已失效，请重新登录');
    }
    return ReplyResult(
      success: false,
      message: msg.isEmpty ? '回复失败，站点未返回提示，请稍后重试' : msg,
    );
  }

  // ---------------------------------------------------------------- 点赞 / 收藏

  /// 点赞（Discuz「支持/顶一下」）。
  ///
  /// [url] 来自帖子页 `a[href*="action=recommend&do=add"]`，已带 tid 与 hash。
  /// 成功响应没有 succeedhandle，只有 `errorhandle_recommend('评价指数 5 +1', …)`
  /// 与 `recommentc` 计数节点；失败则是 `alert_error` + 文案。
  Future<SiteActionResult> supportThread(String url) async {
    final r = await client.get(_withInajax(url), referer: '$kBaseUrl/forum.php');
    final body = r.body;
    if (looksLoggedOut(body)) {
      return const SiteActionResult(success: false, message: '点赞前请先登录');
    }
    final msg = parseAjaxMessage(body);
    if (msg.contains('已评价') || msg.contains('已经支持') || msg.contains('已支持')) {
      return const SiteActionResult(success: true, message: '已支持过本帖');
    }
    // 成功走专用回调：errorhandle_recommend('评价指数 5 +1', {...})。
    // 失败（hash 过期 / 来路不正确）走 alert_error，因此用回调名判定。
    if (body.contains('errorhandle_recommend') ||
        (body.contains('recommentc') && !body.contains('alert_error'))) {
      return const SiteActionResult(success: true, message: '已支持');
    }
    if (msg.contains('登录') || msg.contains('游客')) {
      return const SiteActionResult(success: false, message: '登录状态已失效，请重新登录');
    }
    return SiteActionResult(
      success: false,
      message: msg.isEmpty ? '点赞失败，站点未返回提示' : _shorten(msg),
    );
  }

  /// 收藏帖子。
  ///
  /// [url] 来自帖子页 `a[href*="ac=favorite&type=thread"]`，已带 formhash。
  /// 成功响应：`succeedhandle_('…', '信息收藏成功 ', {'id':…, 'favid':…})`。
  Future<SiteActionResult> favoriteThread(String url) async {
    final r = await client.get(_withInajax(url), referer: '$kBaseUrl/forum.php');
    final body = r.body;
    if (looksLoggedOut(body)) {
      return const SiteActionResult(success: false, message: '收藏前请先登录');
    }
    final msg = parseAjaxMessage(body);
    if (msg.contains('收藏成功')) {
      return const SiteActionResult(success: true, message: '收藏成功');
    }
    if (msg.contains('已经收藏') || msg.contains('已收藏')) {
      return const SiteActionResult(success: true, message: '已收藏过本帖');
    }
    if (msg.contains('登录') || msg.contains('游客')) {
      return const SiteActionResult(success: false, message: '登录状态已失效，请重新登录');
    }
    return SiteActionResult(
      success: false,
      message: msg.isEmpty ? '收藏失败，站点未返回提示' : _shorten(msg),
    );
  }

  /// 站点弹窗接口统一带 inajax=1（等价于 showWindow 的 AJAX 请求）。
  String _withInajax(String url) => url.contains('inajax=') ? url : '$url&inajax=1';

  // ---------------------------------------------------------------- 发帖

  /// 打开版块发帖页，取 `form#postform` 的 action、formhash、posttime 与分类。
  Future<PostForm> newThreadForm(int fid) async {
    final page = await client.get(
      'forum.php?mod=post&action=newthread&fid=$fid',
      referer: '$kBaseUrl/forum-$fid-1.html',
    );
    if (looksLoggedOut(page.body)) {
      return const PostForm(
        canPost: false,
        notice: '登录状态已失效，请重新登录',
      );
    }
    return parsePostForm(page.body);
  }

  /// 发表新主题。
  ///
  /// 与回复一样必须复用页面表单里的 action（含 `extra` / `topicsubmit`）
  /// 和 `formhash` / `posttime`，否则 Discuz 会判定「来路不正确」。
  Future<NewThreadResult> postNewThread({
    required int fid,
    required String subject,
    required String message,
    int? typeId,
  }) async {
    final title = subject.trim();
    if (title.isEmpty) {
      return const NewThreadResult(success: false, message: '请填写标题');
    }
    if (message.trim().isEmpty) {
      return const NewThreadResult(success: false, message: '请填写正文');
    }

    final form = await newThreadForm(fid);
    if (!form.canPost) {
      return NewThreadResult(
        success: false,
        message: form.notice ?? '当前账号在该版块没有发帖权限',
      );
    }
    final fh = form.formhash;
    if (fh == null || fh.isEmpty) {
      return const NewThreadResult(success: false, message: '无法获取发帖令牌，请刷新后重试');
    }

    final baseAction = form.action ??
        'forum.php?mod=post&action=newthread&fid=$fid&extra=&topicsubmit=yes';
    final url =
        baseAction.contains('inajax=') ? baseAction : '$baseAction&inajax=1';

    final r = await client.post(
      url,
      {
        'formhash': fh,
        if (form.posttime != null) 'posttime': form.posttime!,
        'subject': title,
        'message': message,
        'typeid': '${typeId ?? 0}',
        'usesig': '1',
        'wysiwyg': '0',
        'save': '',
      },
      referer: '$kBaseUrl/forum.php?mod=post&action=newthread&fid=$fid',
    );
    return parseNewThreadResult(r.body);
  }

  // ---------------------------------------------------------------- 账号

  Future<LoginResult> login(
    String username,
    String password, {
    int questionId = 0,
    String answer = '',
  }) async {
    final page = await client.get('member.php?mod=logging&action=login');
    final fh = parseFormhash(page.body);
    final lh = parseLoginhash(page.body);
    if (fh == null) {
      return const LoginResult(success: false, message: '无法获取登录令牌，请稍后重试');
    }
    final r = await client.post(
      'member.php?mod=logging&action=login&loginsubmit=yes&handlekey=login'
      '${lh != null ? '&loginhash=$lh' : ''}&inajax=1',
      {
        'formhash': fh,
        'referer': '$kBaseUrl/',
        'loginfield': 'username',
        'username': username,
        'password': password,
        'questionid': '$questionId',
        'answer': answer,
        'cookietime': '2592000',
      },
      referer: '$kBaseUrl/member.php?mod=logging&action=login',
    );
    final msg = parseAjaxMessage(r.body);
    final ok = msg.contains('欢迎您回来') ||
        msg.contains('现在将转入') ||
        msg.contains('登录成功') ||
        r.body.contains('succeedhandle_login');
    if (ok) return const LoginResult(success: true, message: '登录成功');
    return LoginResult(
      success: false,
      message: msg.isEmpty ? '登录失败，请检查账号密码' : msg,
      remainingAttempts: parseRemainingAttempts(msg),
    );
  }

  /// 拉取当前登录用户资料；未登录返回 null
  ///
  /// 两步：
  ///  1. 打开资料页拿到 UID（`discuz_uid` / 跳转 URL / 头部用户链接任一）；
  ///  2. 用移动端 JSON 接口取**准确的积分与社区统计** —— 与
  ///     `spacecp&ac=credit&showcredit=1`（星币 / 经验 / 积分）和
  ///     `space-uid-N.html`（帖子 / 关注 / 粉丝）同源，但不需要正则猜模板。
  /// 接口失败时退回第 1 步页面的 HTML 解析。
  Future<UserProfile?> me() async {
    final r = await client.get('home.php?mod=space&do=profile');
    final url = r.url.toString();
    if (url.contains('mod=logging') || r.body.contains('请先登录')) return null;
    final header = parseHeaderUser(r.body);
    final fromUrl = RegExp(r'space-uid-(\d+)').firstMatch(url)?.group(1);
    final uid = int.tryParse(fromUrl ?? '') ?? parseDiscuzUid(r.body) ?? header?.uid;
    if (uid == null && header == null && !looksLoggedIn(r.body)) return null;

    // 先按 HTML 解析，作为兜底 + 头像 / 用户组来源
    final html = parseProfile(r.body, fallbackUid: uid, fallbackName: header?.name);

    if (uid != null && uid > 0) {
      final api = await userStats(uid);
      // 接口值优先；头像 / 用户组 / 签名等接口没有的字段由 HTML 兜底补齐
      if (api != null) return api.mergeMissingFrom(html);
    }
    return html;
  }

  /// 取指定用户的积分与统计（移动端接口，无需额外登录态）。
  ///
  /// 返回 null 表示接口不可用 / 返回体不是预期结构，调用方应走 HTML 兜底。
  Future<UserProfile?> userStats(int uid) async {
    if (uid <= 0) return null;
    try {
      final r = await client.get(
        'api/mobile/index.php?version=4&module=profile&uid=$uid',
        referer: '$kBaseUrl/home.php?mod=space&uid=$uid',
        // 不吸收 Set-Cookie：接口会重新下发 saltkey，避免干扰已登录会话
        absorbCookies: false,
      );
      if (r.statusCode != 200) return null;
      return parseProfileApi(r.body, fallbackUid: uid);
    } catch (_) {
      return null;
    }
  }

  /// 任意 UID 的公开资料：JSON 优先，空间页 HTML 补用户组 / 等级 / 头像。
  Future<UserProfile> userProfile(int uid) async {
    if (uid <= 0) {
      throw ForumException('该用户不存在或空间不可见');
    }
    final results = await Future.wait<Object?>([
      userStats(uid),
      client.get(
        'home.php?mod=space&uid=$uid&do=profile',
        referer: '$kBaseUrl/home.php?mod=space&uid=$uid',
      ),
    ]);
    final api = results[0] as UserProfile?;
    final r = results[1] as DResponse;
    if (isUserSpaceMissing(r.body)) {
      throw ForumException('该用户不存在或空间不可见');
    }
    final html = r.statusCode == 200 ? parseProfile(r.body, fallbackUid: uid) : null;
    UserProfile? merged = api?.mergeMissingFrom(html) ?? html;
    if (merged == null) {
      throw ForumException('未能加载该用户资料');
    }
    if (merged.avatar == null || merged.avatar!.contains('noavatar')) {
      merged = merged.copyWith(avatar: avatarUrlFromUid(uid));
    }
    return merged;
  }

  /// 目标用户发表的主题列表。
  Future<ThreadPage> userThreads({required int uid, int page = 1}) async {
    if (uid <= 0) {
      return const ThreadPage(items: [], page: 1, totalPages: 1);
    }
    final r = await client.get(
      'home.php?mod=space&uid=$uid&do=thread&view=me&from=space&order=dateline&page=$page',
      referer: '$kBaseUrl/home.php?mod=space&uid=$uid',
    );
    if (isUserSpaceMissing(r.body)) {
      throw ForumException('该用户不存在或空间不可见');
    }
    if (isLoginRequired(r.body)) {
      throw ForumException('登录后才能查看该用户发表的主题');
    }
    return parseUserThreadList(r.body, page: page);
  }

  // ---------------------------------------------------------------- 签到

  Future<SignStatus> signStatus() async {
    final r = await client.get('k_misign-sign.html', referer: '$kBaseUrl/forum.php');
    return parseSignPage(r.body);
  }

  Future<SignResult> sign({String? formhash}) async {
    final page = await client.get('k_misign-sign.html', referer: '$kBaseUrl/forum.php');
    final status = parseSignPage(page.body);
    if (status.signedToday) {
      return const SignResult(success: true, message: '今天已经签过到了');
    }
    final fh = formhash ?? parseFormhash(page.body);
    if (fh == null) {
      return const SignResult(success: false, message: '登录状态已失效，请重新登录');
    }
    final r = await client.post(
      'plugin.php?id=k_misign:sign&operation=qiandao&format=button&formhash=$fh',
      const {},
      referer: '$kBaseUrl/k_misign-sign.html',
    );
    final msg = parseAjaxMessage(r.body);
    final ok = msg.contains('签到成功') ||
        msg.contains('今日已签') ||
        msg.contains('恭喜') ||
        msg.contains('已经签到') ||
        msg.contains('已签到') ||
        r.body.contains('qiandao_success');
    if (ok) {
      return SignResult(success: true, message: msg.isEmpty ? '签到成功' : _shorten(msg));
    }
    if (msg.contains('登录') || msg.contains('游客')) {
      return const SignResult(success: false, message: '登录状态已失效，请重新登录');
    }
    return SignResult(success: false, message: msg.isEmpty ? '签到失败，请稍后重试' : _shorten(msg));
  }

  String _shorten(String s) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length > 60 ? '${t.substring(0, 60)}…' : t;
  }

  // ---------------------------------------------------------------- 工具

  /// 站点当前时间戳（用于避免时区问题），失败则用本地时间
  Future<DateTime> serverNow() async {
    try {
      final r = await client.get('forum.php');
      final m = RegExp(r'现在时间是\s*([\d\-: ]+)').firstMatch(r.body);
      if (m != null) return DateTime.tryParse(m.group(1)!.trim()) ?? DateTime.now();
    } catch (_) {}
    return DateTime.now();
  }

  static int estimatePage(int totalPages) => math.max(1, totalPages);
}
