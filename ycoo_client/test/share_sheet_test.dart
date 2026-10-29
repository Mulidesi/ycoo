/// 详情页分享弹层：入口文案与锁定帖禁用状态。
///
/// 弹层走 `GlassModalSheet`（独立路由），所以只断言文案与入口存在，
/// 不触发真正的图片生成（那需要网络与图片解码）。
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
import 'package:ycoo_client/ui/pages/thread_detail_page.dart';
import 'package:ycoo_client/ui/theme.dart';

/// 正常帖：正文可见。
const String _htmlVisible = '''
<!DOCTYPE html><html><head><title>可见贴 - 综合交流</title></head><body>
<form id="fastpostform" action="forum.php?mod=post&amp;action=reply&amp;fid=2&amp;tid=1001"></form>
<div id="post_1001" class="comiis_vpost comiis_vone">
  <div class="pct"><div class="pcb">
    <div class="authi">
      <a class="km_name" href="home.php?mod=space&amp;uid=1">测试用户</a>
    </div>
    <div class="t_fsz">
      <table cellspacing="0" cellpadding="0"><tr>
        <td class="t_f" id="postmessage_1001">正文内容</td>
      </tr></table>
    </div>
  </div></div>
</div>
</body></html>
''';

/// 付费帖：正文被 locked 顶掉，当前用户无权限，`分享为图片` 应禁用。
const String _htmlLocked = '''
<!DOCTYPE html><html><head><title>付费贴 - 综合交流</title></head><body>
<form id="fastpostform" action="forum.php?mod=post&amp;action=reply&amp;fid=2&amp;tid=1002"></form>
<div id="post_1002" class="comiis_vpost comiis_vone">
  <div class="pct"><div class="pcb">
    <div class="locked">
      <a href="forum.php?mod=misc&amp;action=pay&amp;tid=1002&amp;pid=2002">购买主题</a>
      本主题需向作者支付 <strong>5 星币</strong> 才能浏览
    </div>
  </div></div>
</div>
</body></html>
''';

Future<AppState> _pumpDetail(WidgetTester tester, String html, int tid) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final client = DiscuzClient(
    client: MockClient((req) async => http.Response.bytes(
          utf8.encode(html),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        )),
  );
  final state = AppState(client: client);
  await state.init();

  await tester.binding.setSurfaceSize(const Size(390, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: ThreadDetailPage(tid: tid, title: '测试帖', fid: 2, boardName: '综合交流'),
      ),
    ),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  return state;
}

Future<void> _openShareSheet(WidgetTester tester) async {
  await tester.tap(find.text('分享').first);
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('分享弹层含「分享为图片 / 复制链接 / 浏览器」三项', (tester) async {
    await _pumpDetail(tester, _htmlVisible, 1001);
    expect(tester.takeException(), isNull);

    await _openShareSheet(tester);
    expect(find.text('分享本帖'), findsOneWidget);
    expect(find.text('分享为图片'), findsOneWidget);
    expect(find.text('复制链接'), findsOneWidget);
    expect(find.text('在浏览器打开'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('锁定帖点击「分享为图片」提示需登录或购买', (tester) async {
    await _pumpDetail(tester, _htmlLocked, 1002);
    expect(tester.takeException(), isNull);

    await _openShareSheet(tester);
    final entry = find.byKey(const ValueKey('share-as-image'));
    expect(entry, findsOneWidget);

    await tester.tap(entry);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('正文需登录或购买后可见'), findsOneWidget);
    // 不进入生成流程：进度弹窗不应出现。
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
