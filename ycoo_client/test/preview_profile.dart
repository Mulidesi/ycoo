// 「我的」页资料卡预览：把真实积分/统计填进去渲染成 PNG，人工比对版式。
// 运行：flutter test test/preview_profile.dart --update-goldens
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/models/models.dart';
import 'package:ycoo_client/state/app_state.dart';
import 'package:ycoo_client/ui/pages/profile_page.dart';
import 'package:ycoo_client/ui/theme.dart';

Future<void> _loadFont() async {
  for (final p in ['C:/Windows/Fonts/msyh.ttc', 'C:/Windows/Fonts/simhei.ttf']) {
    final f = File(p);
    if (!f.existsSync()) continue;
    final bytes = await f.readAsBytes();
    final loader = FontLoader('CJK')..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
    return;
  }
}

ThemeData _theme() {
  final base = AppTheme.light();
  return base.copyWith(textTheme: base.textTheme.apply(fontFamily: 'CJK'));
}

void main() {
  setUpAll(_loadFont);

  testWidgets('preview: 我的页资料卡', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(client: DiscuzClient());
    await state.init();
    // 真实接口值（2026-10-21 抓取 uid=31981）
    state.user = const UserProfile(
      uid: 31981,
      username: '木里得斯',
      group: '注册会员',
      points: 9207,
      coins: 2021,
      exp: 8456,
      contribution: 1506,
      posts: 714,
      threads: 39,
      following: 20,
      followers: 188,
      friends: 1,
      onlineHours: 362,
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: _theme(),
        home: const ProfilePage(),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await expectLater(find.byType(ProfilePage), matchesGoldenFile('goldens/profile_card.png'));
  });
}
