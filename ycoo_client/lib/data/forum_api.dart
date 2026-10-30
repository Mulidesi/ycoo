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
    final r = await client.get(
      'forum-$fid-$page.html',
      referer: '$kBaseUrl/forum-$fid-1.html',
    );
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

  /// 搜索。筛选参数与网页端 search.php 表单一一对应：
  ///   搜索范围 `f`：全文 `_all` / 标题 `subject` / 用户名 `author`
  ///   排序 `s`：相关性 `relevance` / 时间倒序 `dateline_DESC` / 时间顺序 `dateline_ASC`
  ///   版块 `fid`：0 或空 = 所有版块，否则指定版块
  ///   模糊搜索 `m=yes`、同义词 `syn=yes`（网页端同义词默认勾选）
  Future<List<ThreadItem>> search(
    String keyword, {
    int page = 1,
    String searchField = '_all',
    String sortBy = 'relevance',
    int fid = 0,
    bool fuzzy = false,
    bool synonym = true,
  }) async {
    final kw = Uri.encodeQueryComponent(keyword);
    final r = await client.get(
      'plugin.php?id=twpx_xunsearch&q=$kw'
      '&m=${fuzzy ? 'yes' : ''}'
      '&syn=${synonym ? 'yes' : ''}'
      '&f=$searchField&s=$sortBy&fid=$fid&p=$page',
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
      followUrl: d.followUrl,
      followHash: d.followHash,
      following: d.following,
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
    final dialogUrl = payUrl.contains('infloat=')
        ? payUrl
        : '$payUrl&infloat=yes&handlekey=pay&inajax=1';
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
        return BuyResult(
          success: true,
          alreadyOwned: true,
          message: _shorten(tip),
        );
      }
      if (tip.contains('余额') || tip.contains('不足') || tip.contains('权限')) {
        return BuyResult(
          success: false,
          message: tip.isEmpty ? '余额不足或无购买权限' : _shorten(tip),
        );
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
      action = action.contains('?')
          ? '$action&paysubmit=yes'
          : '$action?paysubmit=yes';
    }
    if (!action.contains('tid=')) {
      action = '$action&tid=${d.tid}';
    }
    if (!action.contains('inajax=')) action = '$action&inajax=1';

    // 2. 提交购买（tid 必须带：服务端 loadforum() 从 GET/POST 读 tid 加载主题）
    final submitUrl = action.startsWith('http') ? action : '$kBaseUrl/$action';
    final r = await client.post(submitUrl, {
      'formhash': fh,
      'paysubmit': 'yes',
      'handlekey': 'pay',
      'tid': '${d.tid}',
      'referer': '$kBaseUrl/thread-${d.tid}-1-1.html',
    }, referer: referer);
    final msg = parseAjaxMessage(r.body);
    final okByMsg =
        msg.contains('成功') || msg.contains('已经购买') || msg.contains('购买过');

    // 3. 重新拉帖验证：购买入口消失、正文回到 #postmessage 即视为已解锁
    try {
      final check = await client.get(
        'thread-${d.tid}-1-1.html',
        referer: '$kBaseUrl/forum.php',
      );
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
      return BuyResult(
        success: true,
        message: msg.isEmpty ? '购买成功，内容已解锁' : _shorten(msg),
      );
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
    final page = await client.get(
      'thread-$tid-1-1.html',
      referer: '$kBaseUrl/forum.php',
    );
    if (looksLoggedOut(page.body)) {
      return const ReplyResult(success: false, message: '登录状态已失效，请重新登录');
    }
    final form = parseReplyForm(page.body);
    final fh = formhash ?? form?.formhash ?? parseFormhash(page.body) ?? '';
    if (fh.isEmpty) {
      return const ReplyResult(success: false, message: '无法获取回复令牌，请刷新后重试');
    }

    final baseAction =
        form?.action ??
        'forum.php?mod=post&action=reply&fid=$fid&tid=$tid'
            '&extra=page%3D1&replysubmit=yes&infloat=yes&handlekey=fastpost';
    final url = baseAction.contains('inajax=')
        ? baseAction
        : '$baseAction&inajax=1';

    // Discuz 的 formhash + posttime 双重校验：
    //   * posttime 必须是当前时间戳（秒），否则 $_G['timestamp'] > $posttime
    //     触发「来路不正确或表单验证串不符」；
    //   * 回复不需要 subject，多传会让站点走到校验分支。
    final r = await client.post(url, {
      'formhash': fh,
      'message': message,
      'usesig': '1',
      'posttime': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
    }, referer: '$kBaseUrl/thread-$tid-1-1.html');

    final msg = parseAjaxMessage(r.body);
    final ok =
        r.body.contains('succeedhandle_fastpost') ||
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
    if (msg.contains('验证码') ||
        msg.contains('seccode') ||
        msg.contains('安全验证')) {
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
    final r = await client.get(
      _withInajax(url),
      referer: '$kBaseUrl/forum.php',
    );
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
    final r = await client.get(
      _withInajax(url),
      referer: '$kBaseUrl/forum.php',
    );
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
  String _withInajax(String url) =>
      url.contains('inajax=') ? url : '$url&inajax=1';

  // ---------------------------------------------------------------- 投票 / 打赏 / 楼中楼

  /// 现拉一次帖子页取 formhash（投票 / 打赏 / 点评共用）。
  /// 优先用传入的缓存值（如详情页 followHash），避免重复请求。
  Future<String> fetchFormhash(int tid, {String? cached}) async {
    if (cached != null && cached.isNotEmpty) return cached;
    final r = await client.get(
      'thread-$tid-1-1.html',
      referer: '$kBaseUrl/forum.php',
    );
    return parseFormhash(r.body) ?? '';
  }

  /// 提交主题投票。
  ///
  /// Discuz `mod=misc&action=votepoll`：多选时每个选项一个 `pollanswers[$i]`。
  /// [ids] 非空且选项均有效；[formhash] 为空时抛 [ForumException]。
  Future<String> votePoll({
    required int tid,
    required int fid,
    required String formhash,
    required List<int> ids,
  }) async {
    if (ids.isEmpty) throw ForumException('请选择投票选项');
    if (formhash.isEmpty) throw ForumException('投票凭证已失效，请下拉刷新后重试');
    final form = <String, String>{
      'formhash': formhash,
      'pollsubmit': 'yes',
      'quickforward': 'yes',
      'handlekey': 'poll',
    };
    for (var i = 0; i < ids.length; i++) {
      form['pollanswers[$i]'] = '${ids[i]}';
    }
    final r = await client.post(
      'forum.php?mod=misc&action=votepoll&tid=$tid&fid=$fid&mobile=2',
      form,
      referer: '$kBaseUrl/thread-$tid-1-1.html',
    );
    final body = r.body;
    final msg = parseAjaxMessage(body);
    // 成功走 succeedhandle_*；已投过票 / 投票已结束 / 未选项目等走 errorhandle_*。
    final errored =
        body.contains('errorhandle') || (!body.contains('succeedhandle') && _looksLikeError(msg));
    if (errored) throw ForumException(_rateErrorText(msg));
    return msg.isEmpty ? '投票成功' : _shorten(msg);
  }

  /// 读取当前用户组可用的打赏项（好评 / 金币等）、单次范围与今日剩余额度。
  Future<RateOptions> fetchRateOptions({required int tid, required int pid}) async {
    try {
      final r = await client.get(
        'forum.php?mod=misc&action=rate&tid=$tid&pid=$pid&showratetip=1&mobile=2',
        referer: '$kBaseUrl/thread-$tid-1-1.html',
      );
      if (looksLoggedOut(r.body)) {
        return const RateOptions(notice: '打赏前请先登录');
      }
      final parsed = parseRateOptions(r.body);
      if (parsed.fields.isEmpty) {
        // 站点可能返回「24 小时额度用完 / 无权限」提示页，把提示透传出去。
        final notice = parseAjaxMessage(r.body);
        return RateOptions(notice: notice.isEmpty ? '' : _shorten(notice));
      }
      return parsed;
    } catch (_) {
      return RateOptions.fallback;
    }
  }

  /// 给某个楼层打赏（Discuz `misc&action=rate`）。
  ///
  /// [scores] 键为 RateField.id，值为本次分值。成功返回站点提示或「打赏成功」。
  Future<String> ratePost({
    required int tid,
    required int pid,
    required String formhash,
    required Map<int, int> scores,
    String reason = '',
    bool notify = false,
  }) async {
    if (formhash.isEmpty) throw ForumException('打赏凭证已失效，请下拉刷新后重试');
    final r = await client.post(
      'forum.php?mod=misc&action=rate&tid=$tid&pid=$pid&ratesubmit=yes'
      '&handlekey=rate&formhash=$formhash&inajax=1&mobile=2',
      {
        'formhash': formhash,
        'tid': '$tid',
        'pid': '$pid',
        'reason': reason,
        for (final e in scores.entries) 'score${e.key}': '${e.value}',
        if (notify) 'sendreasonpm': 'on',
      },
      referer: '$kBaseUrl/thread-$tid-1-1.html',
    );
    final msg = parseAjaxMessage(r.body);
    if (_looksLikeError(msg)) throw ForumException(_rateErrorText(msg));
    return msg.isEmpty ? '打赏成功' : _shorten(msg);
  }

  /// 楼中楼点评（Discuz `mod=post&action=comment`）。
  Future<String> addComment({
    required int tid,
    required int pid,
    required String message,
    required String formhash,
  }) async {
    if (formhash.isEmpty) throw ForumException('点评凭证已失效，请下拉刷新后重试');
    if (message.trim().isEmpty) throw ForumException('请输入点评内容');
    final r = await client.post(
      'forum.php?mod=post&action=comment&tid=$tid&pid=$pid&commentsubmit=yes&mobile=2',
      {
        'formhash': formhash,
        'message': message,
        'posttime': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
      },
      referer: '$kBaseUrl/thread-$tid-1-1.html',
    );
    final msg = parseAjaxMessage(r.body);
    if (_looksLikeError(msg)) throw ForumException(_shorten(msg));
    return msg.isEmpty ? '点评成功' : _shorten(msg);
  }

  // ---------------------------------------------------------------- 举报 / 编辑 / 删除

  /// 举报主题或回复（Discuz `mod=misc&action=report`）。
  ///
  /// [reason] 为原因编号 1-5，[message] 为补充说明。
  Future<String> report({
    required int tid,
    required int fid,
    required int pid,
    required String formhash,
    required int reason,
    String message = '',
  }) async {
    if (formhash.isEmpty) throw ForumException('举报凭证已失效，请下拉刷新后重试');
    final r = await client.post(
      'forum.php?mod=misc&action=report&tid=$tid&fid=$fid&pid=$pid'
      '&reportsubmit=yes&handlekey=report&mobile=2',
      {
        'formhash': formhash,
        'reason': '$reason',
        'message': message,
      },
      referer: '$kBaseUrl/thread-$tid-1-1.html',
    );
    final msg = parseAjaxMessage(r.body);
    if (_looksLikeError(msg)) throw ForumException(_shorten(msg));
    return msg.isEmpty ? '举报已提交' : _shorten(msg);
  }

  /// 编辑自己的帖子 / 回复（Discuz `mod=post&action=edit&editsubmit=yes`）。
  Future<String> editPost({
    required int tid,
    required int fid,
    required int pid,
    required String subject,
    required String message,
    required String formhash,
  }) async {
    if (formhash.isEmpty) throw ForumException('编辑凭证已失效，请下拉刷新后重试');
    final r = await client.post(
      'forum.php?mod=post&action=edit&tid=$tid&fid=$fid&pid=$pid'
      '&editsubmit=yes&mobile=2',
      {
        'formhash': formhash,
        'subject': subject,
        'message': message,
        'posttime': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        'usesig': '1',
        'save': '',
      },
      referer: '$kBaseUrl/thread-$tid-1-1.html',
    );
    final msg = parseAjaxMessage(r.body);
    if (_looksLikeError(msg)) throw ForumException(_shorten(msg));
    return msg.isEmpty ? '编辑成功' : _shorten(msg);
  }

  /// 删除自己的帖子 / 回复（Discuz 用 `action=edit&delete=1`）。
  Future<String> deletePost({
    required int tid,
    required int fid,
    required int pid,
    required String formhash,
  }) async {
    if (formhash.isEmpty) throw ForumException('删除凭证已失效，请下拉刷新后重试');
    final r = await client.get(
      'forum.php?mod=post&action=edit&tid=$tid&fid=$fid&pid=$pid'
      '&delete=1&formhash=$formhash&mobile=2',
      referer: '$kBaseUrl/thread-$tid-1-1.html',
    );
    final msg = parseAjaxMessage(r.body);
    if (_looksLikeError(msg)) throw ForumException(_shorten(msg));
    return msg.isEmpty ? '已删除' : _shorten(msg);
  }

  bool _looksLikeError(String text) =>
      RegExp(r'(抱歉|错误|失败|不能|无权|权限|非法|禁止|请先登录|间隔|重复|超过限制)')
          .hasMatch(text);

  String _rateErrorText(String message) {
    if (RegExp(r'24\s*小时评分数超过限制').hasMatch(message)) {
      return '24 小时内该积分项的评分额度已用完，请明天再试';
    }
    if (message.contains('不能给自己评分') || message.contains('不能评分自己')) {
      return '不能打赏自己的帖子';
    }
    if (message.contains('没有权限') || message.contains('无权')) {
      return '当前账号没有打赏权限';
    }
    return message;
  }

  // ---------------------------------------------------------------- 发帖

  /// 打开版块发帖页，取 `form#postform` 的 action、formhash、posttime 与分类。
  Future<PostForm> newThreadForm(int fid) async {
    final page = await client.get(
      'forum.php?mod=post&action=newthread&fid=$fid',
      referer: '$kBaseUrl/forum-$fid-1.html',
    );
    if (looksLoggedOut(page.body)) {
      return const PostForm(canPost: false, notice: '登录状态已失效，请重新登录');
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
    bool replyOnly = false,
    bool orderDesc = false,
    bool notify = false,
    bool useSignature = true,
    String readPerm = '',
    String price = '',
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

    final baseAction =
        form.action ??
        'forum.php?mod=post&action=newthread&fid=$fid&extra=&topicsubmit=yes';
    final url = baseAction.contains('inajax=')
        ? baseAction
        : '$baseAction&inajax=1';

    final r = await client.post(url, {
      'formhash': fh,
      if (form.posttime != null) 'posttime': form.posttime!,
      'subject': title,
      'message': message,
      'typeid': '${typeId ?? 0}',
      'usesig': useSignature ? '1' : '0',
      'wysiwyg': '0',
      'save': '',
      if (replyOnly) 'replyonly': '1',
      if (orderDesc) 'ordertype': '1',
      if (notify) 'emailnotify': '1',
      if (readPerm.isNotEmpty && readPerm != '0') 'readperm': readPerm,
      if (price.isNotEmpty && price != '0') 'price': price,
    }, referer: '$kBaseUrl/forum.php?mod=post&action=newthread&fid=$fid');
    return parseNewThreadResult(r.body);
  }

  /// 上传附件到 Discuz。
  ///
  /// 走 `misc.php?mod=swfupload` 接口，返回 `DISCUZUPLOAD|aid|status|size`。
  /// 需要发帖页表单中的 `uploadhash`（swfupload 凭证）和当前用户 `uid`。
  Future<int> uploadAttachment({
    required List<int> bytes,
    required String filename,
    required String uploadHash,
    required int uid,
    int? fid,
    bool image = true,
  }) async {
    if (uploadHash.isEmpty) {
      throw ForumException('上传凭证已失效，请返回发帖页重试');
    }
    final r = await client.postFile(
      'misc.php?mod=swfupload&operation=upload'
      '&type=${image ? "image" : "attach"}'
      '&inajax=yes&infloat=yes&simple=2',
      {
        'uid': '$uid',
        'hash': uploadHash,
      },
      fieldName: 'Filedata',
      filename: filename,
      bytes: bytes,
      referer: fid != null
          ? '$kBaseUrl/forum.php?mod=post&action=newthread&fid=$fid&mobile=2'
          : '$kBaseUrl/forum.php?mod=post&action=newthread&mobile=2',
    );
    final match =
        RegExp(r'DISCUZUPLOAD\|(\d*)\|(-?\d+)\|(\d+)').firstMatch(r.body);
    if (match == null) {
      throw ForumException('上传失败，请稍后重试');
    }
    final status = int.tryParse(match.group(2) ?? '') ?? -1;
    final aid = int.tryParse(match.group(3) ?? '') ?? 0;
    if (status != 0 || aid <= 0) {
      throw ForumException('上传失败（状态码 $status），请稍后重试');
    }
    return aid;
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
    final ok =
        msg.contains('欢迎您回来') ||
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
    final uid =
        int.tryParse(fromUrl ?? '') ?? parseDiscuzUid(r.body) ?? header?.uid;
    if (uid == null && header == null && !looksLoggedIn(r.body)) return null;

    // 先按 HTML 解析，作为兜底 + 头像 / 用户组来源
    final html = parseProfile(
      r.body,
      fallbackUid: uid,
      fallbackName: header?.name,
    );

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
    final html = r.statusCode == 200
        ? parseProfile(r.body, fallbackUid: uid)
        : null;
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

  /// 目标用户的回帖列表（点进去看上下文）。
  Future<ThreadPage> userReplies({required int uid, int page = 1}) async {
    if (uid <= 0) {
      return const ThreadPage(items: [], page: 1, totalPages: 1);
    }
    final r = await client.get(
      'home.php?mod=space&uid=$uid&do=reply&view=me&from=space&page=$page',
      referer: '$kBaseUrl/home.php?mod=space&uid=$uid',
    );
    if (isUserSpaceMissing(r.body)) {
      throw ForumException('该用户不存在或空间不可见');
    }
    if (isLoginRequired(r.body)) {
      throw ForumException('登录后才能查看该用户的回帖');
    }
    return parseUserReplyList(r.body, page: page);
  }

  /// 关注 / 粉丝列表。[followers] 为 true 时取「关注我的」，否则取「我关注的」。
  Future<FollowPage> followList({
    required int uid,
    bool followers = false,
    int page = 1,
  }) async {
    if (uid <= 0) {
      return const FollowPage(items: [], page: 1, totalPages: 1);
    }
    final kind = followers ? 'follower' : 'follow';
    final r = await client.get(
      'home.php?mod=space&uid=$uid&do=$kind&view=$kind&from=space&page=$page',
      referer: '$kBaseUrl/home.php?mod=space&uid=$uid',
    );
    if (isUserSpaceMissing(r.body)) {
      throw ForumException('该用户不存在或空间不可见');
    }
    if (isLoginRequired(r.body)) {
      throw ForumException('登录后才能查看关注列表');
    }
    return parseFollowList(r.body, page: page);
  }

  /// 读取某用户空间页的关注状态；自己 / 游客 / 无权限时返回 null。
  Future<FollowLink?> followStatus(int uid) async {
    if (uid <= 0) return null;
    final r = await client.get(
      'home.php?mod=space&uid=$uid',
      referer: '$kBaseUrl/home.php?mod=space&uid=$uid',
    );
    if (isUserSpaceMissing(r.body) || isLoginRequired(r.body)) return null;
    return parseFollowLink(r.body, uid: uid);
  }

  /// 关注（[follow] 为 true）或取消关注。新增关注必须带 formhash。
  Future<SiteActionResult> setFollow({
    required int uid,
    required bool follow,
    String? hash,
  }) async {
    if (uid <= 0) {
      return const SiteActionResult(success: false, message: '该用户不存在');
    }
    final op = follow ? 'add' : 'del';
    final h = follow && hash != null && hash.isNotEmpty ? '&hash=$hash' : '';
    final url = 'home.php?mod=spacecp&ac=follow&op=$op$h&fuid=$uid';
    final r = await client.get(
      _withInajax(url),
      referer: '$kBaseUrl/home.php?mod=space&uid=$uid',
    );
    final body = r.body;
    if (looksLoggedOut(body)) {
      return const SiteActionResult(success: false, message: '关注前请先登录');
    }
    final msg = parseAjaxMessage(body);
    if (msg.contains('登录') || msg.contains('游客')) {
      return const SiteActionResult(success: false, message: '登录状态已失效，请重新登录');
    }
    // 成功走 succeedhandle_*；失败（hash 过期 / 来路不正确 / 无权限）走 alert_error。
    if (body.contains('succeedhandle_') ||
        msg.contains('成功') ||
        msg.contains('已关注')) {
      return SiteActionResult(
        success: true,
        message: msg.isEmpty ? (follow ? '已关注' : '已取消关注') : _shorten(msg),
      );
    }
    return SiteActionResult(
      success: false,
      message: msg.isEmpty ? '操作失败，请稍后重试' : _shorten(msg),
    );
  }

  // ---------------------------------------------------------------- 签到

  Future<SignStatus> signStatus() async {
    final r = await client.get(
      'k_misign-sign.html',
      referer: '$kBaseUrl/forum.php',
    );
    return parseSignPage(r.body);
  }

  Future<SignResult> sign({String? formhash}) async {
    final page = await client.get(
      'k_misign-sign.html',
      referer: '$kBaseUrl/forum.php',
    );
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
    final ok =
        msg.contains('签到成功') ||
        msg.contains('今日已签') ||
        msg.contains('恭喜') ||
        msg.contains('已经签到') ||
        msg.contains('已签到') ||
        r.body.contains('qiandao_success');
    if (ok) {
      return SignResult(
        success: true,
        message: msg.isEmpty ? '签到成功' : _shorten(msg),
      );
    }
    if (msg.contains('登录') || msg.contains('游客')) {
      return const SignResult(success: false, message: '登录状态已失效，请重新登录');
    }
    return SignResult(
      success: false,
      message: msg.isEmpty ? '签到失败，请稍后重试' : _shorten(msg),
    );
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
      if (m != null) {
        return DateTime.tryParse(m.group(1)!.trim()) ?? DateTime.now();
      }
    } catch (_) {}
    return DateTime.now();
  }

  Future<List<FriendItem>> fetchFriends({int page = 1}) async {
    final r = await client.get(
      'home.php?mod=space&do=friend&view=me&mobile=2&page=$page',
    );
    return parseFriends(r.body);
  }

  static int estimatePage(int totalPages) => math.max(1, totalPages);
}
