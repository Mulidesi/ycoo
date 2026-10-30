/// 离线帖子缓存：app-private 目录 + JSON 索引 + 图片下载到本地。
///
/// 存储结构：
/// ```
/// offline_threads/
/// ├── offline_threads.json   # 索引（原子写入 tmp+rename）
/// └── <tid>/
///     └── images/
///         └── img_0.jpg, img_1.png, ...
/// ```
///
/// 图片下载上限：80 张 / 8MB/张；失败时以 `（图片未能缓存）` 替换远程 URL。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path_provider/path_provider.dart';

import '../../core/discuz_client.dart';
import '../../models/models.dart';

/// 离线帖子缓存（单例）。
class OfflineThreadCache {
  OfflineThreadCache._();
  static final OfflineThreadCache instance = OfflineThreadCache._();
  static const _indexName = 'offline_threads.json';
  static const _maxImages = 80;
  static const _maxImageBytes = 8 * 1024 * 1024;

  Future<Directory> _root() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/offline_threads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _indexFile() async =>
      File('${(await _root()).path}/$_indexName');

  Future<Map<String, dynamic>> _read() async {
    final file = await _indexFile();
    if (!await file.exists()) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) return decoded.map((k, v) => MapEntry(k.toString(), v));
    } catch (error) {
      debugPrint('Unable to read offline cache index: $error');
    }
    return <String, dynamic>{};
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final file = await _indexFile();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  /// 列出所有离线帖子（按缓存时间倒序）。
  Future<List<Map<String, dynamic>>> list() async {
    final data = await _read();
    final items = data.values
        .whereType<Map>()
        .map((v) => v.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
    items.sort((a, b) => (b['cachedAt'] ?? '')
        .toString()
        .compareTo((a['cachedAt'] ?? '').toString()));
    return items;
  }

  /// 获取单个离线帖子的快照。
  Future<Map<String, dynamic>?> get(int tid) async {
    final value = (await _read())['$tid'];
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return null;
  }

  /// 保存帖子为离线快照。
  Future<void> save({
    required int tid,
    required String title,
    required String boardName,
    required String author,
    required String time,
    required int views,
    required int replies,
    required List<Post> posts,
  }) async {
    final root = await _root();
    final imageDir = Directory('${root.path}/$tid/images');
    if (!await imageDir.exists()) await imageDir.create(recursive: true);
    final old = await get(tid);
    final existingImages = <String, String>{};
    if (old?['imageMap'] is Map) {
      (old!['imageMap'] as Map).forEach((k, v) {
        if (k is String && v is String) existingImages[k] = v;
      });
    }
    final imageMap = <String, String>{...existingImages};
    var imageCount = 0;

    Future<String> cacheImage(String raw) async {
      if (raw.startsWith('file://')) return raw;
      final url = raw.startsWith('http')
          ? raw
          : 'https://ycoo.net${raw.startsWith('/') ? '' : '/'}$raw';
      if (imageMap.containsKey(url) &&
          await File(Uri.parse(imageMap[url]!).toFilePath()).exists()) {
        return imageMap[url]!;
      }
      if (imageCount >= _maxImages) return url;
      final uri = Uri.tryParse(url);
      if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
        return url;
      }
      try {
        final client = DiscuzClient();
        final headers = <String, String>{
          'Referer': 'https://ycoo.net/',
          'User-Agent': 'Mozilla/5.0',
        };
        final cookie = client.cookieHeader;
        if (cookie.isNotEmpty) headers['Cookie'] = cookie;
        final response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 18));
        if (response.statusCode != 200 ||
            response.bodyBytes.isEmpty ||
            response.bodyBytes.length > _maxImageBytes) {
          return url;
        }
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.isNotEmpty && !contentType.startsWith('image/')) {
          return url;
        }
        final ext = _extension(uri.path, contentType);
        final file = File('${imageDir.path}/img_${imageMap.length}.$ext');
        await file.writeAsBytes(response.bodyBytes, flush: true);
        final local = file.uri.toString();
        imageMap[url] = local;
        imageCount++;
        return local;
      } catch (_) {
        return url;
      }
    }

    final savedPosts = <Map<String, dynamic>>[];
    for (final post in posts) {
      var html = post.contentHtml;
      try {
        final document = parseHtml(html);
        final imgs = document.querySelectorAll('img');
        for (final img in imgs) {
          final raw = img.attributes['comiis_loadimages'] ??
              img.attributes['data-src'] ??
              img.attributes['data-original'] ??
              img.attributes['file'] ??
              img.attributes['src'] ??
              img.attributes['longdesc'] ??
              '';
          if (raw.trim().isEmpty) continue;
          final local = await cacheImage(raw.trim());
          if (local.startsWith('file://')) {
            img.attributes['src'] = local;
            img.attributes.remove('data-src');
            img.attributes.remove('data-original');
            img.attributes.remove('file');
            img.attributes.remove('comiis_loadimages');
            img.attributes.remove('longdesc');
          } else {
            // Never leave a remote image URL in an offline snapshot.
            img.replaceWith(dom.Element.tag('span')..text = '（图片未能缓存）');
          }
        }
        html = document.body?.innerHtml ?? html;
      } catch (_) {}

      final localImages = <String>[];
      for (final attachment in post.attachments) {
        if (attachment.url.startsWith('http')) {
          final local = await cacheImage(attachment.url);
          localImages.add(local);
        }
      }
      savedPosts.add(<String, dynamic>{
        'pid': post.pid,
        'author': post.author,
        'avatar': post.avatar ?? '',
        'time': post.timeText ?? '',
        'html': html,
        'floor': post.floor ?? '',
        'uid': post.authorId ?? 0,
        'level': post.level ?? '',
        'isOp': post.isOp,
        'images': localImages,
        'comments': post.comments.map((c) => <String, dynamic>{
          'author': c.author,
          'text': c.text,
          'uid': c.uid,
          'time': c.time,
        }).toList(),
      });
    }

    final data = await _read();
    data['$tid'] = <String, dynamic>{
      'tid': tid,
      'title': title,
      'boardName': boardName,
      'author': author,
      'time': time,
      'views': views,
      'replies': replies,
      'cachedAt': DateTime.now().toIso8601String(),
      'posts': savedPosts,
      'imageMap': imageMap,
    };
    await _write(data);
  }

  String _extension(String path, String contentType) {
    final ext = path.split('.').last.toLowerCase().split('?').first;
    if (const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'avif'}
        .contains(ext)) {
      return ext == 'jpeg' ? 'jpg' : ext;
    }
    if (contentType.contains('png')) return 'png';
    if (contentType.contains('gif')) return 'gif';
    if (contentType.contains('webp')) return 'webp';
    return 'jpg';
  }

  /// 删除离线帖子。
  Future<void> delete(int tid) async {
    final data = await _read();
    data.remove('$tid');
    await _write(data);
    final dir = Directory('${(await _root()).path}/$tid');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// 清空所有离线帖子。
  Future<void> clear() async {
    final root = await _root();
    final data = await _read();
    for (final key in data.keys) {
      final dir = Directory('${root.path}/$key');
      if (await dir.exists()) await dir.delete(recursive: true);
    }
    await _write(<String, dynamic>{});
  }

  /// 估算缓存项的 JSON 字节数。
  int estimateBytes(Map<String, dynamic> item) =>
      utf8.encode(jsonEncode(item)).length;
}

dynamic parseHtml(String source) {
  // Keep the HTML parser isolated here to avoid retaining DOM nodes in the cache.
  return html_parser.parse(source);
}
