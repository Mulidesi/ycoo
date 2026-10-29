import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ycoo_client/core/share/share_image_service.dart';
import 'package:ycoo_client/core/share/share_renderer.dart';
import 'package:ycoo_client/data/content.dart';

final Uint8List kPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  const header = ShareHeader(
    title: '测试标题',
    author: '楼主',
    timeText: '昨天 21:20',
  );
  const footer = ShareFooter(
    siteName: '源论坛',
    threadUrl: 'https://ycoo.net/thread-1-1-1.html',
  );

  test('空正文不可分享，有文本或图片可分享', () {
    expect(canShareThreadAsImage(''), isFalse);
    expect(canShareThreadAsImage('<p>   </p>'), isFalse);
    expect(canShareThreadAsImage('<p>正文</p>'), isTrue);
    expect(canShareThreadAsImage('<img src="a.png">'), isTrue);
  });

  test('文件名清洗去掉非法字符并截断', () {
    expect(FileNameSafe.sanitize(''), 'share');
    expect(FileNameSafe.sanitize('a/b:c'), 'a_b_c');
    expect(FileNameSafe.sanitize('x' * 80).length, 40);
  });

  test('收集头像与正文图片 URL，忽略空值', () {
    final urls = collectShareImageUrls(
      avatarUrl: 'https://ycoo.net/a.gif',
      blocks: [
        const ContentBlock.text([InlineRun('hi')]),
        ContentBlock.image('https://ycoo.net/1.png'),
        ContentBlock.image(''),
      ],
    );
    expect(urls, [
      'https://ycoo.net/a.gif',
      'https://ycoo.net/1.png',
    ]);
  });

  testWidgets('纯文本布局宽度固定、高度大于页边距', (tester) async {
    final renderer = ShareRenderer();
    final layout = renderer.computeLayout(
      header: header,
      footer: footer,
      blocks: [
        const ContentBlock.text([InlineRun('这是一段用于分享的正文内容。')]),
      ],
    );
    expect(layout.width, 1080);
    expect(layout.height, greaterThan(200));
    expect(layout.truncated, isFalse);
  });

  testWidgets('混合块高度大于纯文本', (tester) async {
    final renderer = ShareRenderer();
    final textOnly = renderer.computeLayout(
      header: header,
      footer: footer,
      blocks: [const ContentBlock.text([InlineRun('一段文字')])],
    );
    final mixed = renderer.computeLayout(
      header: header,
      footer: footer,
      blocks: [
        const ContentBlock.text([InlineRun('一段文字')]),
        const ContentBlock.quote([InlineRun('引用')]),
        ContentBlock.codeBlock('print(1);'),        const ContentBlock.divider(),
        ContentBlock.image('https://ycoo.net/x.png'),
      ],
    );
    expect(mixed.height, greaterThan(textOnly.height));
    expect(mixed.truncated, isFalse);
  });

  testWidgets('超长内容按 maxHeight 截断', (tester) async {
    final renderer = ShareRenderer(
      spec: const ShareImageSpec(maxHeight: 420, maxLines: 10000),
    );
    final blocks = [
      for (var i = 0; i < 80; i++)
        ContentBlock.text([InlineRun('第 $i 段很长的正文用来撑开高度。' * 4)]),
    ];
    final layout = renderer.computeLayout(
      header: header,
      footer: footer,
      blocks: blocks,
    );
    expect(layout.truncated, isTrue);
    expect(layout.height, lessThanOrEqualTo(420 + 80));
  });

  testWidgets('超行数截断', (tester) async {
    final renderer = ShareRenderer(
      spec: const ShareImageSpec(maxLines: 3, maxHeight: 8000),
    );
    final layout = renderer.computeLayout(
      header: header,
      footer: footer,
      blocks: [
        for (var i = 0; i < 20; i++)
          const ContentBlock.text([InlineRun('一行正文')]),
      ],
    );
    expect(layout.truncated, isTrue);
  });

  testWidgets('渲染输出 2 倍图且非空像素', (tester) async {
    // picture.toImage / toByteData 要真实异步，fake async 下会永久挂起。
    await tester.runAsync(() async {
      final renderer = ShareRenderer(
        spec: const ShareImageSpec(width: 400, pixelRatio: 2),
      );
      final image = await renderer.render(
        header: header,
        footer: footer,
        blocks: const [ContentBlock.text([InlineRun('分享正文')])],
      );
      expect(image.width, 800);
      expect(image.height, greaterThan(200));
      final bytes = await image.toByteData();
      expect(bytes, isNotNull);
      expect(bytes!.lengthInBytes, greaterThan(0));
      image.dispose();
    });
  });

  testWidgets('图片块下载失败时仍能布局', (tester) async {
    final renderer = ShareRenderer();
    final layout = renderer.computeLayout(
      header: header,
      footer: footer,
      blocks: [ContentBlock.image('https://ycoo.net/missing.png')],
    );
    expect(layout.height, greaterThan(200));
  });

  testWidgets('图片预取遵守数量上限，超量不请求', (tester) async {
    await tester.runAsync(() async {
      var calls = 0;
      final fetcher = ShareImageFetcher(
        spec: const ShareImageSpec(maxImages: 2, maxConcurrent: 2),
        fetchBytes: (url) async {
          calls++;
          return kPng;
        },
      );
      final images = await fetcher.load([
        'https://ycoo.net/1.png',
        'https://ycoo.net/2.png',
        'https://ycoo.net/3.png',
      ]);
      expect(calls, 2);
      expect(images.length, 2);
      expect(images.values.every((img) => img != null), isTrue);
      for (final img in images.values) {
        img?.dispose();
      }
    });
  });

  testWidgets('超过体积上限的图片记为失败', (tester) async {
    await tester.runAsync(() async {
      var calls = 0;
      final fetcher = ShareImageFetcher(
        spec: const ShareImageSpec(maxImageBytes: 4),
        fetchBytes: (url) async {
          calls++;
          return kPng;
        },
      );
      final images = await fetcher.load(['https://ycoo.net/big.png']);
      expect(calls, 1);
      expect(images['https://ycoo.net/big.png'], isNull);
    });
  });
}
