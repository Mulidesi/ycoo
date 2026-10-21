// 真实网络图片加载测试（需要联网，CI 环境可跳过）
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:ycoo_client/core/image_loader.dart';

const _urls = [
  'https://ycoo.net/data/avatar/000/00/00/01_avatar_middle.jpg',
  'https://ycoo.net/data/attachment/common/template/boardimg_20241216d6f4lsl6.png',
  'https://ycoo.net/data/avatar/noavatar.svg',
  'https://s1.imagehub.cc/images/2026/10/19/6540aa703c836608a8b8e737ff34f2a2.jpg',
];

void main() {
  test('真实图片可下载并可解码', () async {
    HttpOverrides.global = null;
    for (final url in _urls) {
      try {
        final bytes = await DiscuzImageProvider(url).fetchBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        // ignore: avoid_print
        print('OK  ${bytes.length.toString().padLeft(7)}B  '
            '${frame.image.width}x${frame.image.height}  $url');
      } on ImageFetchException catch (e) {
        // ignore: avoid_print
        print('ERR ${e.message.padRight(24)} $url');
      }
    }
  }, timeout: const Timeout(Duration(seconds: 90)));
}
