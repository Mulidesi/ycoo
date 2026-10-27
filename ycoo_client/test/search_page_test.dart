/// P14：搜索页筛选条（Issue #1）widget 冒烟测试。
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/state/app_state.dart';
import 'package:ycoo_client/ui/pages/search_page.dart';
import 'package:ycoo_client/ui/theme.dart';

const String _boardHtml = '''
<html><body>
<h2><a href="forum.php?mod=forumdisplay&amp;gid=1">书源交流</a></h2>
<div id="category_1"><dl><dt><a href="forum-2-1.html">书源发布</a></dt>
<dd><em>主题 10</em><em><span title="50">50</span></em></dd></dl></div>
<h2><a href="forum.php?mod=forumdisplay&amp;gid=2">网络资源</a></h2>
<div id="category_2"><dl><dt><a href="forum-3-1.html">软件分享</a></dt>
<dd><em>主题 20</em><em><span title="80">80</span></em></dd></dl></div>
</body></html>
''';

const String _xunHtml = '''
<html><body><dl class="result-list">
  <dt><a href="forum.php?mod=viewthread&amp;tid=123"><h4>91 <em>番茄</em>更新</h4></a></dt>
  <dd><p>摘要</p><p class="field-info"><span>发帖时间:2025-8-29</span>
  <span>作者:<a href="home.php?mod=space&amp;uid=47753">妍希</a></span>
  <span><a href="forum.php?mod=forumdisplay&amp;fid=2">书源发布</a></span></p></dd>
</dl></body></html>
''';

http.Response _html(String body) => http.Response.bytes(utf8.encode(body), 200);

void main() {
  testWidgets('搜索页：筛选条渲染完整，切换条件自动重搜', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final state = AppState(
      client: DiscuzClient(
        client: MockClient((r) async {
          final url = r.url.toString();
          if (url.contains('twpx_xunsearch')) return _html(_xunHtml);
          if (url.contains('forum.php')) return _html(_boardHtml);
          if (url.contains('forum-')) {
            return _html('<html><body></body></html>');
          }
          return http.Response('not found', 404);
        }),
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SearchPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '番茄');
    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();

    // 结果页显示筛选条
    expect(find.text('全文'), findsOneWidget);
    expect(find.text('标题'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('相关性'), findsOneWidget);
    expect(find.text('所有版块'), findsOneWidget);
    expect(find.text('模糊'), findsOneWidget);
    expect(find.text('同义词'), findsOneWidget);
    expect(find.text('番茄更新'), findsOneWidget);

    // 切到标题范围 → 自动重搜（URL 含 f=subject）
    await tester.tap(find.text('标题').last);
    await tester.pumpAndSettle();
    expect(find.text('番茄更新'), findsOneWidget);

    // 开模糊开关 → 自动重搜（URL 含 m=yes）
    await tester.tap(find.widgetWithText(FilterChip, '模糊'));
    await tester.pumpAndSettle();
    expect(find.text('番茄更新'), findsOneWidget);

    // 同义词开关可关
    await tester.tap(find.widgetWithText(FilterChip, '同义词'));
    await tester.pumpAndSettle();
    expect(find.text('番茄更新'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('搜索页：版块选择器按分组列出，选择后生效', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final state = AppState(
      client: DiscuzClient(
        client: MockClient((r) async {
          final url = r.url.toString();
          if (url.contains('twpx_xunsearch')) return _html(_xunHtml);
          if (url.contains('forum.php')) return _html(_boardHtml);
          if (url.contains('forum-')) {
            return _html('<html><body></body></html>');
          }
          return http.Response('not found', 404);
        }),
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SearchPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '番茄');
    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, '所有版块'));
    await tester.pumpAndSettle();

    // 底部弹层：分组标题 + 所有版块 + 具体版块
    expect(find.text('书源交流'), findsOneWidget);
    expect(find.text('网络资源'), findsOneWidget);
    expect(find.text('书源发布').last, findsWidgets);
    expect(find.text('软件分享').last, findsWidgets);

    await tester.tap(find.text('软件分享').last);
    await tester.pumpAndSettle();
    expect(find.text('软件分享'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
