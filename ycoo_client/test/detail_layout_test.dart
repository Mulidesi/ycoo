import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/state/app_state.dart';
import 'package:ycoo_client/ui/pages/thread_detail_page.dart';
import 'package:ycoo_client/ui/theme.dart';

/// 用真实帖子页 HTML 做离线渲染，检查「正文 / 评论」版式是否成立。
String? _loadFixture() {
  const candidates = [
    '../recon/thread_login.html',
    'C:/Users/Administrator/WorkBuddy AI/源论坛/recon/thread_login.html',
  ];
  for (final p in candidates) {
    final f = File(p);
    if (f.existsSync()) return f.readAsStringSync();
  }
  return null;
}

void main() {
  final html = _loadFixture();

  testWidgets('详情页：正文成篇、评论区独立分栏', (tester) async {
    if (html == null) {
      markTestSkipped('缺少 recon/thread_login.html');
      return;
    }

    SharedPreferences.setMockInitialValues({});
    final client = DiscuzClient(
      client: MockClient((req) async => http.Response.bytes(
            // Discuz 页面是 UTF-8，用 bytes 避免 header 编码干扰
            utf8.encode(html),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          )),
    );
    final state = AppState(client: client);
    await state.init();

    await tester.binding.setSurfaceSize(const Size(390, 1200));
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ThreadDetailPage(tid: 152951, title: '测试帖', fid: 2, boardName: '综合交流'),
        ),
      ),
    );

    // 等首屏加载完成（不 pumpAndSettle：图片加载动画会一直转）
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(tester.takeException(), isNull);
    // 正文区：标题 + 版块标签
    expect(find.text('综合交流'), findsWidgets);
    // 正文操作区
    expect(find.text('复制正文'), findsOneWidget);
    expect(find.text('分享'), findsWidgets);

    // 评论区在正文下方，滚动到可见
    await tester.scrollUntilVisible(find.text('全部评论'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(milliseconds: 60));

    // 评论区独立标题 + 排序
    expect(find.text('全部评论'), findsOneWidget);
    expect(find.text('正序'), findsOneWidget);
    expect(find.text('倒序'), findsOneWidget);
    // 楼层名
    expect(find.text('沙发'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
