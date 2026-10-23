import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/discuz_client.dart';
import '../../design/tokens.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/thread_tile.dart';
import 'thread_detail_page.dart';

/// 他人公开资料与主题列表。与「我的」页分离，不含设置入口。
class UserSpacePage extends StatefulWidget {
  const UserSpacePage({super.key, required this.uid, this.username});

  final int uid;
  final String? username;

  @override
  State<UserSpacePage> createState() => _UserSpacePageState();
}

class _UserSpacePageState extends State<UserSpacePage> {
  final _scroll = ScrollController();
  UserProfile? _profile;
  final _threads = <ThreadItem>[];
  int _page = 0;
  int _totalPages = 1;
  bool _loadingProfile = true;
  bool _loadingThreads = false;
  String? _profileError;
  String? _threadError;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 420 &&
        !_loadingThreads &&
        _page < _totalPages &&
        _profileError == null) {
      _loadThreads(_page + 1);
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
      _threadError = null;
      _threads.clear();
      _page = 0;
      _totalPages = 1;
    });
    await Future.wait([_loadProfile(), _loadThreads(1)]);
  }

  Future<void> _loadProfile() async {
    try {
      final p = await context.read<AppState>().api.userProfile(widget.uid);
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loadingProfile = false;
        _profileError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _profileError = e is ForumException ? e.message : e.toString();
      });
    }
  }

  Future<void> _loadThreads(int page) async {
    if (_loadingThreads) return;
    setState(() {
      _loadingThreads = true;
      if (page == 1) _threadError = null;
    });
    try {
      final res = await context.read<AppState>().api.userThreads(uid: widget.uid, page: page);
      if (!mounted) return;
      setState(() {
        if (page == 1) _threads.clear();
        _threads.addAll(res.items.where((e) => !_threads.any((x) => x.tid == e.tid)));
        _page = res.page;
        _totalPages = res.totalPages;
        _threadError = null;
        _loadingThreads = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _threadError = e is ForumException ? e.message : e.toString();
        _loadingThreads = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _profile?.username ?? widget.username ?? '个人中心';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loadingProfile && _profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_profileError != null && _profile == null) {
      return ErrorView(message: _profileError!, onRetry: _reload);
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _profileCard()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(YuanSpace.md, YuanSpace.lg, YuanSpace.md, YuanSpace.xs),
              child: Text(
                '主题',
                style: YuanType.titleSm.copyWith(
                  color: YuanSemanticColors.of(context).textSecondary,
                ),
              ),
            ),
          ),
          ..._threadSlivers(),
        ],
      ),
    );
  }

  List<Widget> _threadSlivers() {
    if (_threadError != null && _threads.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: ErrorView(message: _threadError!, onRetry: () => _loadThreads(1)),
        ),
      ];
    }
    if (!_loadingThreads && _threads.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: SizedBox(
            height: 240,
            child: EmptyView(message: '该用户还没有发表主题'),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(YuanSpace.sm, YuanSpace.xs, YuanSpace.sm, YuanSpace.xs),
        sliver: SliverList.separated(
          itemCount: _threads.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (c, i) {
            final item = _threads[i];
            return ThreadTile(
              item: item,
              showBoard: true,
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
      ),
      SliverToBoxAdapter(child: _footer()),
    ];
  }

  Widget _footer() {
    if (_threadError != null && _threads.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: YuanSpace.md),
        child: Center(
          child: TextButton(
            onPressed: () => _loadThreads(_page + 1),
            child: Text(_threadError!),
          ),
        ),
      );
    }
    if (_loadingThreads) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_page >= _totalPages) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(0, 18, 0, YuanSpace.xxl),
        child: Center(child: Text('已经到底了', style: TextStyle(fontSize: 12, color: Colors.grey))),
      );
    }
    return const SizedBox(height: YuanSpace.xxl);
  }

  Widget _profileCard() {
    final u = _profile;
    final semantic = YuanSemanticColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(YuanSpace.md, YuanSpace.sm, YuanSpace.md, 0),
      child: Container(
        padding: const EdgeInsets.all(YuanSpace.md + 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [YuanColors.brandDeepLight, YuanColors.brandPrimaryLight],
          ),
          borderRadius: BorderRadius.circular(YuanRadius.md + 4),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Avatar(
                    url: u?.avatar,
                    name: u?.username ?? widget.username,
                    size: YuanSizes.avatarProfile * 0.75,
                  ),
                ),
                const SizedBox(width: YuanSpace.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u?.username ?? widget.username ?? '用户',
                        style: YuanType.titleMd.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: YuanSpace.xxs + 1),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (u != null && u.uid > 0) _pill('UID ${u.uid}'),
                          if ((u?.level ?? '').isNotEmpty) _pill(u!.level!),
                          if ((u?.group ?? '').isNotEmpty && u!.group != u.level) _pill(u.group!),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: YuanSpace.md + 2),
            Container(
              padding: const EdgeInsets.symmetric(vertical: YuanSpace.sm),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(YuanRadius.sm + 2),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _metric('人气', u?.views),
                      _metric('关注', u?.following),
                      _metric('粉丝', u?.followers),
                    ],
                  ),
                  const SizedBox(height: YuanSpace.sm),
                  Row(
                    children: [
                      _metric('帖子', u?.threads),
                      _metric('回帖', u?.replies),
                      _metric('积分', u?.points),
                    ],
                  ),
                  const SizedBox(height: YuanSpace.sm),
                  Row(
                    children: [
                      _metric('星币', u?.coins),
                      const Expanded(child: SizedBox()),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ),
            ),
            if (_loadingProfile)
              Padding(
                padding: const EdgeInsets.only(top: YuanSpace.sm),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: Colors.white,
                  backgroundColor: semantic.glassStroke,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(YuanRadius.pill),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10.5)),
      );

  Widget _metric(String label, int? value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value == null ? '—' : thousandCount(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
