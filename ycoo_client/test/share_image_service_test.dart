import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ycoo_client/core/share/share_image_service.dart';
import 'package:ycoo_client/core/share/share_platform.dart';
import 'package:ycoo_client/core/share/share_renderer.dart';
import 'package:ycoo_client/data/content.dart';

void main() {
  testWidgets('生成 PNG 并走注入的 persist，不调系统分享', (tester) async {
    // toImage / toByteData 要真实异步，fake async 下会永久挂起。
    await tester.runAsync(() async {
      Uint8List? saved;
      String? name;
      String? capturedShareText;
      final svc = ShareImageService(
        spec: const ShareImageSpec(width: 400, pixelRatio: 1),
        persist: ({
          required Uint8List bytes,
          required String fileName,
          String shareText = '',
        }) async {
          saved = bytes;
          name = fileName;
          capturedShareText = shareText;
          // 只落盘：不返回 shared，模拟“保存完成、尚未调起分享”。
          return ShareOutcome(path: '/tmp/$fileName', bytes: bytes);
        },
      );
      final outcome = await svc.generateAndShare(
        title: '你好/世界',
        author: '楼主',
        timeText: '昨天',
        blocks: const [ContentBlock.text([InlineRun('正文')])],
        siteName: '源论坛',
        threadUrl: 'https://ycoo.net/thread-1-1-1.html',
      );

      expect(outcome.path, '/tmp/ycoo-你好_世界.png');
      expect(outcome.shared, isFalse);
      expect(name, 'ycoo-你好_世界.png');
      expect(capturedShareText, '你好/世界\nhttps://ycoo.net/thread-1-1-1.html');

      final bytes = saved;
      expect(bytes, isNotNull);
      expect(bytes![0], 0x89);
      expect(bytes.sublist(1, 4), [0x50, 0x4E, 0x47]);
      expect(outcome.bytes, isNotNull);
    });
  });

  testWidgets('进度回调覆盖下载 / 渲染 / 保存三个阶段', (tester) async {
    await tester.runAsync(() async {
      final phases = <String>[];
      final svc = ShareImageService(
        spec: const ShareImageSpec(width: 400, pixelRatio: 1),
        persist: ({
          required Uint8List bytes,
          required String fileName,
          String shareText = '',
        }) async =>
            ShareOutcome(path: fileName, bytes: bytes),
      );
      await svc.generateAndShare(
        title: '标题',
        author: '楼主',
        blocks: const [ContentBlock.text([InlineRun('正文')])],
        siteName: '源论坛',
        threadUrl: 'https://ycoo.net/thread-1-1-1.html',
        onPhase: (phase, progress) {
          phases.add(phase);
          expect(progress, inInclusiveRange(0, 1));
        },
      );
      expect(phases, contains('正在准备正文'));
      expect(phases, contains('正在下载图片'));
      expect(phases, contains('正在生成分享图片'));
      expect(phases, contains('正在保存'));
    });
  });

  test('文件名清洗与标题过长截断', () {
    expect(FileNameSafe.sanitize('  标题/带:非法*字符  '), '标题_带_非法_字符');
    expect(FileNameSafe.sanitize(''), 'share');
    expect(FileNameSafe.sanitize('a' * 100).length, 40);
  });
}
