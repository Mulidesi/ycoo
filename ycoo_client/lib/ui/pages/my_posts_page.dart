import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/discuz_client.dart';
import '../../core/navigation/user_nav.dart';
import '../../design/tokens.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/thread_tile.dart';
import 'thread_detail_page.dart';

/// 我的帖子：主题 / 回帖双 Tab。
///
/// 主题列表点进主题首页；回帖列表定位到所在主题（Discuz 空间页条目只给主题，
/// 没有稳定的 pid 锚点，先打开主题再看上下文）。
class MyPostsPage extends StatelessWidget {
  const MyPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AppState>().user?.uid ?? 0;
    if (uid <= 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的帖子')),
        body: const EmptyView(message: '登录后查看我的帖子', icon: Icons.lock_outline_rounded),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('我的帖子'),
          bottom: const TabBar(
            tabs: [Tab(text: '主题'), Tab(text: '回帖')],
          ),
        ),
        body: TabBarView(
          children: [
            _PostTab(uid: uid, replies: false),
            _PostTab(uid: uid, replies: true),
          ],
        ),
      ),
    );
  }
}

class _PostTab extends StatefulWidget {
  const _PostTab({required this.uid, required this.replies});

  final int uid;
  final bool replies;

  @override
  State<_PostTab> createState() => _PostTabState();
}

class _PostTabState extends State<_PostTab> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _items = <ThreadItem>[];
  int _page = 0;
  int _totalPages = 1;
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(1);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 420 && _page < _totalPages) {
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
      final api = context.read<AppState>().api;
      final res = widget.replies
          ? await api.userReplies(uid: widget.uid, page: page)
          : await api.userThreads(uid: widget.uid, page: page);
      if (!mounted) return;
      setState(() {
        if (page == 1) _items.clear();
        _items.addAll(res.items.where((e) => !_items.any((x) => x.tid == e.tid)));
        _page = res.page;
        _totalPages = res.totalPages;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ForumException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error != null) {
      return ErrorView(message: _error!, onRetry: () => _load(1));
    }
    if (_items.isEmpty) {
      return EmptyView(
        message: widget.replies ? '还没有回帖' : '还没有发表主题',
        action: TextButton(onPressed: () => _load(1), child: const Text('刷新')),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(1),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(YuanSpace.sm, YuanSpace.sm, YuanSpace.sm, YuanSpace.xl),
        itemCount: _items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (c, i) {
          if (i == _items.length) return _footer();
          final item = _items[i];
          return ThreadTile(
            item: item,
            showBoard: true,
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
  }

  Widget _footer() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: YuanSpace.md),
        child: Center(
          child: TextButton(
            onPressed: () => _load(_page + 1),
            child: Text(_error!),
          ),
        ),
      );
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (_page >= _totalPages) {
      return Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Center(
          child: Text(
            '已经到底了',
            style: YuanType.label.copyWith(color: YuanSemanticColors.of(context).textTertiary),
          ),
        ),
      );
    }
    return const SizedBox(height: YuanSpace.lg);
  }
}
