/// 离线帖子缓存列表页：展示已缓存的帖子，支持离线打开与删除。
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/services/offline_cache.dart';
import '../../design/tokens.dart';
import '../../ui/widgets/html_content.dart';

class OfflineCachePage extends StatefulWidget {
  const OfflineCachePage({super.key});

  @override
  State<OfflineCachePage> createState() => _OfflineCachePageState();
}

class _OfflineCachePageState extends State<OfflineCachePage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await OfflineThreadCache.instance.list();
    } catch (_) {
      _items = [];
    }
    setState(() => _loading = false);
  }

  Future<void> _openOffline(Map<String, dynamic> item) async {
    final tid = (item['tid'] as num?)?.toInt() ?? 0;
    final title = (item['title'] as String?) ?? '';
    final boardName = (item['boardName'] as String?) ?? '';
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OfflineThreadDetailPage(
          tid: tid,
          title: title,
          boardName: boardName,
          snapshot: item,
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final tid = (item['tid'] as num?)?.toInt() ?? 0;
    final title = (item['title'] as String?) ?? '';
    final confirmed = await _confirmDialog(
      '删除离线帖子',
      '确定删除「${title.length > 20 ? '${title.substring(0, 20)}…' : title}」的离线缓存吗？',
    );
    if (!confirmed) return;
    try {
      await OfflineThreadCache.instance.delete(tid);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：${e.toString()}')),
        );
      }
    }
  }

  Future<bool> _confirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final semantic = YuanSemanticColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('离线缓存'),
        actions: [
          IconButton(
            icon: Icon(
              _loading ? Icons.refresh_rounded : Icons.refresh_outlined,
              size: 22,
            ),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: semantic.brandPrimary))
          : _items.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Icon(Icons.cloud_off_rounded,
                          size: 64, color: semantic.textTertiary),
                      const SizedBox(height: 12),
                      Text('暂无离线缓存',
                          style: YuanType.bodySm.copyWith(
                              color: semantic.textTertiary)),
                      const SizedBox(height: 4),
                      Text('帖子详情页可缓存帖子供离线阅读',
                          style: YuanType.caption.copyWith(
                              color: semantic.textTertiary)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) => _OfflineTile(
                    item: _items[index],
                    onTap: () => _openOffline(_items[index]),
                    onDelete: () => _delete(_items[index]),
                  ),
                ),
    );
  }
}

class _OfflineTile extends StatelessWidget {
  const _OfflineTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String _formatSize(Map<String, dynamic> item) {
    try {
      final bytes = utf8.encode(jsonEncode(item));
      final len = bytes.length;
      if (len > 1024 * 1024) {
        return '${(len / 1024 / 1024).toStringAsFixed(1)} MB';
      }
      return '${(len / 1024).toStringAsFixed(1)} KB';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = YuanSemanticColors.of(context);
    final title = (item['title'] as String?) ?? '';
    final boardName = (item['boardName'] as String?) ?? '';
    final cachedAt = (item['cachedAt'] as String?) ?? '';
    final views = (item['views'] as num?)?.toInt() ?? 0;
    final replies = (item['replies'] as num?)?.toInt() ?? 0;
    return Card(
      color: themeColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(YuanRadius.lg),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(YuanRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: YuanType.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: semantic.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (boardName.isNotEmpty) ...[
                    Text(boardName,
                        style: YuanType.caption.copyWith(
                            color: semantic.textTertiary)),
                    const SizedBox(height: 2),
                  ],
                  Text('· $replies 回 · $views 阅',
                      style: YuanType.caption.copyWith(
                          color: semantic.textTertiary)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(_formatSize(item),
                      style: YuanType.caption.copyWith(
                          color: semantic.textTertiary)),
                  const Spacer(),
                  Text(cachedAt,
                      style: YuanType.caption.copyWith(
                          color: semantic.textTertiary)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 20, color: semantic.textTertiary),
                    onPressed: onDelete,
                    tooltip: '删除缓存',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color themeColor(BuildContext context) =>
    Theme.of(context).cardTheme.color ?? Colors.white;

/// 离线帖子详情页：直接从本地快照渲染，不发起网络请求。
class OfflineThreadDetailPage extends StatelessWidget {
  const OfflineThreadDetailPage({
    super.key,
    required this.tid,
    required this.title,
    required this.boardName,
    required this.snapshot,
  });

  final int tid;
  final String title;
  final String boardName;
  final Map<String, dynamic> snapshot;

  @override
  Widget build(BuildContext context) {
    final posts = <Map<String, dynamic>>[];
    if (snapshot['posts'] is List) {
      for (final p in (snapshot['posts'] as List)) {
        if (p is Map) {
          posts.add(p.map((k, v) => MapEntry(k.toString(), v)));
        }
      }
    }

    final views = (snapshot['views'] as num?)?.toInt() ?? 0;
    final replies = (snapshot['replies'] as num?)?.toInt() ?? 0;

    final semantic = YuanSemanticColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (boardName.isNotEmpty)
                    Text(boardName,
                        style: YuanType.caption.copyWith(
                            color: semantic.brandPrimary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('$views 阅 · $replies 回',
                          style: YuanType.caption.copyWith(
                              color: semantic.textTertiary)),
                      const Spacer(),
                      Icon(Icons.cloud_download_rounded,
                          size: 16, color: semantic.success),
                      const SizedBox(width: 4),
                      Text(
                        (snapshot['cachedAt'] as String?) ?? '',
                        style: YuanType.caption.copyWith(
                            color: semantic.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final p = posts[index];
                return _OfflinePostCard(
                  pid: (p['pid'] as num?)?.toInt() ?? 0,
                  author: (p['author'] as String?) ?? '',
                  time: (p['time'] as String?) ?? '',
                  floor: (p['floor'] as String?) ?? '',
                  html: (p['html'] as String?) ?? '',
                  isOp: (p['isOp'] as bool?) ?? false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflinePostCard extends StatelessWidget {
  const _OfflinePostCard({
    required this.pid,
    required this.author,
    required this.time,
    required this.floor,
    required this.html,
    required this.isOp,
  });

  final int pid;
  final String author;
  final String time;
  final String floor;
  final String html;
  final bool isOp;

  @override
  Widget build(BuildContext context) {
    final semantic = YuanSemanticColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOp
            ? semantic.surfaceContainer
            : themeCardColor(context),
        borderRadius: BorderRadius.circular(
          isOp ? YuanRadius.lg : YuanRadius.md,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: semantic.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    author.isNotEmpty ? author.substring(0, 1) : '?',
                    style: YuanType.bodySm.copyWith(
                      color: semantic.brandPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          author,
                          style: YuanType.bodySm.copyWith(
                            fontWeight: FontWeight.w600,
                            color: semantic.textPrimary,
                          ),
                        ),
                        if (isOp) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: semantic.brandPrimary
                                  .withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            child: Text('楼主',
                                style: YuanType.caption.copyWith(
                                    color: semantic.brandPrimary)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: YuanType.caption.copyWith(
                          color: semantic.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _OfflineHtmlContent(html: html),
        ],
      ),
    );
  }
}

Color themeCardColor(BuildContext context) =>
    Theme.of(context).cardTheme.color ?? Colors.white;

class _OfflineHtmlContent extends StatelessWidget {
  const _OfflineHtmlContent({required this.html});
  final String html;

  @override
  Widget build(BuildContext context) {
    return PostContent(html: html);
  }
}
