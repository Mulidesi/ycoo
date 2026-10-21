import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ycoo_client/core/image_loader.dart';
import 'package:ycoo_client/ui/widgets/net_image.dart';

/// 1x1 PNG
final Uint8List kPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

http.Response _png() => http.Response.bytes(
      kPng,
      200,
      headers: {'content-type': 'image/png'},
    );

void main() {
  tearDown(() {
    DiscuzImageProvider.httpGet = null;
    DiscuzImageProvider.cookieProvider = null;
    imageCache.clear();
    imageCache.clearLiveImages();
  });

  test('带 Referer 被 403 后自动去掉 Referer 重试', () async {
    var calls = 0;
    DiscuzImageProvider.httpGet = (uri, headers) async {
      calls++;
      if (headers.containsKey('Referer')) {
        return http.Response('forbidden', 403);
      }
      return _png();
    };

    final bytes = await const DiscuzImageProvider('https://ycoo.net/a.png').fetchBytes();
    expect(bytes.length, kPng.length);
    expect(calls, 2);
  });

  test('请求带上登录 Cookie', () async {
    String? seen;
    DiscuzImageProvider.cookieProvider = () => 'YPSa_2132_auth=abc';
    DiscuzImageProvider.httpGet = (uri, headers) async {
      seen = headers['Cookie'];
      return _png();
    };
    await const DiscuzImageProvider('https://ycoo.net/a.png').fetchBytes();
    expect(seen, 'YPSa_2132_auth=abc');
  });

  test('SVG 直接判为不支持，不重试', () async {
    var calls = 0;
    DiscuzImageProvider.httpGet = (uri, headers) async {
      calls++;
      return http.Response('<svg/>', 200, headers: {'content-type': 'image/svg+xml'});
    };
    expect(
      () => const DiscuzImageProvider('https://ycoo.net/data/avatar/noavatar.svg').fetchBytes(),
      throwsA(isA<ImageFetchException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(calls, 1);
  });

  testWidgets('加载成功后渲染出图片，不再显示破图', (tester) async {
    DiscuzImageProvider.httpGet = (uri, headers) async => _png();

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NetImage(url: 'https://ycoo.net/ok.png', width: 40, height: 40)),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();

    expect(find.text('图片加载失败'), findsNothing);
    expect(find.text('重试'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('失败时显示状态码与重试', (tester) async {
    DiscuzImageProvider.httpGet = (uri, headers) async => http.Response('nope', 404);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NetImage(url: 'https://ycoo.net/404.png', width: 120, height: 80)),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();

    expect(find.text('HTTP 404'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}
