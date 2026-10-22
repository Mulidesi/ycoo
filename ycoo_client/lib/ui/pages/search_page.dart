import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/user_nav.dart';
import '../../core/utils/content_filter.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/thread_tile.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
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
      final items = await context.read<AppState>().api.search(kw);
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
            hintText: '搜索帖子标题 / 关键词',
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
      body: _body(theme),
    );
  }

  Widget _body(ThemeData theme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(message: _error!, onRetry: _search);
    if (_items == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_search_rounded, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              '输入关键词搜索源论坛的帖子',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 6),
            Text(
              '提示：部分版块或敏感词需要登录后才会返回结果',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                color: theme.colorScheme.outline.withOpacity(0.8),
              ),
            ),
          ],
        ),
      );
    }
    if (_items!.isEmpty) {
      return const EmptyView(message: '没有找到相关帖子', icon: Icons.search_off_rounded);
    }
    final filter = context.select<AppState, ({bool enabled, List<String> keywords})>(
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
