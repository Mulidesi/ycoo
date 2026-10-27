import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycoo_client/design/tokens.dart';
import 'package:ycoo_client/ui/theme.dart';
import 'package:ycoo_client/ui/widgets/common.dart';

/// 骨架屏回归：列表加载期间渲染骨架卡片，微光动画推进不报错。
void main() {
  testWidgets('骨架屏列表 渲染骨架卡片并推进微光动画', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SkeletonList()),
      ),
    );
    expect(find.byType(SkeletonList), findsOneWidget);
    expect(find.byType(SkeletonTile), findsWidgets);

    // 动画推进若干帧不应抛错
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SkeletonTile), findsWidgets);
  });

  testWidgets('骨架屏列表 悬浮底栏下预留底部空间', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          extendBody: true,
          body: BottomBarInset(
            value: YuanSizes.bottomBarInset(0),
            child: const SkeletonList(),
          ),
          bottomNavigationBar: const Text('bar'),
        ),
      ),
    );
    expect(find.byType(SkeletonList), findsOneWidget);
    expect(find.byType(SkeletonTile), findsWidgets);
  });
}
