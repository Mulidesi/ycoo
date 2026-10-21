import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/net_image.dart';
import 'search_page.dart';
import 'thread_list_page.dart';

class BoardsPage extends StatefulWidget {
  const BoardsPage({super.key});

  @override
  State<BoardsPage> createState() => _BoardsPageState();
}

class _BoardsPageState extends State<BoardsPage> with AutomaticKeepAliveClientMixin {
  List<BoardGroup>? _groups;
  String? _error;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await context.read<AppState>().api.boards();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final st = context.watch<AppState>();
    final favFids = st.settings.favoriteFids;
    final favBoards = <Board>[
      for (final g in _groups ?? const <BoardGroup>[])
        for (final b in g.boards)
          if (favFids.contains(b.fid)) b,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('版块'),
        actions: [
          IconButton(
            tooltip: '搜索',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SearchPage()),
            ),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      if (favBoards.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 3,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '我的收藏',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final b in favBoards)
                              ActionChip(
                                avatar: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                                label: Text(b.name, style: const TextStyle(fontSize: 12.5)),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ThreadListPage(fid: b.fid, name: b.name),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      for (final g in _groups!) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 3,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                g.name,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${g.boards.length} 个版块',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        LayoutBuilder(
                          builder: (c, cons) {
                            final cols = cons.maxWidth > 1040
                                ? 3
                                : cons.maxWidth > 640
                                    ? 2
                                    : 1;
                            final w = (cons.maxWidth - 12 * (cols - 1)) / cols;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final b in g.boards)
                                  SizedBox(width: w, child: _boardCard(theme, b)),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _boardCard(ThemeData theme, Board b) {
    final st = context.watch<AppState>();
    final isFav = st.isFavoriteBoard(b.fid);
    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ThreadListPage(fid: b.fid, name: b.name)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                clipBehavior: Clip.antiAlias,
                child: b.icon == null
                    ? Icon(Icons.forum_rounded, size: 20, color: theme.colorScheme.primary)
                    : NetImage(
                        url: b.icon!,
                        fit: BoxFit.cover,
                        showRetry: false,
                        errorBuilder: (c) =>
                            Icon(Icons.forum_rounded, size: 20, color: theme.colorScheme.primary),
                      ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            b.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (b.isPrivate) ...[
                          const SizedBox(width: 6),
                          const TagChip(label: '私密', color: Color(0xFF94A3B8)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '主题 ${humanNumber(b.threads)} · 帖 ${humanNumber(b.posts)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (b.todayPosts > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+${b.todayPosts}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              // 收藏星标
              InkWell(
                onTap: () {
                  st.toggleFavoriteBoard(b.fid);
                  if (!isFav) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已收藏「${b.name}」'),
                        duration: const Duration(milliseconds: 900),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Icon(
                    isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 20,
                    color: isFav ? const Color(0xFFF59E0B) : theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 供其它页面复用：拉版块（搜索页选择范围）
Future<List<BoardGroup>> loadBoards(BuildContext context) => context.read<AppState>().api.boards();
