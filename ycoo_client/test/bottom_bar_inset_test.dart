import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycoo_client/design/tokens.dart';
import 'package:ycoo_client/models/models.dart';
import 'package:ycoo_client/state/app_state.dart';
import 'package:ycoo_client/ui/theme.dart';
import 'package:ycoo_client/ui/widgets/common.dart';
import 'package:ycoo_client/ui/widgets/thread_list_view.dart';

/// 悬浮底栏盖在内容之上（`extendBody: true`），
/// 列表必须为它预留底部空间，否则最后一条被胶囊挡住。
void main() {
  group('底栏占位高度', () {
    test('不含安全区时为 80（4 + 64 + 12）', () {
      expect(YuanSizes.barTotalHeight, 80);
    });

    test('含安全区与呼吸距离', () {
      expect(YuanSizes.bottomBarInset(0), YuanSizes.barTotalHeight + YuanSizes.barContentGap);
      expect(YuanSizes.bottomBarInset(34), YuanSizes.barTotalHeight + YuanSizes.barContentGap + 34);
      // 必须大于胶囊本身高度，才能整块让开
      expect(YuanSizes.bottomBarInset(0), greaterThan(YuanSizes.barHeight));
    });
  });

  group('BottomBarInset 传播', () {
    testWidgets('无底栏（二级页面）时为 0', (tester) async {
      late double seen;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          seen = BottomBarInset.of(c);
          return const SizedBox();
        }),
      ));
      expect(seen, 0);
    });

    testWidgets('注入后子树读到同一个值', (tester) async {
      late double seen;
      await tester.pumpWidget(MaterialApp(
        home: BottomBarInset(
          value: 96,
          child: Builder(builder: (c) {
            seen = BottomBarInset.of(c);
            return const SizedBox();
          }),
        ),
      ));
      expect(seen, 96);
    });
  });

  group('帖子列表底部留白', () {
    Future<void> pumpList(WidgetTester tester, {double? inset}) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final state = AppState();
      final list = ThreadListView(
        loader: (page) async => ThreadPage(
          items: <ThreadItem>[
            for (var i = 1; i <= 3; i++)
              ThreadItem(tid: i, title: '帖子 $i', url: '/thread-$i-1-1.html'),
          ],
          page: 1,
          totalPages: 1,
        ),
      );
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: inset == null
              ? Scaffold(body: list)
              : BottomBarInset(value: inset, child: Scaffold(body: list)),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('有悬浮底栏时底部 padding = 24 + 占位高度', (tester) async {
      await pumpList(tester, inset: 96);
      final lv = tester.widget<ListView>(find.byType(ListView).first);
      expect(lv.padding, const EdgeInsets.fromLTRB(12, 10, 12, 24 + 96));
    });

    testWidgets('二级页面（无底栏）保持 24', (tester) async {
      await pumpList(tester);
      final lv = tester.widget<ListView>(find.byType(ListView).first);
      expect(lv.padding, const EdgeInsets.fromLTRB(12, 10, 12, 24));
    });
  });
}
