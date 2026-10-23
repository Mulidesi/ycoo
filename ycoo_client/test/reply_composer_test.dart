import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/models/models.dart';
import 'package:ycoo_client/state/app_state.dart';
import 'package:ycoo_client/ui/pages/thread_detail_page.dart';
import 'package:ycoo_client/ui/theme.dart';

const _threadHtml = '''
<!DOCTYPE html><html><head><title>测试帖 - 综合交流</title></head><body>
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

void main() {
  testWidgets('键盘弹出时回复输入框仍在可见区域', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final client = DiscuzClient(
      client: MockClient((req) async => http.Response.bytes(
            utf8.encode(_threadHtml),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          )),
    );
    final state = AppState(client: client);
    await state.init();
    state.user = const UserProfile(uid: 1, username: '测试用户');

    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // viewInsets 以物理像素计，固定 DPR 让 300 物理像素等于 300 逻辑像素。
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ThreadDetailPage(tid: 1001, title: '测试帖'),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    // 收起态是假输入框，点击后展开为真正的 TextField。
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('写评论…'));
    await tester.pump(const Duration(milliseconds: 400));

    final composer = find.byType(TextField);
    expect(composer, findsOneWidget);
    expect(tester.getRect(composer).bottom, lessThanOrEqualTo(700));

    // 模拟输入法占用底部 300dp（edge-to-edge 设备不会改变窗口高度）。
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    final rect = tester.getRect(composer);
    expect(rect.bottom, lessThanOrEqualTo(400));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);
  });
}
