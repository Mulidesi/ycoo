/// 带 Cookie 持久化的 Discuz! HTTP 客户端。
///
/// package:http 不自带 Cookie 管理，而 Discuz 的会话完全依赖 Cookie
/// （形如 `YPSa_2132_auth`），所以这里自己维护一份 name→value 表。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../data/parsers.dart';

class ForumException implements Exception {
  final String message;
  final bool network;
  ForumException(this.message, {this.network = false});
  @override
  String toString() => message;
}

class DResponse {
  final int statusCode;
  final String body;
  final Uri url;

  DResponse(this.statusCode, this.body, this.url);
}

class DiscuzClient {
  DiscuzClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, String> _cookies = {};

  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  Map<String, String> get cookies => Map.unmodifiable(_cookies);
  bool get hasSession => _cookies.keys.any((k) => k.endsWith('_auth'));

  /// 拼好的 Cookie 头，供图片加载等场景复用登录态
  String get cookieHeader =>
      _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  void loadCookies(Map<String, String> c) {
    _cookies
      ..clear()
      ..addAll(c);
  }

  void clearCookies() => _cookies.clear();

  Map<String, String> _headers({bool ajax = false, String? referer, Map<String, String>? extra}) {
    final h = <String, String>{
      'User-Agent': userAgent,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Cache-Control': 'no-cache',
    };
    if (_cookies.isNotEmpty) {
      h['Cookie'] = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }
    if (ajax) h['X-Requested-With'] = 'XMLHttpRequest';
    if (referer != null) h['Referer'] = referer;
    if (extra != null) h.addAll(extra);
    return h;
  }

  void _absorb(http.Response r) {
    final raw = r.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    // 多个 Set-Cookie 被 http 包用 ", " 拼在一起，但 expires 里也含逗号，
    // 因此只在“逗号 + name=”处切分。
    for (final part in raw.split(RegExp(r',(?=\s*[A-Za-z0-9_\-]+=)'))) {
      final kv = part.split(';').first.trim();
      final i = kv.indexOf('=');
      if (i <= 0) continue;
      final name = kv.substring(0, i).trim();
      final value = kv.substring(i + 1).trim();
      if (value.isEmpty) {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
  }

  String _decode(http.Response r) {
    try {
      return utf8.decode(r.bodyBytes, allowMalformed: true);
    } catch (_) {
      return r.body;
    }
  }

  Future<DResponse> get(String path, {String? referer, bool ajax = false}) async {
    final uri = Uri.parse(path.startsWith('http') ? path : '$kBaseUrl/$path');
    try {
      final r = await _client
          .get(uri, headers: _headers(ajax: ajax, referer: referer))
          .timeout(const Duration(seconds: 25));
      _absorb(r);
      return DResponse(r.statusCode, _decode(r), r.request?.url ?? uri);
    } on TimeoutException {
      throw ForumException('请求超时，请检查网络后重试', network: true);
    } on SocketException {
      throw ForumException('网络连接失败，请检查网络或代理设置', network: true);
    } on http.ClientException catch (e) {
      throw ForumException('网络请求失败：${e.message}', network: true);
    }
  }

  Future<DResponse> post(
    String path,
    Map<String, String> body, {
    String? referer,
    bool ajax = true,
  }) async {
    final uri = Uri.parse(path.startsWith('http') ? path : '$kBaseUrl/$path');
    try {
      final r = await _client
          .post(uri, headers: _headers(ajax: ajax, referer: referer), body: body)
          .timeout(const Duration(seconds: 25));
      _absorb(r);
      return DResponse(r.statusCode, _decode(r), r.request?.url ?? uri);
    } on TimeoutException {
      throw ForumException('请求超时，请检查网络后重试', network: true);
    } on SocketException {
      throw ForumException('网络连接失败，请检查网络或代理设置', network: true);
    } on http.ClientException catch (e) {
      throw ForumException('网络请求失败：${e.message}', network: true);
    }
  }

  void close() => _client.close();
}
