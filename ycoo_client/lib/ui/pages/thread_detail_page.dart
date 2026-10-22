import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/discuz_client.dart';
import '../../core/navigation/user_nav.dart';
import '../../core/services/download_service.dart';
import '../../data/content.dart';
import '../../design/tokens.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
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

  /// 附件下载状态（key = attachment.url）
  final Map<String, _DlState> _dls = <String, _DlState>{};

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

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    final d = _detail;
    if (text.isEmpty || d == null) return;
    setState(() => _sending = true);
    final res = await context.read<AppState>().manualReply(d, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (res.success) {
      _replyCtrl.clear();
      FocusScope.of(context).unfocus();
      _toast('回复成功');
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
              }
            },
            itemBuilder: (c) => const [
              PopupMenuItem(value: 'copy', child: Text('复制链接')),
              PopupMenuItem(value: 'browser', child: Text('在浏览器打开')),
            ],
          ),
        ],
      ),
      body: _buildBody(theme, d),
      bottomNavigationBar: loggedIn && d != null ? _replyBar(theme) : null,
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
        color: semantic.surfaceThreadBody,
        borderRadius: BorderRadius.circular(YuanRadius.md),
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
                    Text(
                      op.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: YuanType.titleSm.copyWith(fontSize: 13.5),
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
              _actionButton(
                context,
                theme,
                icon: Icons.share_outlined,
                label: '分享',
                onTap: () => _copyText(_threadUrl(), okHint: '链接已复制'),
              ),
              _actionButton(
                context,
                theme,
                icon: Icons.open_in_browser_rounded,
                label: '浏览器',
                onTap: () => launchUrl(Uri.parse(_threadUrl()), mode: LaunchMode.externalApplication),
              ),
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

  // ---------------------------------------------------------------- 评论

  Widget _commentsHeader(ThemeData theme, int count) {
    final semantic = YuanSemanticColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Row(
        children: [
          Text(
            '全部评论',
            style: YuanType.titleMd.copyWith(fontSize: 15.5),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: YuanType.label.copyWith(color: semantic.textTertiary),
          ),
          const Spacer(),
          _sortChip(theme, '正序', !_desc),
          const SizedBox(width: 6),
          _sortChip(theme, '倒序', _desc),
        ],
      ),
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
          color: active ? semantic.brandPrimary.withOpacity(0.10) : Colors.transparent,
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
        color: semantic.surfaceReply,
        border: Border(
          left: BorderSide(color: semantic.outlineReplyRail, width: YuanSizes.replyRailWidth),
          bottom: index == total - 1
              ? const BorderSide(color: Colors.transparent)
              : BorderSide(color: semantic.outlineSubtle),
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
                    InkWell(
                      onTap: () {
                        _replyCtrl.text = '@${p.author} ';
                        _replyCtrl.selection = TextSelection.collapsed(offset: _replyCtrl.text.length);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Icon(Icons.reply_rounded, size: 15, color: muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _floorLabel(Post p, int index) {
    final raw = (p.floor ?? '').trim();
    if (raw.isNotEmpty && !raw.contains('楼主') && !raw.contains('#')) return raw;
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
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
      _toast('购买前请先登录');
      return;
    }
    setState(() => _buying = true);
    try {
      final res = await context.read<AppState>().buyThread(d);
      if (!mounted) return;
      _toast(res.message);
      if (res.success) await _load(1);
    } catch (e) {
      if (mounted) _toast('购买失败：$e');
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
        color: color.withOpacity(0.08),
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

  Widget _replyBar(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: YuanSemanticColors.of(context).surfaceThreadBody,
          border: Border(top: BorderSide(color: YuanSemanticColors.of(context).outlineSubtle)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _replyCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendReply(),
                decoration: InputDecoration(
                  hintText: '写评论…',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  fillColor: YuanSemanticColors.of(context).surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: YuanSemanticColors.of(context).brandPrimary.withOpacity(0.4)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: '分享',
              onPressed: () => _copyText(_threadUrl(), okHint: '链接已复制'),
              icon: const Icon(Icons.share_outlined, size: 19),
            ),
            IconButton.filled(
              onPressed: _sending ? null : _sendReply,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
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
