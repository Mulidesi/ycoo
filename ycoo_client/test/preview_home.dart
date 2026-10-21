import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycoo_client/design/glass/liquid_glass_bar.dart';
import 'package:ycoo_client/design/tokens.dart';
import 'package:ycoo_client/models/models.dart';
import 'package:ycoo_client/ui/theme.dart';
import 'package:ycoo_client/ui/widgets/common.dart';
import 'package:ycoo_client/ui/widgets/thread_tile.dart';

/// 悬浮底栏 + 列表的版式预览：最后一条帖子必须完整露在玻璃胶囊上方。
///
/// 产物：`test/goldens/home_bottom.png`
void main() {
  testWidgets('preview: 悬浮底栏不遮挡列表末条', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final items = <ThreadItem>[
      for (var i = 1; i <= 6; i++)
        ThreadItem(
          tid: i,
          title: '第 $i 条帖子标题，用来检查底栏是否遮挡内容',
          url: '/thread-$i-1-1.html',
          author: '木里得斯',
          replies: 10 * i,
          views: 100 * i,
          timeText: '$i 小时前',
          typeName: '精品软件',
        ),
    ];

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        extendBody: true,
        appBar: AppBar(title: const Text('版块')),
        body: BottomBarInset(
          value: YuanSizes.bottomBarInset(0),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 24 + YuanSizes.bottomBarInset(0)),
            itemCount: items.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (c, i) {
              if (i == items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text('已经到底了', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                );
              }
              return ThreadTile(
                item: items[i],
                showBoard: true,
                onTap: () {},
              );
            },
          ),
        ),
        bottomNavigationBar: LiquidGlassBar(
          destinations: const <BarDestination>[
            BarDestination(icon: Icons.article_outlined, selectedIcon: Icons.article_rounded, label: '首页'),
            BarDestination(icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, label: '版块'),
            BarDestination(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: '我的'),
          ],
          currentIndex: 1,
          onSelected: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 滚动到底，检查最后一条与底栏没有重叠
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/home_bottom.png'),
    );
  });
}
