import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycoo_client/core/utils/content_filter.dart';
import 'package:ycoo_client/models/models.dart';
import 'package:ycoo_client/state/app_state.dart';
import 'package:ycoo_client/ui/theme.dart';
import 'package:ycoo_client/ui/widgets/thread_list_view.dart';

ThreadItem _item(int tid, String title) =>
    ThreadItem(tid: tid, title: title, url: '/thread-$tid-1-1.html');

void main() {
  group('标题关键词匹配', () {
    test('包含即命中，忽略大小写与首尾空格', () {
      expect(matchesPostKeyword('每日打卡，领星币', '打卡'), isTrue);
      expect(matchesPostKeyword('DAILY Check-IN', ' check-in '), isTrue);
      expect(matchesPostKeyword('书源分享', '打卡'), isFalse);
      expect(matchesPostKeyword('任意标题', '   '), isFalse);
    });

    test('关闭时不过滤，开启时只隐藏命中标题的帖子', () {
      final items = [
        _item(1, '打卡'),
        _item(2, '每日打卡'),
        _item(3, '正常书源分享'),
      ];
      expect(
        filterThreadsByKeywords(items, enabled: false, keywords: ['打卡']),
        hasLength(3),
      );
      final visible =
          filterThreadsByKeywords(items, enabled: true, keywords: ['打卡']);
      expect(visible.map((e) => e.tid), [3]);
    });
  });

  group('过滤设置', () {
    test('默认开启并过滤「打卡」', () {
      final s = AppSettings();
      expect(s.postFilterEnabled, isTrue);
      expect(s.postFilterKeywords, ['打卡']);
    });

    test('旧版本缺少字段时使用默认值，显式空列表保持为空', () {
      expect(
          AppSettings.fromJson(<String, dynamic>{}).postFilterKeywords, ['打卡']);
      expect(
        AppSettings.fromJson(<String, dynamic>{
          'postFilterKeywords': <String>[],
          'postFilterEnabled': false,
        }).postFilterKeywords,
        isEmpty,
      );
    });

    test('关键词去空白、忽略大小写去重、单条限长', () {
      final out = AppSettings.sanitizePostFilterKeywords([
        ' 打卡 ',
        '打卡',
        'Check-In',
        'check-in',
        '',
        'x' * 31,
      ]);
      expect(out, ['打卡', 'Check-In']);
    });

    test('toJson / fromJson 往返保留过滤设置', () {
      final s = AppSettings(
        postFilterEnabled: false,
        postFilterKeywords: ['打卡', '广告'],
      );
      final back = AppSettings.fromJson(s.toJson());
      expect(back.postFilterEnabled, isFalse);
      expect(back.postFilterKeywords, ['打卡', '广告']);
    });
  });

  group('列表过滤', () {
    Future<void> pumpList(
        WidgetTester tester, AppState state, ThreadListView list) async {
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: list),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('隐藏命中标题并显示过滤计数', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final state = AppState();
      await pumpList(
        tester,
        state,
        ThreadListView(
          loader: (page) async => ThreadPage(
            items: <ThreadItem>[
              _item(1, '每日打卡'),
              _item(2, '正常书源分享'),
            ],
            page: 1,
            totalPages: 1,
          ),
        ),
      );
      expect(find.text('每日打卡'), findsNothing);
      expect(find.text('正常书源分享'), findsOneWidget);
      expect(find.text('已过滤 1 条 · 已经到底了'), findsOneWidget);
    });

    testWidgets('整页被过滤时可继续加载下一页', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final state = AppState();
      final loadedPages = <int>[];
      await pumpList(
        tester,
        state,
        ThreadListView(
          loader: (page) async {
            loadedPages.add(page);
            return ThreadPage(
              items: page == 1
                  ? <ThreadItem>[_item(1, '打卡'), _item(2, '打卡帖')]
                  : <ThreadItem>[_item(3, '第二页正常帖')],
              page: page,
              totalPages: 2,
            );
          },
        ),
      );
      expect(find.text('本页 2 条已全部被关键词过滤'), findsOneWidget);
      await tester.tap(find.text('加载下一页'));
      await tester.pumpAndSettle();
      expect(loadedPages, [1, 2]);
      expect(find.text('第二页正常帖'), findsOneWidget);
    });
  });

  group('点击首页刷新信号', () {
    test('重复点击首页都会递增，切到其他 Tab 不递增', () {
      final st = AppState();
      expect(st.homeRefreshTick, 0);
      st.selectHomeTab(0);
      expect(st.homeRefreshTick, 1);
      st.selectHomeTab(0);
      expect(st.homeRefreshTick, 2);
      st.selectHomeTab(1);
      expect(st.homeTabIndex, 1);
      expect(st.homeRefreshTick, 2);
      st.selectHomeTab(0);
      expect(st.homeTabIndex, 0);
      expect(st.homeRefreshTick, 3);
    });
  });
}
