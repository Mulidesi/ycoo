/// 下载管理：ChangeNotifier + SharedPreferences 历史记录。
///
/// 下载状态：completed / downloading / interrupted / failed。
/// 应用关闭时未完成的下载会被标记为 interrupted，可重新下载。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../discuz_client.dart';

/// 下载记录。
class DownloadRecord {
  const DownloadRecord({
    required this.url,
    required this.path,
    required this.name,
    required this.time,
    this.status = 'completed',
    this.receivedBytes = 0,
    this.totalBytes = -1,
    this.error = '',
  });

  final String url;
  final String path;
  final String name;
  final String time;
  final String status;
  final int receivedBytes;
  final int totalBytes;
  final String error;

  DownloadRecord copyWith({
    String? status,
    int? receivedBytes,
    int? totalBytes,
    String? error,
  }) => DownloadRecord(
        url: url,
        path: path,
        name: name,
        time: time,
        status: status ?? this.status,
        receivedBytes: receivedBytes ?? this.receivedBytes,
        totalBytes: totalBytes ?? this.totalBytes,
        error: error ?? this.error,
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'path': path,
        'name': name,
        'time': time,
        'status': status,
        'receivedBytes': receivedBytes,
        'totalBytes': totalBytes,
        'error': error,
      };

  factory DownloadRecord.fromJson(Map<String, dynamic> json) => DownloadRecord(
        url: json['url'] as String? ?? '',
        path: json['path'] as String? ?? '',
        name: json['name'] as String? ?? 'download',
        time: json['time'] as String? ?? '',
        status: json['status'] as String? ?? 'completed',
        receivedBytes: json['receivedBytes'] as int? ?? 0,
        totalBytes: json['totalBytes'] as int? ?? -1,
        error: json['error'] as String? ?? '',
      );
}

/// 下载管理（单例 + ChangeNotifier）。
class DownloadManager extends ChangeNotifier {
  DownloadManager._();
  static final DownloadManager instance = DownloadManager._();
  static const _key = 'ycoo_download_history_v1';
  final List<DownloadRecord> records = [];
  bool initialized = false;

  Future<void> load() async {
    if (initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_key) ?? const <String>[];
    records
      ..clear()
      ..addAll(values.map((value) {
        try {
          final record =
              DownloadRecord.fromJson(jsonDecode(value) as Map<String, dynamic>);
          // A process killed mid-download cannot resume this HTTP stream;
          // make that explicit.
          return record.status == 'downloading'
              ? record.copyWith(
                  status: 'interrupted',
                  error: '应用关闭时下载中断，可重新下载',
                )
              : record;
        } catch (_) {
          return null;
        }
      }).whereType<DownloadRecord>());
    initialized = true;
    notifyListeners();
    await _save();
  }

  /// 下载文件到应用文档目录 `downloads/`。
  Future<DownloadRecord> download(
    String rawUrl, {
    void Function(int received, int total)? onProgress,
    Map<String, String>? headers,
    String? suggestedFilename,
  }) async {
    await load();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
      throw const HttpException('不支持的下载地址');
    }
    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory('${directory.path}/downloads');
    await folder.create(recursive: true);

    var name = suggestedFilename?.trim() ?? '';
    if (name.isEmpty) {
      name = Uri.decodeComponent(
          uri.pathSegments.isEmpty ? '' : uri.pathSegments.last);
    }
    if (name.isEmpty || name == '/' || !name.contains('.')) {
      name = 'download_${DateTime.now().millisecondsSinceEpoch}';
    }
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    var target = '${folder.path}/$name';
    if (await File(target).exists() ||
        records.any((record) =>
            record.path == target && record.status == 'downloading')) {
      final dot = name.lastIndexOf('.');
      final base = dot > 0 ? name.substring(0, dot) : name;
      final ext = dot > 0 ? name.substring(dot) : '';
      target =
          '${folder.path}/${base}_${DateTime.now().millisecondsSinceEpoch}$ext';
      name = target.split(Platform.pathSeparator).last;
    }

    var record = DownloadRecord(
      url: rawUrl,
      path: target,
      name: name,
      time: DateTime.now().toIso8601String(),
      status: 'downloading',
      totalBytes: -1,
    );
    records.insert(0, record);
    notifyListeners();
    await _save();

    final client = HttpClient();
    var lastPersist = DateTime.now();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
      request.headers.set(HttpHeaders.refererHeader, 'https://ycoo.net/');
      final cookie = DiscuzClient().cookieHeader;
      if (cookie.isNotEmpty && uri.host == 'ycoo.net') {
        request.headers.set(HttpHeaders.cookieHeader, cookie);
      }
      headers?.forEach((key, value) {
        request.headers.set(key, value);
      });

      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('下载失败：HTTP ${response.statusCode}', uri: uri);
      }
      record = record.copyWith(
        status: 'downloading',
        totalBytes: response.contentLength,
      );
      _replaceRecord(record);
      final file = File(target).openWrite();
      var received = 0;
      try {
        await for (final chunk in response) {
          file.add(chunk);
          received += chunk.length;
          onProgress?.call(received, response.contentLength);
          record = record.copyWith(
            receivedBytes: received,
            totalBytes: response.contentLength,
          );
          _replaceRecord(record);
          if (DateTime.now().difference(lastPersist).inMilliseconds >= 600) {
            lastPersist = DateTime.now();
            await _save();
          }
        }
      } finally {
        await file.close();
      }
      record = record.copyWith(
        status: 'completed',
        receivedBytes: received,
        totalBytes: response.contentLength,
        error: '',
      );
      _replaceRecord(record);
      await _save();
      return record;
    } catch (e) {
      final partial = File(target);
      if (await partial.exists()) await partial.delete();
      record = record.copyWith(status: 'failed', error: e.toString());
      _replaceRecord(record);
      await _save();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  void _replaceRecord(DownloadRecord updated) {
    final index = records.indexWhere((record) => record.path == updated.path);
    if (index >= 0) records[index] = updated;
    notifyListeners();
  }

  /// 删除下载记录（可选删除文件）。
  Future<void> remove(DownloadRecord record, {bool deleteFile = false}) async {
    records.removeWhere((item) => item.path == record.path);
    if (deleteFile) {
      final file = File(record.path);
      if (await file.exists()) await file.delete();
    }
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      records.map((record) => jsonEncode(record.toJson())).toList(),
    );
  }
}
