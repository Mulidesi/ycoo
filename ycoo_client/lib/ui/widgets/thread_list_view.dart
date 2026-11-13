import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/user_nav.dart';
import '../../core/services/feed_cache.dart';
import '../../core/utils/content_filter.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../state/preview_store.dart';
import '../pages/thread_detail_page.dart';
import 'common.dart';
import 'thread_tile.dart';

/// 通用帖子列表：下拉刷新 + 触底加载更多。
///
/// 列表本身的 HTML 不含首图与摘要，加载完成后按版块向 [PreviewStore]
/// 拉一次移动端接口补全，卡片会在数据到达后原地补上首图。
///
/// 传 [cacheKey] 时启用首页缓存：启动先读缓存展示，下拉刷新才拉取最新内容。
class ThreadListView extends StatefulWidget {
  const ThreadListView({
    super.key,
    required this.loader,
    this.header,
    this.emptyText = '这里还没有帖子',
    this.showBoard = false,
    this.previewPage,
    this.cacheKey,
  });

  final Future<ThreadPage> Function(int page) loader;
  final Widget? header;
  final String emptyText;

  /// 是否显示版块标签（信息流里有用）
  final bool showBoard;

  /// 预览请求用的版块页码；导读类列表跨版块，统一取第 1 页
  final int Function(int page)? previewPage;

  /// 缓存键（如 newthread / hot / new / digest）；为 null 时不启用缓存
  final String? cacheKey;

  @override
  State<ThreadListView> createState() => _ThreadListViewState();
}

class _ThreadListViewState extends State<ThreadListView>
    with AutomaticKeepAliveClientMixin {
  final _items = <ThreadItem>[];
  final _controller = ScrollController();
  int _page = 0;
  int _totalPages = 1;
  bool _loading = false;
  bool _initialLoading = true;
  String? _error;

  FeedCacheEntry? _cacheEntry;
  bool _fromCache = false;

  /// 每分钟刷新缓存提示条的时间文本。
  Timer? _cacheHintTimer;

  PreviewStore? _previews;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _previews ??= context.read<AppState>().previews;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _cacheHintTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _fromCache) setState(() {});
    });
    if (widget.cacheKey != null) {
      _loadFromCache();
    } else {
      _load(1);
    }
  }

  @override
  void dispose() {
    _cacheHintTimer?.cancel();
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    if (pos.pixels >= pos.maxScrollExtent - 420 &&
        !_loading &&
        _page < _totalPages) {
      _load(_page + 1);
    }
  }

  Future<void> _loadFromCache() async {
    final key = widget.cacheKey;
    if (key == null) return;
    final entry = await FeedCache.instance.get(key);
    if (!mounted) return;
    if (entry != null && entry.items.isNotEmpty) {
      setState(() {
        _items
          ..clear()
          ..addAll(entry.items);
        _page = entry.page;
        _totalPages = entry.totalPages;
        _initialLoading = false;
        _fromCache = true;
        _cacheEntry = entry;
      });
      _previews?.request(
        entry.items,
        page: widget.previewPage?.call(entry.page) ?? entry.page,
      );
    } else {
      _load(1);
    }
  }

  Future<void> _load(int page) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (page == 1) _error = null;
    });
    try {
      final res = await widget.loader(page);
      if (!mounted) return;
      setState(() {
        if (page == 1) _items.clear();
        _items.addAll(
          res.items.where((e) => !_items.any((x) => x.tid == e.tid)),
        );
        _page = res.page;
        _totalPages = res.totalPages;
        _initialLoading = false;
        _error = null;
        if (page == 1) {
          _fromCache = false;
          _cacheEntry = null;
        }
      });
      if (widget.cacheKey != null && page == 1) {
        try {
          await FeedCache.instance.put(
            FeedCacheEntry(
              view: widget.cacheKey!,
              items: List.of(_items),
              page: res.page,
              totalPages: res.totalPages,
              cachedAt: DateTime.now(),
            ),
          );
        } catch (_) {
          // 缓存写入失败不影响已展示的数据
        }
      }
      _previews?.request(
        res.items,
        page: widget.previewPage?.call(page) ?? page,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 悬浮底栏盖在内容之上，列表底部要留出它的高度（二级页面为 0）
    final barInset = BottomBarInset.of(context);
    if (_initialLoading) return const SkeletonList();
    if (_error != null && _items.isEmpty) {
      return ErrorView(message: _error!, onRetry: () => _load(1));
    }
    final filter = context
        .select<AppState, ({bool enabled, List<String> keywords})>(
          (st) => (
            enabled: st.settings.postFilterEnabled,
            keywords: st.settings.postFilterKeywords,
          ),
        );
    final visible = filterThreadsByKeywords(
      _items,
      enabled: filter.enabled,
      keywords: filter.keywords,
    );
    final hiddenCount = _items.length - visible.length;
    if (visible.isEmpty) {
      final canLoadMore = _items.isNotEmpty && _page < _totalPages;
      return RefreshIndicator(
        onRefresh: () => _load(1),
        child: ListView(
          padding: EdgeInsets.only(bottom: barInset),
          children: [
            if (widget.header != null) widget.header!,
            SizedBox(
              height: canLoadMore ? 260 : 320,
              child: EmptyView(
                message: _items.isEmpty
                    ? widget.emptyText
                    : '本页 ${_items.length} 条已全部被关键词过滤',
                icon: _items.isEmpty
                    ? Icons.forum_outlined
                    : Icons.filter_alt_off_rounded,
              ),
            ),
            if (canLoadMore)
              Center(
                child: TextButton(
                  onPressed: _loading ? null : () => _load(_page + 1),
                  child: const Text('加载下一页'),
                ),
              ),
          ],
        ),
      );
    }

    final store = _previews;
    if (store == null) return const SkeletonList();

    return AnimatedBuilder(
      animation: store,
      builder: (c, _) {
        final cacheBanner =
            _fromCache && _cacheEntry != null ? _cacheHint() : null;
        return RefreshIndicator(
          onRefresh: () => _load(1),
          child: ListView.separated(
            controller: _controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(12, 10, 12, 24 + barInset),
            itemCount: visible.length +
                1 +
                (widget.header != null ? 1 : 0) +
                (cacheBanner != null ? 1 : 0),
            separatorBuilder: (c, i) => const SizedBox(height: 10),
            itemBuilder: (c, index) {
              var i = index;
              if (cacheBanner != null) {
                if (i == 0) return cacheBanner;
                i -= 1;
              }
              if (widget.header != null) {
                if (i == 0) return widget.header!;
                i -= 1;
              }
              if (i == visible.length) return _footer(hiddenCount);
              final item = visible[i];
              return ThreadTile(
                item: item,
                preview: store.of(item.tid),
                showBoard: widget.showBoard,
                onAvatarTap: () => openUserFromAvatar(
                  context,
                  uid: item.authorId,
                  username: item.author,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ThreadDetailPage(
                      tid: item.tid,
                      title: item.title,
                      fid: item.fid,
                      boardName: item.typeName,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _cacheHint() {
    final diff = DateTime.now().difference(_cacheEntry!.cachedAt);
    final String text;
    if (diff.inMinutes < 1) {
      text = '刚刚';
    } else if (diff.inHours < 1) {
      text = '${diff.inMinutes} 分钟前';
    } else if (diff.inDays < 1) {
      text = '${diff.inHours} 小时前';
    } else {
      text = '${diff.inDays} 天前';
    }
    final color = Theme.of(context).colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '缓存于 $text · 下拉刷新获取最新内容',
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(int hiddenCount) {
    if (_page >= _totalPages) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            hiddenCount > 0 ? '已过滤 $hiddenCount 条 · 已经到底了' : '已经到底了',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: TextButton(
          onPressed: () => _load(_page + 1),
          child: Text(hiddenCount > 0 ? '已过滤 $hiddenCount 条 · 加载更多' : '加载更多'),
        ),
      ),
    );
  }
}
