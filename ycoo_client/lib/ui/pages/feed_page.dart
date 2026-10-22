import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/thread_list_view.dart';
import 'new_thread_page.dart';
import 'search_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  static const _tabs = <({String label, String view})>[
    (label: '最新发表', view: 'newthread'),
    (label: '最新热门', view: 'hot'),
    (label: '最新回复', view: 'new'),
    (label: '最新精华', view: 'digest'),
  ];

  late final TabController _tabController;
  final Map<String, int> _refreshTicks = <String, int>{};
  AppState? _state;
  int _seenHomeTick = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final st = context.read<AppState>();
    if (identical(st, _state)) return;
    _state?.removeListener(_onStateChanged);
    _state = st;
    _seenHomeTick = st.homeRefreshTick;
    st.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _state?.removeListener(_onStateChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// 点击底栏「首页」时只刷新当前选中的信息流，避免一次打四个请求。
  void _onStateChanged() {
    final st = _state;
    if (st == null || !mounted) return;
    if (st.homeRefreshTick == _seenHomeTick) return;
    _seenHomeTick = st.homeRefreshTick;
    final view = _tabs[_tabController.index].view;
    _refreshTicks[view] = (_refreshTicks[view] ?? 0) + 1;
    setState(() {});
  }

  Future<void> _compose() async {
    final ok = await openNewThreadFlow(context);
    if (!ok || !mounted) return;
    setState(() {
      for (final t in _tabs) {
        _refreshTicks[t.view] = (_refreshTicks[t.view] ?? 0) + 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final api = context.read<AppState>().api;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF60A5FA), Color(0xFF2563EB)]),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Text(
                '源',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 9),
            const Text('源坛', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '发帖',
            onPressed: _compose,
            icon: const Icon(Icons.edit_note_rounded),
          ),
          IconButton(
            tooltip: '搜索',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SearchPage()),
            ),
            icon: const Icon(Icons.search_rounded),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppTheme.brand,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: AppTheme.brand,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 2.5,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 14),
              tabs: [for (final t in _tabs) Tab(text: t.label)],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final t in _tabs)
            ThreadListView(
              key: ValueKey<String>('${t.view}-${_refreshTicks[t.view] ?? 0}'),
              loader: (page) => api.guide(t.view, page: page),
              emptyText: '暂无内容',
              showBoard: true,
              // 导读是跨版块聚合，预览统一按各版块第 1 页取
              previewPage: (_) => 1,
            ),
        ],
      ),
    );
  }
}
