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

  Future<List<ThreadItem>> search(String keyword) async {
    final home = await client.get('forum.php');
    final fh = parseFormhash(home.body);
    if (fh == null) throw ForumException('无法获取搜索令牌');
    final r = await client.post(
      'search.php?mod=forum&searchsubmit=yes',
      {'formhash': fh, 'srchtxt': keyword, 'searchsubmit': 'yes', 'srchfid': 'all'},
      referer: '$kBaseUrl/forum.php',
    );
    if (r.url.toString().contains('mod=logging')) {
      throw ForumException('站点要求登录后才能搜索');
    }
    final page = parseThreadList(r.body);
    if (page.items.isEmpty && r.body.contains('两次搜索')) {
      throw ForumException('搜索太频繁，请稍后再试');
    }
    return page.items;
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
  Future<UserProfile?> me() async {
    final r = await client.get('home.php?mod=space&do=profile');
    final url = r.url.toString();
    if (url.contains('mod=logging') || r.body.contains('请先登录')) return null;
    final m = RegExp(r'space-uid-(\d+)').firstMatch(url);
    final header = parseHeaderUser(r.body);
    if (m == null && header == null && !looksLoggedIn(r.body)) return null;
    final uid = m != null ? int.parse(m.group(1)!) : header?.uid;
    final profile = parseProfile(r.body, fallbackUid: uid, fallbackName: header?.name);
    return profile;
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
