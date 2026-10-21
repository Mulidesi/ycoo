/// 图片加载器。
///
/// 为什么不用 `Image.network`：
///   1. 站内附件图（`data/attachment/...`）需要登录态 Cookie，`Image.network` 带不上；
///   2. 站点/图床可能按 Referer 做防盗链，命中后返回 403 或占位图；
///   3. `noavatar.svg` 这类 SVG 头像 Flutter 解不了，会直接抛解码错误；
///   4. 出错时拿不到状态码，只能看到「图片加载失败」，没法定位。
/// 这里统一走自己的 HTTP 栈：带 UA / Referer / Cookie，失败自动降级重试，
/// 并把 HTTP 状态码透出到 UI。
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

import '../data/parsers.dart' show kBaseUrl;
import 'discuz_client.dart';

class ImageFetchException implements Exception {
  final String message;
  final int? status;

  const ImageFetchException(this.message, {this.status});

  @override
  String toString() => message;
}

class DiscuzImageProvider extends ImageProvider<DiscuzImageProvider> {
  const DiscuzImageProvider(this.url, {this.scale = 1.0});

  final String url;
  final double scale;

  /// 由 AppState 注入，返回当前登录态的 Cookie 头
  static String? Function()? cookieProvider;

  /// 测试可替换成假实现
  @visibleForTesting
  static Future<http.Response> Function(Uri uri, Map<String, String> headers)? httpGet;

  static bool looksLikeSvg(String url, String? contentType) {
    if ((contentType ?? '').toLowerCase().contains('svg')) return true;
    final path = url.toLowerCase().split('?').first;
    return path.endsWith('.svg');
  }

  Map<String, String> _headers({required bool withReferer}) {
    final cookie = cookieProvider?.call();
    return {
      'User-Agent': DiscuzClient.userAgent,
      'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      if (withReferer) 'Referer': '$kBaseUrl/',
      if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
    };
  }

  /// 下载图片字节：先带 Referer 试，失败再去掉 Referer 试一次（有的图床反过来拦）。
  Future<Uint8List> fetchBytes() async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw const ImageFetchException('图片地址无效');
    }

    Object? last;
    for (final withReferer in const [true, false]) {
      try {
        final headers = _headers(withReferer: withReferer);
        final r = await (httpGet != null
            ? httpGet!(uri, headers)
            : http.get(uri, headers: headers).timeout(const Duration(seconds: 25)));
        if (r.statusCode == 200) {
          if (looksLikeSvg(url, r.headers['content-type'])) {
            throw const ImageFetchException('SVG 图片不支持渲染');
          }
          if (r.bodyBytes.isEmpty) {
            throw const ImageFetchException('图片内容为空');
          }
          return r.bodyBytes;
        }
        last = ImageFetchException('HTTP ${r.statusCode}', status: r.statusCode);
      } on ImageFetchException catch (e) {
        last = e;
        // SVG / 空内容换个 Referer 也没用，直接抛出
        if (e.status == null) rethrow;
      } catch (e) {
        last = ImageFetchException('网络异常：$e');
      }
    }
    throw last ?? const ImageFetchException('图片加载失败');
  }

  @override
  Future<DiscuzImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<DiscuzImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(DiscuzImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<String>('图片地址', key.url),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(DiscuzImageProvider key, ImageDecoderCallback decode) async {
    final bytes = await key.fetchBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is DiscuzImageProvider && other.url == url && other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() => 'DiscuzImageProvider("$url")';
}
