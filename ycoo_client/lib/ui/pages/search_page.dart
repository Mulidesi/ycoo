import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/user_nav.dart';
import '../../core/utils/content_filter.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/thread_tile.dart';
import 'boards_page.dart';
import 'thread_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<ThreadItem>? _items;
  bool _loading = false;
  String? _error;

  // 筛选条件，与网页端 search.php 表单一一对应
  String _scope = '_all'; // 全文 / 标题 / 用户名
  String _sort = 'relevance'; // relevance / dateline_DESC / dateline_ASC
  int _fid = 0; // 0 = 所有版块
  bool _fuzzy = false;
  bool _synonym = true;
  List<BoardGroup>? _boards;
  bool _boardsLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _loadBoards();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadBoards() async {
    if (_boards != null || _boardsLoading) return;
    setState(() => _boardsLoading = true);
    try {
      _boards = await loadBoards(context);
    } catch (_) {
      _boards = null;
    }
    if (!mounted) return;
    setState(() => _boardsLoading = false);
  }

  Future<void> _search() async {
    final kw = _ctrl.text.trim();
    if (kw.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<AppState>().api.search(
        kw,
        searchField: _scope,
        sortBy: _sort,
        fid: _fid,
        fuzzy: _fuzzy,
        synonym: _synonym,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      context.read<AppState>().previews.request(items, page: 1);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _refilter() {
    _loadBoards();
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: _scope == '_all'
                ? '搜索帖子标题 / 关键词'
                : _scope == 'subject'
                ? '只搜索标题'
                : '搜索用户名',
            isDense: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _ctrl.clear()),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          TextButton(onPressed: _search, child: const Text('搜索')),
          const SizedBox(width: 6),
        ],
      ),
      body: _items == null
          ? _body(theme)
          : Column(
              children: [
                _filterBar(theme),
                Expanded(child: _body(theme)),
              ],
            ),
    );
  }

  Widget _filterBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '_all', label: Text('全文')),
              ButtonSegment(value: 'subject', label: Text('标题')),
              ButtonSegment(value: 'author', label: Text('用户名')),
            ],
            selected: {_scope},
            onSelectionChanged: (s) {
              if (s.first == _scope) return;
              setState(() => _scope = s.first);
              _refilter();
            },
          ),
          ActionChip(
            label: Text(
              _sort == 'relevance'
                  ? '相关性'
                  : _sort == 'dateline_DESC'
                  ? '时间倒序'
                  : '时间顺序',
            ),
            onPressed: () => _pickSort(theme),
          ),
          ActionChip(
            label: _fid == 0
                ? const Text('所有版块')
                : Text(_boardName(_fid) ?? '版块 $_fid'),
            onPressed: _boardsLoading ? null : () => _pickBoard(theme),
          ),
          FilterChip(
            label: const Text('模糊'),
            selected: _fuzzy,
            onSelected: (v) {
              setState(() => _fuzzy = v);
              _refilter();
            },
          ),
          FilterChip(
            label: const Text('同义词'),
            selected: _synonym,
            onSelected: (v) {
              setState(() => _synonym = v);
              _refilter();
            },
          ),
        ],
      ),
    );
  }

  void _pickSort(ThemeData theme) {
    const values = ['relevance', 'dateline_DESC', 'dateline_ASC'];
    const labels = ['相关性', '时间倒序', '时间顺序'];
    showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('排序方式'),
        children: [
          for (var i = 0; i < labels.length; i++)
            SimpleDialogOption(
              child: Text(
                labels[i],
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: values[i] == _sort ? null : theme.colorScheme.outline,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(values[i]),
            ),
        ],
      ),
    ).then((v) {
      if (v != null && v != _sort) {
        setState(() => _sort = v);
        _refilter();
      }
    });
  }

  void _pickBoard(ThemeData theme) {
    showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (c) {
        final groups = _boards ?? const [];
        final listH = (MediaQuery.sizeOf(c).height * 0.38).clamp(220.0, 340.0);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text('在哪个版块搜索', style: theme.textTheme.titleSmall),
              ),
              SizedBox(
                height: listH,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.all_inbox_rounded, size: 20),
                      title: const Text('所有版块'),
                      selected: _fid == 0,
                      onTap: () => Navigator.of(context).pop(0),
                    ),
                    for (final g in groups) ...<Widget>[
                      Text(
                        g.name,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      for (final b in g.boards)
                        ListTile(
                          leading: b.isPrivate
                              ? const Icon(Icons.lock_rounded, size: 18)
                              : const Icon(Icons.forum_rounded, size: 18),
                          title: Text(b.name),
                          selected: _fid == b.fid,
                          onTap: () => Navigator.of(context).pop(b.fid),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ).then((v) {
      if (v != null && v != _fid) {
        setState(() => _fid = v);
        _refilter();
      }
    });
  }

  String? _boardName(int fid) {
    for (final g in _boards ?? const []) {
      for (final b in g.boards) {
        if (b.fid == fid) return b.name;
      }
    }
    return null;
  }

  Widget _body(ThemeData theme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(message: _error!, onRetry: _search);
    if (_items == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              '输入关键词搜索源论坛的帖子',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '提示：部分版块或敏感词需要登录后才会返回结果',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                color: theme.colorScheme.outline.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      );
    }
    if (_items!.isEmpty) {
      final filtered = _scope != '_all' || _fid != 0 || _fuzzy;
      return EmptyView(
        message: filtered ? '没有符合条件的帖子，试试调整筛选' : '没有找到相关帖子',
        icon: filtered
            ? Icons.filter_alt_off_rounded
            : Icons.search_off_rounded,
      );
    }
    final filter = context
        .select<AppState, ({bool enabled, List<String> keywords})>(
          (st) => (
            enabled: st.settings.postFilterEnabled,
            keywords: st.settings.postFilterKeywords,
          ),
        );
    final visible = filterThreadsByKeywords(
      _items!,
      enabled: filter.enabled,
      keywords: filter.keywords,
    );
    if (visible.isEmpty) {
      return EmptyView(
        message: '已过滤 ${_items!.length} 条关键词帖子',
        icon: Icons.filter_alt_off_rounded,
      );
    }
    final store = context.read<AppState>().previews;
    return AnimatedBuilder(
      animation: store,
      builder: (c, _) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        itemCount: visible.length,
        separatorBuilder: (c, i) => const SizedBox(height: 10),
        itemBuilder: (c, i) {
          final t = visible[i];
          return ThreadTile(
            item: t,
            preview: store.of(t.tid),
            showBoard: true,
            onAvatarTap: () => openUserFromAvatar(
              context,
              uid: t.authorId,
              username: t.author,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ThreadDetailPage(
                  tid: t.tid,
                  title: t.title,
                  fid: t.fid,
                  boardName: t.typeName,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
