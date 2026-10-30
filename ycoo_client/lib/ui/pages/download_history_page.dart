/// 下载历史页：展示下载记录列表，支持重新下载与删除。
library;

import 'package:flutter/material.dart';

import '../../core/services/download_manager.dart';
import '../../design/tokens.dart';

class DownloadHistoryPage extends StatefulWidget {
  const DownloadHistoryPage({super.key});

  @override
  State<DownloadHistoryPage> createState() => _DownloadHistoryPageState();
}

class _DownloadHistoryPageState extends State<DownloadHistoryPage> {
  List<DownloadRecord> _records = [];
  bool _loading = true;
  final Map<String, bool> _downloading = {};

  @override
  void initState() {
    super.initState();
    _load();
    // 监听下载管理器变化
    DownloadManager.instance.addListener(_onDownloadChange);
  }

  @override
  void dispose() {
    DownloadManager.instance.removeListener(_onDownloadChange);
    super.dispose();
  }

  void _onDownloadChange() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await DownloadManager.instance.load();
    setState(() {
      _records = DownloadManager.instance.records;
      _loading = false;
    });
  }

  Future<void> _redownload(DownloadRecord record) async {
    setState(() => _downloading[record.path] = true);
    try {
      await DownloadManager.instance.download(
        record.url,
        suggestedFilename: record.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已重新下载「${record.name}」')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading[record.path] = false);
    }
  }

  Future<void> _remove(DownloadRecord record, {bool deleteFile = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除下载记录'),
        content: Text('确定删除「${record.name}」的记录吗？'),
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
    if (confirmed != true) return;
    await DownloadManager.instance.remove(record, deleteFile: deleteFile);
    if (mounted) setState(() {});
  }

  String _formatSize(int bytes) {
    if (bytes < 0) return '未知';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime);
      final now = DateTime.now();
      if (dt.isAfter(now.subtract(const Duration(days: 1)))) {
        return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.month}月${dt.day}日 ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = YuanSemanticColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载历史'),
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
          : _records.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Icon(Icons.download_outlined,
                          size: 64, color: semantic.textTertiary),
                      const SizedBox(height: 12),
                      Text('暂无下载记录',
                          style: YuanType.bodySm.copyWith(
                              color: semantic.textTertiary)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _records.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) => _DownloadTile(
                    record: _records[index],
                    downloading: _downloading[_records[index].path] ?? false,
                    onRedownload: () => _redownload(_records[index]),
                    onDelete: () => _remove(_records[index], deleteFile: true),
                    formatSize: _formatSize,
                    formatTime: _formatTime,
                  ),
                ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.record,
    required this.downloading,
    required this.onRedownload,
    required this.onDelete,
    required this.formatSize,
    required this.formatTime,
  });

  final DownloadRecord record;
  final bool downloading;
  final VoidCallback onRedownload;
  final VoidCallback onDelete;
  final String Function(int) formatSize;
  final String Function(String) formatTime;

  @override
  Widget build(BuildContext context) {
    final semantic = YuanSemanticColors.of(context);
    final statusColor = switch (record.status) {
      'completed' => semantic.success,
      'downloading' => semantic.brandPrimary,
      'interrupted' => semantic.warning,
      'failed' => semantic.danger,
      _ => semantic.textTertiary,
    };
    final statusLabel = switch (record.status) {
      'completed' => '已完成',
      'downloading' => '下载中',
      'interrupted' => '已中断',
      'failed' => '失败',
      _ => record.status,
    };
    final receivedText = record.totalBytes > 0
        ? '${formatSize(record.receivedBytes)} / ${formatSize(record.totalBytes)}'
        : formatSize(record.receivedBytes);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(YuanRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insert_drive_file_outlined,
                    size: 22, color: semantic.textTertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    record.name,
                    style: YuanType.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: semantic.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: YuanType.caption.copyWith(
                        color: statusColor, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(record.receivedBytes > 0 || record.totalBytes > 0
                    ? receivedText
                    : formatSize(record.receivedBytes),
                    style: YuanType.caption.copyWith(
                        color: semantic.textTertiary)),
                const SizedBox(width: 8),
                Text(record.time.isNotEmpty
                    ? formatTime(record.time)
                    : '',
                    style: YuanType.caption.copyWith(
                        color: semantic.textTertiary)),
                const Spacer(),
                if (record.status == 'interrupted' ||
                    record.status == 'failed')
                  IconButton(
                    icon: Icon(Icons.refresh_rounded,
                        size: 20, color: semantic.brandPrimary),
                    onPressed: onRedownload,
                    tooltip: '重新下载',
                  ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 20, color: semantic.textTertiary),
                  onPressed: onDelete,
                  tooltip: '删除记录',
                ),
              ],
            ),
            if (record.error.isNotEmpty && record.status != 'completed')
              ...[
                const SizedBox(height: 6),
                Text(
                  record.error,
                  style: YuanType.caption.copyWith(
                    color: semantic.danger,
                    fontSize: 10,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
          ],
        ),
      ),
    );
  }
}
