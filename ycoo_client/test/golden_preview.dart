// 版式预览：用 --update-goldens 生成 PNG，便于人工比对设计稿。
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
import 'package:ycoo_client/data/previews.dart';
import 'package:ycoo_client/models/models.dart';
import 'package:ycoo_client/state/app_state.dart';
import 'package:ycoo_client/ui/pages/thread_detail_page.dart';
import 'package:ycoo_client/ui/theme.dart';
import 'package:ycoo_client/ui/widgets/thread_tile.dart';

const _items = <ThreadItem>[
  ThreadItem(
    tid: 153502,
    title: 'NFC Tools Pro 9.8 | 强大的NFC工具，一键模拟门禁卡、电梯卡……',
    url: 'https://ycoo.net/thread-153502-1-1.html',
    author: '硬核软件',
    replies: 6,
    views: 179,
    timeText: '昨天 21:20',
    typeName: '综合交流',
    hasAttachment: true,
    fid: 39,
  ),
  ThreadItem(
    tid: 153497,
    title: 'TVBox_takagen99',
    url: 'https://ycoo.net/thread-153497-1-1.html',
    author: 'feelingboy11',
    replies: 3,
    views: 250,
    timeText: '昨天 21:13',
    typeName: '精品软件',
    fid: 39,
  ),
  ThreadItem(
    tid: 153495,
    title: '一个软件卸载工具，卸载无残留，绿色免安装',
    url: 'https://ycoo.net/thread-153495-1-1.html',
    author: 'ysqzh',
    replies: 12,
    views: 88,
    timeText: '昨天 19:02',
    typeName: '网络资源',
    hasAttachment: true,
    fid: 40,
  ),
];

const _previews = <int, ThreadPreview>{
  153502: ThreadPreview(
    image: 'https://ycoo.net/demo1.png',
    excerpt: 'NFC Tools PRO 是一款专为Android设备打造的强大NFC（近场通信）工具。凭借强大的读写能力、灵活的配置选项以及广泛的兼容性，助力用户高效管理和运用手机内置的NFC功能。',
    imageCount: 3,
    likes: 8,
  ),
  153497: ThreadPreview(
    image: 'https://ycoo.net/demo2.png',
    excerpt: '不喜勿喷 002款下载地址：http://4275.com/a2n5kj 内置多线路，支持电视端与手机端播放。',
    imageCount: 1,
  ),
  153495: ThreadPreview(
    excerpt: '一个软件卸载工具，卸载无残留，绿色免安装，支持批量清理注册表与残留目录，卸载后自动备份。',
  ),
};

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

/// 1x1 纯色 PNG（作为图片占位，验证图片区域布局）
final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR4nGOoWfEBK2IYWhIA2sWFARzvhhQAAAAASUVORK5CYII=',
);

ThemeData _theme() {
  final base = AppTheme.light();
  return base.copyWith(textTheme: base.textTheme.apply(fontFamily: 'CJK'));
}

Widget _wrap(Widget child, {Size size = const Size(390, 844)}) {
  return MaterialApp(
    theme: _theme(),
    home: Scaffold(
      backgroundColor: AppTheme.surfaceTint,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: child,
      ),
    ),
  );
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

  testWidgets('golden: 列表卡片', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(_wrap(
      RepaintBoundary(
        key: const Key('list'),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          itemCount: _items.length,
          separatorBuilder: (c, i) => const SizedBox(height: 10),
          itemBuilder: (c, i) => ThreadTile(
            item: _items[i],
            preview: _previews[_items[i].tid],
            showBoard: true,
            onTap: () {},
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byKey(const Key('list')), matchesGoldenFile('goldens/list.png'));
  });

  testWidgets('golden: 详情页正文与评论', (tester) async {
    final html = File('../recon/thread_login.html').existsSync()
        ? File('../recon/thread_login.html').readAsStringSync()
        : File('C:/Users/Administrator/WorkBuddy AI/源论坛/recon/thread_login.html').readAsStringSync();

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
        home: const ThreadDetailPage(tid: 152951, title: '测试帖', fid: 2, boardName: '综合交流'),
      ),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    await expectLater(find.byType(ThreadDetailPage), matchesGoldenFile('goldens/detail_top.png'));

    await tester.scrollUntilVisible(find.text('全部评论'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(milliseconds: 120));
    await expectLater(find.byType(ThreadDetailPage), matchesGoldenFile('goldens/detail_comments.png'));
  });
}
