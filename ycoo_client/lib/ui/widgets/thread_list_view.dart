import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/user_nav.dart';
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
class ThreadListView extends StatefulWidget {
  const ThreadListView({
    super.key,
    required this.loader,
    this.header,
    this.emptyText = '这里还没有帖子',
    this.showBoard = false,
    this.previewPage,
  });

  final Future<ThreadPage> Function(int page) loader;
  final Widget? header;
  final String emptyText;

  /// 是否显示版块标签（信息流里有用）
  final bool showBoard;

  /// 预览请求用的版块页码；导读类列表跨版块，统一取第 1 页
  final int Function(int page)? previewPage;

  @override
  State<ThreadListView> createState() => _ThreadListViewState();
}

class _ThreadListViewState extends State<ThreadListView> with AutomaticKeepAliveClientMixin {
  final _items = <ThreadItem>[];
  final _controller = ScrollController();
  int _page = 0;
  int _totalPages = 1;
  bool _loading = false;
  bool _initialLoading = true;
  String? _error;

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
    _load(1);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    if (pos.pixels >= pos.maxScrollExtent - 420 && !_loading && _page < _totalPages) {
      _load(_page + 1);
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
        _items.addAll(res.items.where((e) => !_items.any((x) => x.tid == e.tid)));
        _page = res.page;
        _totalPages = res.totalPages;
        _initialLoading = false;
        _error = null;
      });
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
    if (_initialLoading) return const LoadingList();
    if (_error != null && _items.isEmpty) {
      return ErrorView(message: _error!, onRetry: () => _load(1));
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(1),
        child: ListView(
          padding: EdgeInsets.only(bottom: barInset),
          children: [
            if (widget.header != null) widget.header!,
            SizedBox(
              height: 320,
              child: EmptyView(message: widget.emptyText),
            ),
          ],
        ),
      );
    }

    final store = _previews;
    if (store == null) return const LoadingList();

    return AnimatedBuilder(
      animation: store,
      builder: (c, _) {
        return RefreshIndicator(
          onRefresh: () => _load(1),
          child: ListView.separated(
            controller: _controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(12, 10, 12, 24 + barInset),
            itemCount: _items.length + 1 + (widget.header != null ? 1 : 0),
            separatorBuilder: (c, i) => const SizedBox(height: 10),
            itemBuilder: (c, index) {
              var i = index;
              if (widget.header != null) {
                if (i == 0) return widget.header!;
                i -= 1;
              }
              if (i == _items.length) return _footer();
              final item = _items[i];
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

  Widget _footer() {
    if (_page >= _totalPages) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text('已经到底了', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}
