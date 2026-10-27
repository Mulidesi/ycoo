import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/discuz_client.dart';
import '../../design/tokens.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'user_space_page.dart';

/// 关注 / 粉丝列表：双 Tab，点条目进入对应用户空间。
class FollowListPage extends StatelessWidget {
  const FollowListPage({super.key, required this.uid, this.username, this.initialTab = 0});

  final int uid;
  final String? username;

  /// 0 = 关注，1 = 粉丝。
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    if (uid <= 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('关注与粉丝')),
        body: const EmptyView(message: '登录后查看关注与粉丝', icon: Icons.lock_outline_rounded),
      );
    }
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          title: Text('${username ?? '用户'}的关注与粉丝'),
          bottom: const TabBar(
            tabs: [Tab(text: '关注'), Tab(text: '粉丝')],
          ),
        ),
        body: TabBarView(
          children: [
            _FollowTab(uid: uid, followers: false),
            _FollowTab(uid: uid, followers: true),
          ],
        ),
      ),
    );
  }
}

class _FollowTab extends StatefulWidget {
  const _FollowTab({required this.uid, required this.followers});

  final int uid;
  final bool followers;

  @override
  State<_FollowTab> createState() => _FollowTabState();
}

class _FollowTabState extends State<_FollowTab> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _items = <FollowUser>[];
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
      final res = await context.read<AppState>().api.followList(
            uid: widget.uid,
            followers: widget.followers,
            page: page,
          );
      if (!mounted) return;
      setState(() {
        if (page == 1) _items.clear();
        _items.addAll(res.items.where((e) => !_items.any((x) => x.uid == e.uid)));
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
        message: widget.followers ? '还没有粉丝' : '还没有关注任何人',
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
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (c, i) {
          if (i == _items.length) return _footer();
          return _userTile(_items[i]);
        },
      ),
    );
  }

  Widget _userTile(FollowUser u) {
    final semantic = YuanSemanticColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: semantic.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(YuanRadius.md),
        border: Border.all(color: semantic.outlineSubtle, width: 0.9),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => UserSpacePage(uid: u.uid, username: u.username),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              YuanSpace.sm + 2,
              YuanSpace.sm,
              YuanSpace.xs,
              YuanSpace.sm,
            ),
            child: Row(
              children: [
                Avatar(url: u.avatar, name: u.username, size: YuanSizes.avatarReply),
                const SizedBox(width: YuanSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: YuanType.titleSm.copyWith(fontSize: 13.5),
                      ),
                      if ((u.note ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          u.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: YuanType.label.copyWith(color: semantic.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: semantic.textTertiary),
              ],
            ),
          ),
        ),
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
