/// 带 Cookie 持久化的 Discuz! HTTP 客户端。
///
/// package:http 不自带 Cookie 管理，而 Discuz 的会话完全依赖 Cookie
/// （形如 `YPSa_2132_auth`），所以这里按 host 分桶维护。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'error/app_exception.dart';
import 'persistence/cookie_store.dart';

/// 过渡别名：业务错误继续用这个类型，下一个小版本删除。
class ForumException extends AppException {
  ForumException(String message, {this.network = false})
      : super(
          network ? AppErrorKind.network : AppErrorKind.unknown,
          message: message,
        );

  final bool network;

  @override
  String toString() => message ?? 'ForumException';
}

class DResponse {
  final int statusCode;
  final String body;
  final Uri url;

  DResponse(this.statusCode, this.body, this.url);
}

class DiscuzClient {
  DiscuzClient({
    required this.baseUrl,
    http.Client? client,
    CookieStore? store,
  })  : _client = client ?? http.Client(),
        store = store ?? CookieStore();

  /// 当前站点根地址（不带尾部斜杠）。
  ///
  /// P13 起由 Client 自持；切站时 SiteManager/AppState 更新此值并清理旧 Cookie。
  String baseUrl;
  final http.Client _client;
  final CookieStore store;

  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  String get _siteHost => Uri.parse(baseUrl).host;

  Map<String, String> get cookies => store.snapshot(_siteHost);
  bool get hasSession => store.hasSession(_siteHost);

  /// 拼好的 Cookie 头，供图片加载等场景复用登录态
  String get cookieHeader => store.headerFor(_siteHost) ?? '';

  void loadCookies(Map<String, String> c) => store.load(_siteHost, c);

  void clearCookies() => store.clear(_siteHost);

  bool _sameSite(String host) =>
      CookieStore.normalizeHost(host) == CookieStore.normalizeHost(_siteHost);

  Map<String, String> _headers({
    required Uri uri,
    bool ajax = false,
    String? referer,
    Map<String, String>? extra,
  }) {
    final h = <String, String>{
      'User-Agent': userAgent,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Cache-Control': 'no-cache',
    };
    if (_sameSite(uri.host)) {
      final cookie = store.headerFor(_siteHost);
      if (cookie != null && cookie.isNotEmpty) h['Cookie'] = cookie;
    }
    if (ajax) h['X-Requested-With'] = 'XMLHttpRequest';
    if (referer != null) h['Referer'] = referer;
    if (extra != null) h.addAll(extra);
    return h;
  }

  void _absorb(http.Response r) {
    final host = (r.request?.url ?? Uri.parse(baseUrl)).host;
    if (!_sameSite(host)) return;
    store.absorb(_siteHost, r.headers['set-cookie']);
  }

  String _decode(http.Response r) {
    try {
      return utf8.decode(r.bodyBytes, allowMalformed: true);
    } catch (_) {
      return r.body;
    }
  }

  void _throwIfMapped(int status) {
    switch (status) {
      case 401:
        throw AppException.unauthorized();
      case 403:
        throw AppException.forbidden();
      case 404:
        throw AppException.notFound();
      default:
        if (status >= 500) {
          throw AppException.server(statusCode: status);
        }
    }
  }

  Future<http.Response> _exchange({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Map<String, String>? body,
  }) async {
    var currentMethod = method;
    var currentUri = uri;
    final currentHeaders = Map<String, String>.from(headers);
    Map<String, String>? currentBody = body;

    for (var hop = 0; hop < 5; hop++) {
      final req = http.Request(currentMethod, currentUri)
        ..followRedirects = false
        ..headers.addAll(currentHeaders);
      if (currentBody != null) {
        req.bodyFields = currentBody;
      }
      final streamed =
          await _client.send(req).timeout(const Duration(seconds: 25));
      if (streamed.statusCode >= 300 && streamed.statusCode < 400) {
        final location = streamed.headers['location'];
        await streamed.stream.drain<void>();
        if (location == null || location.isEmpty) {
          return http.Response(
            '',
            streamed.statusCode,
            headers: streamed.headers,
            request: req,
          );
        }
        final next = currentUri.resolve(location);
        if (!_sameSite(next.host)) {
          currentHeaders.remove('Cookie');
        }
        currentUri = next;
        currentMethod = 'GET';
        currentBody = null;
        continue;
      }
      return http.Response.fromStream(streamed);
    }
    throw AppException.network(message: '重定向过多');
  }

  /// [absorbCookies] 为 false 时不吸收响应里的 Set-Cookie。
  /// 移动端 JSON 接口会重新下发 `saltkey` 等 Cookie，没必要让它干扰登录态。
  Future<DResponse> get(
    String path, {
    String? referer,
    bool ajax = false,
    bool absorbCookies = true,
  }) async {
    final uri = Uri.parse(path.startsWith('http') ? path : '$baseUrl/$path');
    try {
      final r = await _exchange(
        method: 'GET',
        uri: uri,
        headers: _headers(uri: uri, ajax: ajax, referer: referer),
      );
      if (absorbCookies) _absorb(r);
      _throwIfMapped(r.statusCode);
      return DResponse(r.statusCode, _decode(r), r.request?.url ?? uri);
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw AppException.timeout();
    } on SocketException {
      throw AppException.network();
    } on http.ClientException catch (e) {
      throw AppException.network(message: e.message, cause: e);
    }
  }

  Future<DResponse> post(
    String path,
    Map<String, String> body, {
    String? referer,
    bool ajax = true,
  }) async {
    final uri = Uri.parse(path.startsWith('http') ? path : '$baseUrl/$path');
    try {
      final r = await _exchange(
        method: 'POST',
        uri: uri,
        headers: _headers(uri: uri, ajax: ajax, referer: referer),
        body: body,
      );
      _absorb(r);
      _throwIfMapped(r.statusCode);
      return DResponse(r.statusCode, _decode(r), r.request?.url ?? uri);
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw AppException.timeout();
    } on SocketException {
      throw AppException.network();
    } on http.ClientException catch (e) {
      throw AppException.network(message: e.message, cause: e);
    }
  }

  void close() => _client.close();
}
