import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycoo_client/ui/pages/update_page.dart';

void main() {
  testWidgets('非 Android 环境提示不支持应用内更新', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UpdatePage()));
    await tester.pumpAndSettle();

    expect(find.textContaining('当前平台不支持应用内更新'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}
