// 附件排版预览：把真实帖子渲染成 PNG，人工比对「移动端网页 vs App」。
// 运行：flutter test test/preview_attach.dart --update-goldens
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/core/image_loader.dart';
import 'package:ycoo_client/state/app_state.dart';
import 'package:ycoo_client/ui/pages/thread_detail_page.dart';
import 'package:ycoo_client/ui/theme.dart';

Future<void> _loadFont() async {
  for (final p in ['C:/Windows/Fonts/msyh.ttc', 'C:/Windows/Fonts/simhei.ttf']) {
    final f = File(p);
    if (!f.existsSync()) continue;
    final bytes = await f.readAsBytes();
    final loader = FontLoader('CJK')..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
    return;
  }
}

final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR4nGOoWfEBK2IYWhIA2sWFARzvhhQAAAAASUVORK5CYII=',
);

ThemeData _theme() {
  final base = AppTheme.light();
  return base.copyWith(textTheme: base.textTheme.apply(fontFamily: 'CJK'));
}

/// 样本缺失时返回 null，让测试跳过（CI 里没有 recon/）。
String? _sample(String name) {
  for (final p in [
    '../recon/$name',
    'C:/Users/Administrator/WorkBuddy AI/源论坛/recon/$name',
    'E:/源论坛/recon/$name',
  ]) {
    final f = File(p);
    if (f.existsSync()) return f.readAsStringSync();
  }
  return null;
}

void main() {
  setUpAll(() async {
    await _loadFont();
    DiscuzImageProvider.httpGet = (uri, headers) async => http.Response.bytes(
          _pngBytes,
          200,
          headers: {'content-type': 'image/png'},
        );
  });

  Future<void> render(WidgetTester tester, String sample, int tid, String golden) async {
    final html = _sample(sample);
    if (html == null) {
      markTestSkipped('缺少 recon/$sample');
      return;
    }
    SharedPreferences.setMockInitialValues({});
    final client = DiscuzClient(
      client: MockClient((req) async => http.Response.bytes(
            utf8.encode(html),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          )),
    );
    final state = AppState(client: client);
    await state.init();

    await tester.binding.setSurfaceSize(const Size(390, 900));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: _theme(),
        home: ThreadDetailPage(tid: tid, title: '测试帖', fid: 39, boardName: '精品软件'),
      ),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    await expectLater(find.byType(ThreadDetailPage), matchesGoldenFile(golden));
  }

  testWidgets('preview: 只有附件的帖子', (tester) async {
    await render(tester, 't152780_login.html', 152780, 'goldens/attach_body.png');
  });

  testWidgets('preview: 正文+附件混合', (tester) async {
    await render(tester, 't153650_after.html', 153650, 'goldens/attach_mixed.png');
  });
}
