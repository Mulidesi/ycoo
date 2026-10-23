/// 玻璃回复栏：展开 / 发布 / 状态图标回归。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:ycoo_client/ui/theme.dart';
import 'package:ycoo_client/ui/widgets/glass_reply_bar.dart';

Widget _host(Widget child) => LiquidGlassWidgets.wrap(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: child),
        ),
      ),
    );

Widget _bar({
  required TextEditingController controller,
  required bool expanded,
  required ValueChanged<bool> onExpandedChanged,
  VoidCallback? onSend,
  bool liked = false,
  bool favorited = false,
  bool busy = false,
}) {
  return GlassReplyBar(
    controller: controller,
    expanded: expanded,
    onExpandedChanged: onExpandedChanged,
    onSend: onSend ?? () {},
    onLike: () {},
    onFavorite: () {},
    onShare: () {},
    liked: liked,
    favorited: favorited,
    busy: busy,
  );
}

void main() {
  testWidgets('收起态只有提示与操作，点击后展开输入框', (tester) async {
    var expanded = false;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(StatefulBuilder(
      builder: (context, setState) => _bar(
        controller: controller,
        expanded: expanded,
        onExpandedChanged: (v) => setState(() => expanded = v),
      ),
    )));

    expect(find.text('写评论…'), findsOneWidget);
    expect(find.byKey(const ValueKey('glass-reply-input')), findsNothing);
    expect(find.byIcon(Icons.thumb_up_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);

    await tester.tap(find.text('写评论…'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('glass-reply-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('glass-reply-send')), findsOneWidget);
  });

  testWidgets('输入内容后「发布」可用并回调', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sent = 0;

    await tester.pumpWidget(_host(_bar(
      controller: controller,
      expanded: true,
      onExpandedChanged: (_) {},
      onSend: () => sent++,
    )));

    final send = find.byKey(const ValueKey('glass-reply-send'));
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('glass-reply-input')),
      '支持一下',
    );
    await tester.pump();

    expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
    await tester.tap(send);
    expect(sent, 1);
  });

  testWidgets('已点赞/收藏显示高亮图标，忙时禁用点赞', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(_bar(
      controller: controller,
      expanded: false,
      onExpandedChanged: (_) {},
      liked: true,
      favorited: true,
      busy: true,
    )));

    expect(find.byIcon(Icons.thumb_up_alt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);

    final like = tester.widget<GlassIconButton>(
      find.byKey(const ValueKey('glass-reply-like')),
    );
    final favorite = tester.widget<GlassIconButton>(
      find.byKey(const ValueKey('glass-reply-favorite')),
    );
    expect(like.onPressed, isNull);
    expect(favorite.onPressed, isNull);
  });
}
