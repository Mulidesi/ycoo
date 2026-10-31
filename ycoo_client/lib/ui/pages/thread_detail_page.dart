import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/discuz_client.dart';
import '../../core/error/app_exception.dart';
import '../../core/navigation/user_nav.dart';
import '../../core/services/download_service.dart';
import '../../core/services/offline_cache.dart';
import '../../core/share/share_image_service.dart';
import '../../core/share/share_platform.dart';
import '../../core/share/share_renderer.dart';
import '../../data/content.dart';
import '../../design/tokens.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/glass_reply_bar.dart';
import '../widgets/html_content.dart';

/// 帖子详情。
///
/// 版式上把「楼主正文」和「评论」拆成两个视觉层：
///   * 正文：独立白卡（标题 + 作者 + 正文 + 操作），像一篇文章；
///   * 评论：无卡片、浅分隔线的平铺列表，带楼层名与排序；
/// 这样长贴滑到底时能一眼看出「正文结束、评论开始」。
class ThreadDetailPage extends StatefulWidget {
  const ThreadDetailPage({
    super.key,
    required this.tid,
    this.title,
    this.fid,
    this.boardName,
  });

  final int tid;
  final String? title;
  final int? fid;

  /// 版块名（列表页带过来，用于标题下方的标签）
  final String? boardName;

  @override
  State<ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends State<ThreadDetailPage> {
  final _replyCtrl = TextEditingController();
  final _scroll = ScrollController();

  ThreadDetail? _detail;
  final _posts = <Post>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  bool _buying = false;
  bool _desc = false; // 评论排序：false=正序
  String? _error;
  String? _autoReplyHint;
  bool _autoReplyBusy = false;

  /// 回复栏展开态（键盘弹起时展开为多行输入）。
  bool _replyExpanded = false;

  /// 回复目标楼层（pid + 作者名），用于展开态显示提示条。
  int? _replyTargetPid;
  String? _replyTargetAuthor;

  /// 点赞 / 收藏为会话内状态：站点没有「我的点赞」查询接口，不持久化。
  bool _liked = false;
  bool _favorited = false;
  bool _actionBusy = false;

  /// 关注楼主：初始值来自详情页入口（op=del 表示已关注），操作后本地翻转。
  bool _following = false;
  bool _followBusy = false;

  /// 附件下载状态（key = attachment.url）
  final Map<String, _DlState> _dls = <String, _DlState>{};

  /// 投票：本次会话内的选择与提交态。刷新后由解析结果决定展示表单还是结果。
  final Set<int> _pollSelected = <int>{};
  bool _pollVoted = false;
  bool _pollBusy = false;

  /// 当前主域名的帖子链接（分享 / 复制 / 浏览器打开 / 购买兜底）。
  String _threadUrl([int page = 1]) {
    final origin = context.read<AppState>().site.origin;
    final base = origin.endsWith('/') ? origin.substring(0, origin.length - 1) : origin;
    return '$base/thread-${widget.tid}-$page-1.html';
  }

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load(int page, {bool replace = false}) async {
    setState(() {
      if (page == 1 || replace) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final api = context.read<AppState>().api;
      final d = await api.thread(widget.tid, page: page, title: widget.title);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _following = d.following;
        if (page == 1 || replace) {
          _posts
            ..clear()
            ..addAll(d.posts);
        } else {
          _posts.addAll(d.posts.where((p) => !_posts.any((x) => x.pid == p.pid)));
        }
        _loading = false;
        _loadingMore = false;
      });
      if (page == 1) _tryAutoReply(d);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _tryAutoReply(ThreadDetail d) async {
    final st = context.read<AppState>();
    if (!st.shouldAutoReply(d)) return;
    setState(() {
      _autoReplyHint = '检测到隐藏内容，正在自动回复解锁…';
      _autoReplyBusy = true;
    });
    final res = await st.maybeAutoReply(d);
    if (!mounted) return;
    if (res?.success == true) {
      setState(() => _autoReplyHint = '回复成功，正在刷新内容…');
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      await _load(1);
      if (!mounted) return;
      setState(() {
        _autoReplyHint = null;
        _autoReplyBusy = false;
      });
      _toast('已自动回复，隐藏内容已解锁');
    } else {
      setState(() {
        _autoReplyHint = res?.message ?? '自动回复未执行';
        _autoReplyBusy = false;
      });
    }
  }

  Future<void> _cacheThreadOffline() async {
    final d = _detail;
    if (d == null) return;
    setState(() => _actionBusy = true);
    try {
      await OfflineThreadCache.instance.save(
        tid: widget.tid,
        title: d.title,
        boardName: widget.boardName ?? '',
        author: d.posts.isNotEmpty ? d.posts.first.author : '',
        time: d.posts.isNotEmpty ? (d.posts.first.timeText ?? '') : '',
        views: d.posts.first.poll?.totalVotes ?? 0,
        replies: 0,
        posts: d.posts,
      );
      if (mounted) _toast('帖子已缓存，可离线阅读');
    } catch (e) {
      if (mounted) _toast(e is AppException ? e.displayMessage : '网络错误，请重试');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    final d = _detail;
    if (text.isEmpty || d == null) return;
    setState(() => _sending = true);
    ReplyResult res;
    try {
      res = await context.read<AppState>().manualReply(d, text);
    } catch (e) {
      res = ReplyResult(
        success: false,
        message: e is AppException ? e.displayMessage : '回复失败，网络异常，请重试',
      );
    }
    if (!mounted) return;
    setState(() => _sending = false);
    if (res.success) {
      _replyCtrl.clear();
      _clearReplyTarget();
      setState(() => _replyExpanded = false);
      FocusScope.of(context).unfocus();
      _toast('操作成功');
      await _load(1);
    } else {
      _toast(res.message);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _copyText(String text, {String okHint = '已复制'}) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast(text.isEmpty ? '没有可复制的内容' : okHint);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _detail;
    final loggedIn = context.watch<AppState>().loggedIn;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          d?.title ?? widget.title ?? '帖子',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => _load(1),
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'browser') {
                await launchUrl(Uri.parse(_threadUrl()), mode: LaunchMode.externalApplication);
              } else if (v == 'copy') {
                await _copyText(_threadUrl(), okHint: '链接已复制');
              } else if (v == 'cache') {
                await _cacheThreadOffline();
              }
            },
            itemBuilder: (c) => const [
              PopupMenuItem(
                value: 'cache',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cloud_download_rounded, size: 20),
                  title: Text('缓存帖子供离线阅读'),
                ),
              ),
              PopupMenuItem(value: 'copy', child: Text('复制链接')),
              PopupMenuItem(value: 'browser', child: Text('在浏览器打开')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(theme, d)),
          // 输入条必须放在 body 内，随键盘弹出一起上移。
          // 放在 bottomNavigationBar 时，edge-to-edge 设备上会被输入法完全盖住。
          if (loggedIn && d != null) _replyBar(),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ThreadDetail? d) {
    final semantic = YuanSemanticColors.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && d == null) {
      return ErrorView(message: _error!, onRetry: () => _load(1));
    }
    if (d == null) return const EmptyView(message: '帖子不存在或已被删除');

    final op = _opPost();
    final comments = _comments();

    return RefreshIndicator(
      onRefresh: () => _load(1),
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(YuanSpace.sm, YuanSpace.sm, YuanSpace.sm, YuanSpace.xl),
        children: [
          if (d.isLocked) _lockedBanner(theme, d),
          if (_autoReplyHint != null) _autoReplyTip(theme),
          if (op != null) _articleCard(theme, d, op),
          _commentsHeader(theme, comments.length),
          if (comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  '还没有评论，来抢沙发',
                  style: YuanType.bodySm.copyWith(color: semantic.textTertiary),
                ),
              ),
            )
          else
            for (var i = 0; i < comments.length; i++)
              _commentTile(theme, comments[i], i, comments.length),
          if (d.totalPages > 1) _pager(theme, d) else _endTip(theme),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 楼主帖：优先 isOp，退化到第一层
  Post? _opPost() {
    if (_posts.isEmpty) return null;
    for (final p in _posts) {
      if (p.isOp) return p;
    }
    return _posts.first;
  }

  /// 除楼主外的所有楼层，按 pid 排序（Discuz 的 pid 单调递增）
  List<Post> _comments() {
    final op = _opPost();
    final list = _posts.where((p) => p.pid != op?.pid).toList();
    list.sort((a, b) => _desc ? b.pid.compareTo(a.pid) : a.pid.compareTo(b.pid));
    return list;
  }

  // ---------------------------------------------------------------- 正文

  Widget _articleCard(ThemeData theme, ThreadDetail d, Post op) {
    final semantic = YuanSemanticColors.of(context);
    final muted = semantic.textTertiary;
    return Container(
      padding: const EdgeInsets.fromLTRB(YuanSpace.md, YuanSpace.lg, YuanSpace.md, YuanSpace.xs),
      decoration: BoxDecoration(
        color: semantic.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: semantic.brandPrimary, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            d.title,
            style: YuanType.titleMd.copyWith(fontSize: 19.5, height: 1.42),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Avatar(
                url: op.avatar,
                name: op.author,
                size: YuanSizes.avatarThreadBody * 0.72,
                onTap: () => openUserFromAvatar(
                  context,
                  uid: op.authorId,
                  username: op.author,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            op.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: YuanType.titleSm.copyWith(fontSize: 13.5),
                          ),
                        ),
                        if (op.level != null) ...[
                          const SizedBox(width: 6),
                          _levelBadge(op.level!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      op.timeText ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: YuanType.label.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              if (d.followUrl != null && op.authorId != null) ...[
                const SizedBox(width: 8),
                _followChip(following: _following, onTap: _followBusy ? null : _toggleFollow),
              ],
              if ((widget.boardName ?? '').isNotEmpty) ...[
                const SizedBox(width: 8),
                _outlineChip(theme, widget.boardName!),
              ],
            ],
          ),
          const SizedBox(height: 16),
           // 附件被抽出正文后，contentHtml 可能只剩空白/<br>，不能再当成"正文为空"提示。
           if (_hasVisibleBody(op))
             PostContent(html: op.contentHtml, fontSize: YuanType.bodyLg.fontSize!, showLockedHint: false)
           else if (op.attachments.isEmpty)
             Padding(
               padding: const EdgeInsets.symmetric(vertical: 12),
               child: Text(
                 '正文需登录或购买后可见，见上方提示',
                 style: theme.textTheme.bodySmall?.copyWith(color: muted),
               ),
             ),
           if (op.poll != null) _pollCard(op.poll!),
           if (op.attachments.isNotEmpty) _attachmentList(op.attachments),
           const SizedBox(height: 6),
           Divider(height: YuanSpace.xl, color: semantic.outlineSubtle),
           Row(
             children: [
               _actionButton(
                 context,
                 theme,
                 icon: Icons.copy_rounded,
                 label: '复制正文',
                 onTap: () => _copyText(
                   contentPlainText(parsePostContent(op.contentHtml, showLockedHint: false)).trim(),
                 ),
               ),
               if (op.canRate)
                 _actionButton(
                   context,
                   theme,
                   icon: Icons.stars_outlined,
                   label: '打赏',
                   onTap: () => _showRateSheet(op),
                 ),
               _actionButton(
                 context,
                 theme,
                 icon: Icons.share_outlined,
                 label: '分享',
                 onTap: _showShareSheet,
               ),
               _actionButton(
                 context,
                 theme,
                 icon: Icons.open_in_browser_rounded,
                 label: '浏览器',
                 onTap: () => launchUrl(Uri.parse(_threadUrl()), mode: LaunchMode.externalApplication),
               ),
               _postMenu(op, compact: false),
               const Spacer(),
              Flexible(
                child: Text(
                  '${_posts.length} 楼 · ${d.totalPages} 页',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: YuanType.label.copyWith(color: semantic.textTertiary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context, ThemeData theme,
      {required IconData icon, required String label, required VoidCallback onTap}) {
    final muted = YuanSemanticColors.of(context).textTertiary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(YuanRadius.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: YuanSpace.xs, vertical: YuanSpace.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: muted),
            const SizedBox(width: 5),
            Text(
              label,
              style: YuanType.label.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 投票

  /// 主题投票卡片。未投且未过期时可选（单选 radio / 多选 checkbox）并提交；
  /// 已投或过期时展示结果条形图。
  Widget _pollCard(Poll poll) {
    final semantic = YuanSemanticColors.of(context);
    final showResult = poll.voted || poll.expired || _pollVoted;
    final total = poll.totalVotes;
    return Container(
      margin: const EdgeInsets.only(top: YuanSpace.md),
      padding: const EdgeInsets.all(YuanSpace.md),
      decoration: BoxDecoration(
        color: semantic.surfaceReply,
        borderRadius: BorderRadius.circular(YuanRadius.sm),
        border: Border.all(color: semantic.outlineSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll_outlined, size: 16, color: semantic.brandPrimary),
              const SizedBox(width: 6),
              const Text('投票', style: YuanType.titleSm),
              if (poll.multiple) ...[
                const SizedBox(width: 6),
                Text('（多选）', style: YuanType.caption.copyWith(color: semantic.textTertiary)),
              ],
              const Spacer(),
              if (total > 0)
                Text('$total 人参与',
                    style: YuanType.caption.copyWith(color: semantic.textTertiary)),
            ],
          ),
          const SizedBox(height: YuanSpace.sm),
          for (final opt in poll.options)
            if (showResult)
              _pollResultRow(opt, total, semantic)
            else
              _pollSelectableRow(opt, poll.multiple, semantic),
          if (!showResult) ...[
            const SizedBox(height: YuanSpace.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _pollBusy || _pollSelected.isEmpty ? null : _submitPoll,
                icon: const Icon(Icons.how_to_vote_outlined, size: 18),
                label: Text(_pollBusy ? '提交中…' : '提交投票'),
              ),
            ),
          ],
          if (poll.expired && !poll.voted)
            Padding(
              padding: const EdgeInsets.only(top: YuanSpace.xs),
              child: Text('投票已结束',
                  style: YuanType.caption.copyWith(color: semantic.textTertiary)),
            ),
        ],
      ),
    );
  }

  Widget _pollSelectableRow(PollOption opt, bool multiple, YuanSemanticColors semantic) {
    final checked = _pollSelected.contains(opt.id);
    return InkWell(
      onTap: () => setState(() {
        if (multiple) {
          if (checked) {
            _pollSelected.remove(opt.id);
          } else {
            _pollSelected.add(opt.id);
          }
        } else {
          _pollSelected
            ..clear()
            ..add(opt.id);
        }
      }),
      borderRadius: BorderRadius.circular(YuanRadius.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            Icon(
              multiple
                  ? (checked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                  : (checked ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
              size: 18,
              color: checked ? semantic.brandPrimary : semantic.textTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(opt.text, style: YuanType.bodyMd)),
          ],
        ),
      ),
    );
  }

  Widget _pollResultRow(PollOption opt, int total, YuanSemanticColors semantic) {
    final ratio = total > 0 ? opt.votes / total : 0.0;
    final pct = (ratio * 100).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(opt.text, style: YuanType.bodySm)),
              const SizedBox(width: 8),
              Text('${opt.votes} 票 · $pct%',
                  style: YuanType.caption.copyWith(color: semantic.textTertiary)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: semantic.outlineSubtle,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPoll() async {
    final d = _detail;
    final op = _opPost();
    if (d == null || op?.poll == null || _pollSelected.isEmpty) return;
    if (!context.read<AppState>().loggedIn) {
      _toast('请先登录');
      return;
    }
    setState(() => _pollBusy = true);
    try {
      final api = context.read<AppState>().api;
      final hash = await _formhash();
      final msg = await api.votePoll(
        tid: d.tid,
        fid: d.fid,
        formhash: hash,
        ids: _pollSelected.toList(),
      );
      if (!mounted) return;
      _toast(msg);
      _pollVoted = true;
      await _load(1);
    } catch (e) {
      if (!mounted) return;
      _toast(e is AppException ? e.displayMessage : '网络错误，请重试');
    } finally {
      if (mounted) setState(() => _pollBusy = false);
    }
  }

  /// 当前帖子的 formhash：优先用关注入口里带的，否则现拉一次帖子页。
  Future<String> _formhash() async {
    final api = context.read<AppState>().api;
    return api.fetchFormhash(_detail?.tid ?? widget.tid, cached: _detail?.followHash);
  }

  // ---------------------------------------------------------------- 打赏

  /// 打赏弹层：读取站点可用积分项与剩余额度，选择分值并提交。
  Future<void> _showRateSheet(Post target) async {
    final d = _detail;
    if (d == null) return;
    if (!context.read<AppState>().loggedIn) {
      _toast('请先登录');
      return;
    }
    final api = context.read<AppState>().api;
    final options = await api.fetchRateOptions(tid: d.tid, pid: target.pid);
    if (!mounted) return;
    if (options.fields.isEmpty) {
      _toast(options.notice.isEmpty ? '当前无法打赏' : options.notice);
      return;
    }
    final scores = <int, int>{
      for (final f in options.fields) f.id: f.presets.isNotEmpty ? f.presets.last : f.ceiling,
    };
    final reasonCtrl = TextEditingController();
    var notify = false;
    bool submitting = false;

    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.5,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (c, setSheet) => Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                YuanSpace.xl, YuanSpace.xs, YuanSpace.xl, YuanSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(target.rateTitle ?? '打赏', style: YuanType.titleSm),
                const SizedBox(height: YuanSpace.md),
                for (final f in options.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: YuanSpace.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${f.label}（上限 ${f.ceiling}）', style: YuanType.bodySm),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final v in (f.presets.isEmpty
                                ? List<int>.generate(f.ceiling, (i) => i + 1)
                                : f.presets))
                              _rateValueChip(
                                label: v >= 0 ? '+$v' : '$v',
                                selected: (scores[f.id] ?? 0) == v,
                                onTap: () => setSheet(() => scores[f.id] = v),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: reasonCtrl,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    hintText: '打赏理由（选填）',
                    counterText: '',
                    isDense: true,
                  ),
                ),
                if (options.canNotify)
                  CheckboxListTile(
                    value: notify,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('站短通知对方', style: YuanType.bodySm),
                    onChanged: (v) => setSheet(() => notify = v ?? false),
                  ),
                const SizedBox(height: YuanSpace.sm),
                FilledButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          setSheet(() => submitting = true);
                          try {
                            final hash = await _formhash();
                            final msg = await api.ratePost(
                              tid: d.tid,
                              pid: target.pid,
                              formhash: hash,
                              scores: scores,
                              reason: reasonCtrl.text.trim(),
                              notify: notify,
                            );
                            if (!c.mounted) return;
                            Navigator.of(c).pop();
                            _toast(msg);
                            await _load(1);
                          } catch (e) {
                            setSheet(() => submitting = false);
                            if (c.mounted) {
                              _toast(e is AppException ? e.displayMessage : '网络错误，请重试');
                            }
                          }
                        },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(submitting ? '提交中…' : '确认打赏'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    reasonCtrl.dispose();
  }

  Widget _rateValueChip(
      {required String label, required bool selected, required VoidCallback onTap}) {
    final semantic = YuanSemanticColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? semantic.brandPrimary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? semantic.brandPrimary : semantic.outlineSubtle,
          ),
        ),
        child: Text(
          label,
          style: YuanType.label.copyWith(
            color: selected ? semantic.brandPrimary : semantic.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 评论

  Widget _commentsHeader(ThemeData theme, int count) {
    final semantic = YuanSemanticColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: semantic.brandPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '评论区 $count 条回复',
                style: YuanType.titleMd.copyWith(fontSize: 15.5),
              ),
              const Spacer(),
              _sortChip(theme, '正序', !_desc),
              const SizedBox(width: 6),
              _sortChip(theme, '倒序', _desc),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          height: 0.5,
          color: semantic.outlineSubtle,
        ),
      ],
    );
  }

  Widget _sortChip(ThemeData theme, String label, bool active) {
    final semantic = YuanSemanticColors.of(context);
    return GestureDetector(
      onTap: () {
        final desc = label == '倒序';
        if (desc == _desc) return;
        setState(() => _desc = desc);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? semantic.brandPrimary.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: YuanType.label.copyWith(
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? semantic.brandPrimary : semantic.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _commentTile(ThemeData theme, Post p, int index, int total) {
    final semantic = YuanSemanticColors.of(context);
    final muted = semantic.textTertiary;
    final floor = _floorLabel(p, index);
    return Container(
      decoration: BoxDecoration(
        color: semantic.surfaceBase,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: semantic.outlineReplyRail, width: YuanSizes.replyRailWidth),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(YuanSpace.sm + YuanSizes.replyRailWidth, YuanSpace.md, YuanSpace.sm, YuanSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(
            url: p.avatar,
            name: p.author,
            size: YuanSizes.avatarReply * 0.84,
            onTap: () => openUserFromAvatar(
              context,
              uid: p.authorId,
              username: p.author,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: YuanType.titleSm.copyWith(fontSize: 13),
                      ),
                    ),
                    if (p.level != null) ...[
                      const SizedBox(width: 6),
                      _levelBadge(p.level!),
                    ],
                    if (floor.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        floor,
                        style: YuanType.caption.copyWith(color: semantic.textTertiary),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (_hasVisibleBody(p))
                  PostContent(
                    html: p.contentHtml,
                    fontSize: YuanType.bodyMd.fontSize!,
                    selectable: false,
                    maxImageHeight: 300,
                    showLockedHint: true,
                    collapseQuotes: true,
                  )
                else if (p.attachments.isEmpty)
                  Text('（该楼内容不可见）', style: YuanType.bodySm.copyWith(color: muted)),
                if (p.attachments.isNotEmpty) _attachmentList(p.attachments),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      p.timeText ?? '',
                      style: YuanType.caption.copyWith(color: muted),
                    ),
                    const Spacer(),
                    if (p.canRate)
                      InkWell(
                        onTap: () => _showRateSheet(p),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stars_outlined, size: 15, color: muted),
                              const SizedBox(width: 4),
                              Text('打赏', style: YuanType.label.copyWith(color: muted)),
                            ],
                          ),
                        ),
                      ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _replyTargetPid = p.pid;
                          _replyTargetAuthor = p.author;
                          _replyCtrl.text = '@${p.author} ';
                          _replyCtrl.selection = TextSelection.collapsed(offset: _replyCtrl.text.length);
                          _replyExpanded = true;
                        });
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Icon(Icons.reply_rounded, size: 15, color: muted),
                      ),
                    ),
                    InkWell(
                      onTap: () => _showCommentSheet(p),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Icon(Icons.chat_bubble_outline_rounded, size: 15, color: muted),
                      ),
                    ),
                    _postMenu(p, compact: true),
                  ],
                ),
                if (p.comments.isNotEmpty) _commentList(p),
                if (p.rates.isNotEmpty) _rateRecords(p),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 打赏记录列表（`#ratelog_<pid>` 解析结果）。
  Widget _rateRecords(Post p) {
    final semantic = YuanSemanticColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: YuanSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in p.rates)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                [
                  if (r.username.isNotEmpty) r.username,
                  if (r.score.isNotEmpty) r.score,
                  if (r.reason.isNotEmpty) r.reason,
                ].join(' · '),
                style: YuanType.caption.copyWith(color: semantic.textTertiary),
              ),
            ),
        ],
      ),
    );
  }

  /// 楼中楼点评列表（Discuz `.cm` 容器，纯展示；点评入口在操作行）。
  Widget _commentList(Post p) {
    final semantic = YuanSemanticColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: YuanSpace.sm),
      padding: const EdgeInsets.all(YuanSpace.sm),
      decoration: BoxDecoration(
        color: semantic.surfaceReply.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(YuanRadius.xs),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in p.comments) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.author.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text('${c.author}：',
                        style: YuanType.label.copyWith(color: semantic.textSecondary)),
                  ),
                Expanded(
                  child: Text(
                    c.text,
                    style: YuanType.bodySm.copyWith(color: semantic.textSecondary),
                  ),
                ),
              ],
            ),
            if (c.time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(c.time,
                    style: YuanType.caption.copyWith(color: semantic.textTertiary)),
              ),
            if (c != p.comments.last)
              Divider(height: YuanSpace.md, color: semantic.outlineSubtle),
          ],
        ],
      ),
    );
  }

  /// 楼中楼点评弹层：输入文本并提交到 `mod=post&action=comment`。
  Future<void> _showCommentSheet(Post target) async {
    final d = _detail;
    if (d == null) return;
    if (!context.read<AppState>().loggedIn) {
      _toast('请先登录');
      return;
    }
    final ctrl = TextEditingController();
    var submitting = false;
    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.35,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (c, setSheet) => Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                YuanSpace.xl, YuanSpace.xs, YuanSpace.xl, YuanSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('点评 @${target.author}', style: YuanType.titleSm),
                const SizedBox(height: YuanSpace.md),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  minLines: 1,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: '写下你的点评…',
                    counterText: '',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: YuanSpace.sm),
                FilledButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          final text = ctrl.text.trim();
                          if (text.isEmpty) {
                            _toast('请输入点评内容');
                            return;
                          }
                          setSheet(() => submitting = true);
                          try {
                            final api = context.read<AppState>().api;
                            final hash = await _formhash();
                            final msg = await api.addComment(
                              tid: d.tid,
                              pid: target.pid,
                              message: text,
                              formhash: hash,
                            );
                            if (!c.mounted) return;
                            Navigator.of(c).pop();
                            _toast(msg);
                            await _load(1);
                          } catch (e) {
                            setSheet(() => submitting = false);
                            if (c.mounted) {
                              _toast(e is AppException ? e.displayMessage : '网络错误，请重试');
                            }
                          }
                        },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(submitting ? '提交中…' : '发表点评'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    ctrl.dispose();
  }

  // ---------------------------------------------------------------- 举报 / 编辑 / 删除

  static const List<String> _reportReasons = ['广告垃圾', '违规内容', '重复发帖', '恶意灌水', '其他'];

  /// 当前用户是否为该楼层作者。
  bool _isMine(Post p) {
    final uid = context.read<AppState>().user?.uid ?? 0;
    final authorId = p.authorId ?? 0;
    return uid > 0 && authorId > 0 && authorId == uid;
  }

  Future<void> _showReportSheet(Post target) async {
    final d = _detail;
    if (d == null) return;
    if (!context.read<AppState>().loggedIn) {
      _toast('请先登录');
      return;
    }
    final ctrl = TextEditingController();
    var reason = 1;
    var submitting = false;
    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.45,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (c, setSheet) => Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                YuanSpace.xl, YuanSpace.md, YuanSpace.xl, YuanSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('举报${target.isOp ? '主题' : '该楼层'}', style: YuanType.titleSm),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(c).pop(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: YuanSpace.sm),
                for (var i = 0; i < _reportReasons.length; i++)
                  InkWell(
                    onTap: () => setSheet(() => reason = i + 1),
                    borderRadius: BorderRadius.circular(YuanRadius.xs),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: YuanSpace.sm, horizontal: YuanSpace.xs),
                      child: Row(
                        children: [
                          Icon(
                            reason == i + 1
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 17,
                            color: reason == i + 1
                                ? YuanSemanticColors.of(c).brandPrimary
                                : YuanSemanticColors.of(c).textTertiary,
                          ),
                          const SizedBox(width: YuanSpace.sm),
                          Expanded(
                            child: Text(_reportReasons[i], style: YuanType.bodySm),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: YuanSpace.sm),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  minLines: 1,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    hintText: '补充说明（可选）',
                    counterText: '',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: YuanSpace.md),
                FilledButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          setSheet(() => submitting = true);
                          try {
                            final api = context.read<AppState>().api;
                            final hash = await _formhash();
                            final msg = await api.report(
                              tid: d.tid,
                              fid: d.fid,
                              pid: target.pid,
                              formhash: hash,
                              reason: reason,
                              message: ctrl.text.trim(),
                            );
                            if (!c.mounted) return;
                            Navigator.of(c).pop();
                            _toast(msg);
                          } catch (e) {
                            setSheet(() => submitting = false);
                            if (c.mounted) {
                              _toast(e is AppException ? e.displayMessage : '网络错误，请重试');
                            }
                          }
                        },
                  icon: const Icon(Icons.flag_rounded, size: 18),
                  label: Text(submitting ? '提交中…' : '提交举报'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    ctrl.dispose();
  }

  Future<void> _showEditSheet(Post target) async {
    final d = _detail;
    if (d == null) return;
    if (!_isMine(target)) {
      _toast('只能编辑自己的内容');
      return;
    }
    final subjectCtrl = TextEditingController(text: target.isOp ? d.title : 'Re: ${d.title}');
    final messageCtrl = TextEditingController(
      text: contentPlainText(parsePostContent(target.contentHtml, showLockedHint: false)).trim(),
    );
    var submitting = false;
    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.6,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (c, setSheet) => Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                YuanSpace.xl, YuanSpace.md, YuanSpace.xl, YuanSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('编辑${target.isOp ? '主题' : '回复'}', style: YuanType.titleSm),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(c).pop(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: YuanSpace.sm),
                if (target.isOp)
                  TextField(
                    controller: subjectCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: '标题',
                      isDense: true,
                    ),
                  ),
                const SizedBox(height: YuanSpace.sm),
                Expanded(
                  child: TextField(
                    controller: messageCtrl,
                    maxLines: 20,
                    minLines: 6,
                    decoration: const InputDecoration(
                      hintText: '正文（支持 BBCode）',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: YuanSpace.md),
                FilledButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          final msg = messageCtrl.text.trim();
                          if (msg.isEmpty) {
                            _toast('正文不能为空');
                            return;
                          }
                          setSheet(() => submitting = true);
                          try {
                            final api = context.read<AppState>().api;
                            final hash = await _formhash();
                            final result = await api.editPost(
                              tid: d.tid,
                              fid: d.fid,
                              pid: target.pid,
                              subject: subjectCtrl.text.trim(),
                              message: msg,
                              formhash: hash,
                            );
                            if (!c.mounted) return;
                            Navigator.of(c).pop();
                            _toast(result);
                            await _load(1);
                          } catch (e) {
                            setSheet(() => submitting = false);
                            if (c.mounted) {
                              _toast(e is AppException ? e.displayMessage : '网络错误，请重试');
                            }
                          }
                        },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text(submitting ? '保存中…' : '保存修改'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    subjectCtrl.dispose();
    messageCtrl.dispose();
  }

  Future<void> _confirmDeletePost(Post target) async {
    final d = _detail;
    if (d == null) return;
    if (!_isMine(target)) {
      _toast('只能删除自己的内容');
      return;
    }
    final api = context.read<AppState>().api;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('删除确认'),
        content: Text(
          '确定删除${target.isOp ? '整篇主题' : '第 ${target.floor ?? ''} 楼的回复'}吗？删除后不可恢复。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dc, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final hash = await _formhash();
      final msg = await api.deletePost(
        tid: d.tid,
        fid: d.fid,
        pid: target.pid,
        formhash: hash,
      );
      if (!mounted) return;
      _toast(msg);
      if (target.isOp) {
        Navigator.of(context).maybePop();
        return;
      }
      await _load(1);
    } catch (e) {
      if (mounted) _toast(e is AppException ? e.displayMessage : '网络错误，请重试');
    }
  }

  /// 楼层操作菜单（复制 / 举报 / 打赏 / 编辑 / 删除）。
  Widget _postMenu(Post p, {required bool compact}) {
    return PopupMenuButton<String>(
      tooltip: '更多操作',
      padding: EdgeInsets.zero,
      iconSize: 18,
      icon: Icon(Icons.more_horiz_rounded, color: YuanSemanticColors.of(context).textTertiary),
      onSelected: (value) async {
        switch (value) {
          case 'copy':
            _copyText(
              contentPlainText(parsePostContent(p.contentHtml, showLockedHint: false)).trim(),
            );
          case 'rate':
            await _showRateSheet(p);
          case 'report':
            await _showReportSheet(p);
          case 'edit':
            await _showEditSheet(p);
          case 'delete':
            await _confirmDeletePost(p);
        }
      },
      itemBuilder: (c) => [
        const PopupMenuItem(
          value: 'copy',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.link_rounded, size: 20),
            title: Text('复制正文'),
          ),
        ),
        const PopupMenuItem(
          value: 'report',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.flag_outlined, size: 20),
            title: Text('举报'),
          ),
        ),
        if (p.canRate && !_isMine(p))
          PopupMenuItem(
            value: 'rate',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.volunteer_activism_outlined, size: 20),
              title: Text(p.isOp ? '赞赏' : '打赏'),
            ),
          ),
        if (_isMine(p)) ...[
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined, size: 20),
              title: Text('编辑'),
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline_rounded, size: 20),
              title: Text('删除'),
            ),
          ),
        ],
      ],
    );
  }

  String _floorLabel(Post p, int index) {
    final label = p.floorLabel;
    if (label.isNotEmpty) return label;
    switch (index) {
      case 0:
        return '沙发';
      case 1:
        return '板凳';
      case 2:
        return '报纸';
      default:
        return '${index + 2} 楼';
    }
  }

  /// 用户组等级徽章（如 Lv.7）。
  Widget _levelBadge(String label) {
    final semantic = YuanSemanticColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: semantic.brandPrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: YuanType.caption.copyWith(
          color: semantic.brandPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 关注 / 已关注。已关注用弱化的描边，避免和正文抢视觉。
  Widget _followChip({required bool following, required VoidCallback? onTap}) {
    final semantic = YuanSemanticColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: following ? Colors.transparent : semantic.brandPrimary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: following
                ? semantic.outlineSubtle
                : semantic.brandPrimary.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          following ? '已关注' : '关注',
          style: YuanType.label.copyWith(
            color: following ? semantic.textTertiary : semantic.brandPrimary,
          ),
        ),
      ),
    );
  }

  Widget _outlineChip(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: YuanSemanticColors.of(context).outlineSubtle),
      ),
      child: Text(
        label,
        style: YuanType.label.copyWith(color: YuanSemanticColors.of(context).textSecondary),
      ),
    );
  }

  Widget _endTip(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Text(
          '已经到底了',
          style: YuanType.label.copyWith(color: YuanSemanticColors.of(context).textTertiary),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 提示条

  Widget _lockedBanner(ThemeData theme, ThreadDetail d) {
    final isPurchase = d.needsPurchase;
    final semantic = YuanSemanticColors.of(context);
    final color = isPurchase ? semantic.brandTertiary : semantic.brandPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isPurchase ? Icons.shopping_bag_outlined : Icons.lock_outline_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPurchase ? '该主题需要购买后浏览' : '该主题内容已隐藏',
                  style: YuanType.titleSm.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  d.lockedText ?? '回复本帖后即可查看隐藏内容',
                  style: YuanType.bodySm.copyWith(height: 1.6),
                ),
                if (!isPurchase && d.needsReply) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.watch<AppState>().hasReplied(d.tid)
                        ? '已回复，下拉刷新查看隐藏内容'
                        : '开启「隐藏贴自动回复」后打开帖子会自动回复解锁',
                    style: YuanType.label.copyWith(color: semantic.textTertiary),
                  ),
                ],
                if (isPurchase) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _buying ? null : () => _purchase(d),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: color,
                        ),
                        icon: _buying
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.shopping_cart_checkout_rounded, size: 15),
                        label: Text(
                          _buying ? '正在购买…' : (d.payPriceText == null ? '购买主题' : '购买（${d.payPriceText}）'),
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                      if (d.payBuyers > 0) ...[
                        const SizedBox(width: 10),
                        Text(
                          '已有 ${d.payBuyers} 人购买',
                          style: YuanType.label.copyWith(color: semantic.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 应用内购买付费主题：走 Discuz misc&action=pay 流程，
  /// 完成后重新拉取帖子验证解锁。
  Future<void> _purchase(ThreadDetail d) async {
    if (_buying) return;
    if (!context.read<AppState>().loggedIn) {
      _toast('请先登录');
      return;
    }
    setState(() => _buying = true);
    try {
      final res = await context.read<AppState>().buyThread(d);
      if (!mounted) return;
      _toast(res.message);
      if (res.success) await _load(1);
    } catch (e) {
      if (mounted) _toast('网络错误，请重试');
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  // ---------------------------------------------------------------- 附件下载

  /// 下载附件：优先公共 Download 目录，受限存储（Android 10+）回落应用目录；
  /// 复用登录 Cookie 与帖子页 Referer（附件直链需要会话）。
  Future<void> _downloadAttachment(PostAttachment a) async {
    final cur = _dls[a.key];
    if (cur != null && cur.busy) return;
    setState(() => _dls[a.key] = const _DlState(busy: true));
    final st = context.read<AppState>();
    try {
      const svc = IoDownloadService();
      final headers = <String, String>{
        'Cookie': st.client.cookieHeader,
        'Referer': _threadUrl(),
        'User-Agent': DiscuzClient.userAgent,
      };
      String path;
      try {
        final dir = await svc.resolveTargetDirectory();
        path = await svc.download(
          url: Uri.parse(a.url),
          targetDir: dir,
          suggestedName: a.name,
          headers: headers,
          onProgress: (received, total) {
            if (!mounted) return;
            setState(() {
              _dls[a.key] = _DlState(
                busy: true,
                progress: total != null && total > 0 ? received / total : null,
                received: received,
                totalBytes: total,
              );
            });
          },
        );
      } catch (_) {
        // scoped storage 不可写 → 应用专属目录回落
        final dir = await DownloadPaths.fallbackAppDir();
        path = await svc.download(
          url: Uri.parse(a.url),
          targetDir: dir,
          suggestedName: a.name,
          headers: headers,
        );
      }
      if (!mounted) return;
      setState(() => _dls[a.key] = _DlState(done: true, path: path));
      _toast('已保存：$path');
    } catch (e) {
      if (!mounted) return;
      setState(() => _dls[a.key] = _DlState(error: '下载失败：$e'));
      _toast('下载失败：$e');
    }
  }

  /// 该楼是否有可渲染的正文。
  ///
  /// 附件块（`<ignore_js_op>`）已从正文抽出，剩下的可能只有空白、`&nbsp;` 或 `<br>`，
  /// 直接按 `contentHtml.isEmpty` 判断会把「只有附件的帖子」误报成内容不可见。
  bool _hasVisibleBody(Post p) {
    if (p.contentHtml.contains('<img')) return true;
    return contentPlainText(parsePostContent(p.contentHtml, showLockedHint: false)).trim().isNotEmpty;
  }

  Widget _attachmentList(List<PostAttachment> atts) {
    final semantic = YuanSemanticColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: semantic.surfaceContainer,
        borderRadius: BorderRadius.circular(YuanRadius.sm),
      ),
      child: Column(
        children: [
          for (final a in atts)
            _attachmentTile(a, semantic, a == atts.last),
        ],
      ),
    );
  }

  Widget _attachmentTile(PostAttachment a, YuanSemanticColors semantic, bool last) {
    final state = _dls[a.key] ?? const _DlState();
    final icon = _iconFor(a.name);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 17, color: semantic.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                // 与论坛移动端一致：文件名与大小同行，「名字 (13.83 KB)」
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: a.name,
                        style: YuanType.bodySm.copyWith(fontWeight: FontWeight.w500),
                      ),
                      if (a.sizeText != null)
                        TextSpan(
                          text: '  (${a.sizeText})',
                          style: YuanType.caption.copyWith(color: semantic.textTertiary),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (state.busy && state.progress != null)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    value: state.progress,
                    strokeWidth: 2.2,
                    color: semantic.brandPrimary,
                  ),
                )
              else if (state.busy)
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              else
                InkWell(
                  onTap: state.done ? null : () => _downloadAttachment(a),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      state.done ? Icons.check_circle_rounded : Icons.download_rounded,
                      size: 20,
                      color: state.done ? semantic.success : semantic.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                state.error!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: YuanType.caption.copyWith(color: semantic.danger),
              ),
            ),
          ),
        if (state.busy && state.progress != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 3,
                color: semantic.brandPrimary,
                backgroundColor: semantic.outlineSubtle,
              ),
            ),
          ),
        if (!last) Divider(height: 1, color: semantic.outlineSubtle),
      ],
    );
  }

  IconData _iconFor(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'txt':
      case 'md':
        return Icons.description_rounded;
      case 'doc':
      case 'docx':
        return Icons.article_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'apk':
        return Icons.android_rounded;
      case 'mp3':
      case 'flac':
      case 'wav':
        return Icons.audiotrack_rounded;
      case 'mp4':
      case 'mkv':
        return Icons.movie_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Widget _autoReplyTip(ThemeData theme) {
    final semantic = YuanSemanticColors.of(context);
    final color = _autoReplyBusy ? semantic.brandPrimary : semantic.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (_autoReplyBusy)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(Icons.error_outline_rounded, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _autoReplyHint!,
              style: YuanType.label.copyWith(color: color),
            ),
          ),
          if (!_autoReplyBusy)
            TextButton(
              onPressed: () => _load(1),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('重试', style: TextStyle(fontSize: 12.5)),
            ),
        ],
      ),
    );
  }

  Widget _pager(ThemeData theme, ThreadDetail d) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton(
            onPressed: _loadingMore ? null : () => _load(d.page - 1 < 1 ? 1 : d.page - 1, replace: true),
            child: const Text('上一页'),
          ),
          const SizedBox(width: 12),
          Text('${d.page} / ${d.totalPages}', style: YuanType.label),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _loadingMore ? null : () => _load(d.page + 1, replace: true),
            child: _loadingMore
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('下一页'),
          ),
        ],
      ),
    );
  }

  /// 底部悬浮玻璃回复栏（收起 / 展开由本页状态驱动）。
  Widget _replyBar() {
    return GlassReplyBar(
      controller: _replyCtrl,
      expanded: _replyExpanded,
      onExpandedChanged: (v) => setState(() => _replyExpanded = v),
      onSend: _sendReply,
      onLike: _toggleSupport,
      onFavorite: _toggleFavorite,
      onShare: _showShareSheet,
      liked: _liked,
      favorited: _favorited,
      sending: _sending,
      busy: _actionBusy,
      replyTargetPid: _replyTargetPid,
      replyTargetAuthor: _replyTargetAuthor,
      onReplyTargetCleared: () => setState(() {
        _replyTargetPid = null;
        _replyTargetAuthor = null;
        _replyCtrl.text = '';
      }),
    );
  }

  /// 清空回复目标（发送成功后调用）。
  void _clearReplyTarget() {
    _replyTargetPid = null;
    _replyTargetAuthor = null;
  }

  /// 点赞（站点叫「支持」）：一次性操作，成功后本地保持高亮。
  Future<void> _toggleSupport() async {
    final url = _detail?.supportUrl;
    if (url == null) return;
    if (_liked) {
      _toast('已支持过本帖');
      return;
    }
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    final res = await context.read<AppState>().api.supportThread(url);
    if (!mounted) return;
    setState(() {
      _actionBusy = false;
      if (res.success) _liked = true;
    });
    _toast(res.message);
  }

  /// 收藏：成功后本地标记；站点未提供「取消收藏」入口，故不做反向操作。
  Future<void> _toggleFavorite() async {
    final url = _detail?.favoriteUrl;
    if (url == null) return;
    if (_favorited) {
      _toast('已收藏本帖');
      return;
    }
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    final res = await context.read<AppState>().api.favoriteThread(url);
    if (!mounted) return;
    setState(() {
      _actionBusy = false;
      if (res.success) _favorited = true;
    });
    _toast(res.message);
  }

  /// 关注 / 取消关注楼主。
  Future<void> _toggleFollow() async {
    final d = _detail;
    final uid = _opPost()?.authorId;
    if (d == null || d.followUrl == null || uid == null) return;
    if (_followBusy) return;
    setState(() => _followBusy = true);
    final next = !_following;
    final res = await context.read<AppState>().api.setFollow(
          uid: uid,
          follow: next,
          hash: d.followHash,
        );
    if (!mounted) return;
    setState(() {
      _followBusy = false;
      if (res.success) _following = next;
    });
    _toast(res.message);
  }

  bool _canShareAsImage() {
    final d = _detail;
    final op = _opPost();
    if (d == null || op == null) return false;
    if ((d.needsPurchase || d.needsLogin || d.isLocked) && !_hasVisibleBody(op)) {
      return false;
    }
    return canShareThreadAsImage(op.contentHtml);
  }

  /// 分享：玻璃弹层提供「分享为图片 / 复制链接 / 在浏览器打开」。
  Future<void> _showShareSheet() async {
    final url = _threadUrl();
    final canImage = _canShareAsImage();
    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.42,
      builder: (sheetCtx) => Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            YuanSpace.xl,
            YuanSpace.xs,
            YuanSpace.xl,
            YuanSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('分享本帖', style: YuanType.titleSm),
              const SizedBox(height: YuanSpace.md),
              _ShareAction(
                key: const ValueKey('share-as-image'),
                icon: Icons.image_outlined,
                label: '分享为图片',
                enabled: canImage,
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  if (!canImage) {
                    _toast('正文需登录或购买后可见');
                    return;
                  }
                  await _shareAsImage();
                },
              ),
              const SizedBox(height: YuanSpace.xs),
              _ShareAction(
                icon: Icons.link_rounded,
                label: '复制链接',
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await _copyText(url, okHint: '链接已复制');
                },
              ),
              const SizedBox(height: YuanSpace.xs),
              _ShareAction(
                icon: Icons.open_in_browser_rounded,
                label: '在浏览器打开',
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareAsImage() async {
    final d = _detail;
    final op = _opPost();
    if (d == null || op == null) return;
    final progressNotifier = ValueNotifier<(String, double)>(('正在生成分享图片', 0.05));
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<(String, double)>(
            valueListenable: progressNotifier,
            builder: (c, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value.$1, style: YuanType.bodyMd),
                const SizedBox(height: YuanSpace.md),
                LinearProgressIndicator(value: value.$2.clamp(0.05, 1)),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final st = context.read<AppState>();
      final blocks = parsePostContent(op.contentHtml, showLockedHint: false);
      final svc = ShareImageService();
      final threadUrl = _threadUrl();
      final outcome = await svc.generateAndShare(
        title: d.title,
        author: op.author,
        authorAvatarUrl: op.avatar,
        timeText: op.timeText ?? '',
        blocks: blocks,
        siteName: st.site.name,
        threadUrl: threadUrl,
        onPhase: (p, v) => progressNotifier.value = (p, v),
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final shareResult = await sharePngFile(
        path: outcome.path,
        fileName: outcome.path.split(RegExp(r'[/\\]')).last,
        shareText: '${d.title}\n$threadUrl',
        bytes: outcome.bytes,
      );
      if (!mounted) return;
      final hint = shareResult.hint ?? outcome.hint;
      if ((hint ?? '').isNotEmpty) _toast(hint!);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final msg = e is AppException ? e.displayMessage : '生成分享图片失败';
      await _showShareFail(msg);
    } finally {
      progressNotifier.dispose();
    }
  }

  Future<void> _showShareFail(String message) async {
    final url = _threadUrl();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('分享失败'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _copyText(url, okHint: '链接已复制');
            },
            child: const Text('复制链接'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

}

/// 分享弹层中的单条操作。
class _ShareAction extends StatelessWidget {
  const _ShareAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final semantic = YuanSemanticColors.of(context);
    final color = enabled ? semantic.textSecondary : semantic.textTertiary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(YuanRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: YuanSpace.sm,
          vertical: YuanSpace.sm,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: YuanSpace.sm),
            Text(
              label,
              style: YuanType.bodyMd.copyWith(
                color: enabled ? null : semantic.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 附件下载条目状态。
class _DlState {
  final bool busy;
  final bool done;
  final double? progress;
  final int? received;
  final int? totalBytes;
  final String? path;
  final String? error;

  const _DlState({
    this.busy = false,
    this.done = false,
    this.progress,
    this.received,
    this.totalBytes,
    this.path,
    this.error,
  });
}
