/// 首页信息流缓存：按 view（newthread / hot / new / digest）独立存储。
///
/// 存储结构：
/// ```
/// feed_cache/
/// └── feed_cache.json   # 索引（原子写入 tmp+rename）
/// ```
///
/// 启动时先读缓存立即展示，用户下拉刷新才拉取最新内容并更新缓存。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/models.dart';

/// 单条缓存条目。
class FeedCacheEntry {
  const FeedCacheEntry({
    required this.view,
    required this.items,
    required this.page,
    required this.totalPages,
    required this.cachedAt,
  });

  final String view;
  final List<ThreadItem> items;
  final int page;
  final int totalPages;
  final DateTime cachedAt;

  Map<String, dynamic> toJson() => {
        'view': view,
        'items': [for (final i in items) i.toJson()],
        'page': page,
        'totalPages': totalPages,
        'cachedAt': cachedAt.toIso8601String(),
      };

  factory FeedCacheEntry.fromJson(Map<String, dynamic> json) => FeedCacheEntry(
        view: json['view'] as String? ?? '',
        items: [
          for (final raw in (json['items'] as List? ?? []))
            if (raw is Map) ThreadItem.fromJson(raw.map((k, v) => MapEntry(k.toString(), v))),
        ],
        page: (json['page'] as num?)?.toInt() ?? 1,
        totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
        cachedAt: DateTime.tryParse(json['cachedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// 首页信息流缓存（单例）。
class FeedCache {
  FeedCache._();
  static final FeedCache instance = FeedCache._();
  static const _fileName = 'feed_cache.json';

  Future<Directory> _root() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/feed_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file() async => File('${(await _root()).path}/$_fileName');

  Future<Map<String, dynamic>> _read() async {
    final file = await _file();
    if (!await file.exists()) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) return decoded.map((k, v) => MapEntry(k.toString(), v));
    } catch (error) {
      debugPrint('Unable to read feed cache: $error');
    }
    return <String, dynamic>{};
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  /// 读取指定 view 的缓存。
  Future<FeedCacheEntry?> get(String view) async {
    final data = await _read();
    final raw = data[view];
    if (raw is! Map) return null;
    try {
      return FeedCacheEntry.fromJson(raw.map((k, v) => MapEntry(k.toString(), v)));
    } catch (_) {
      return null;
    }
  }

  /// 写入指定 view 的缓存。
  Future<void> put(FeedCacheEntry entry) async {
    final data = await _read();
    data[entry.view] = entry.toJson();
    await _write(data);
  }

  /// 清空所有缓存。
  Future<void> clear() async {
    await _write(<String, dynamic>{});
  }
}
