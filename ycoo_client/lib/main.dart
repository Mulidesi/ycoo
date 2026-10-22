import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/automation/background_checkin.dart';
import 'core/navigation/in_app_nav.dart';
import 'state/app_state.dart';
import 'ui/pages/thread_detail_page.dart';
import 'ui/pages/thread_list_page.dart';
import 'ui/pages/user_space_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 站内链接（正文 / 剪贴板）的应用内路由：帖子详情、版块列表
  registerInAppRoutes(
    thread: (tid) => ThreadDetailPage(tid: tid),
    forum: (fid) => ThreadListPage(fid: fid, name: '版块'),
    user: (uid) => UserSpacePage(uid: uid),
  );
  // 后台周期签到（workmanager，仅 Android）
  if (Platform.isAndroid) {
    try {
      await initBackgroundCheckin();
    } catch (_) {}
  }
  final state = AppState();
  await state.init();
  runApp(ChangeNotifierProvider<AppState>.value(value: state, child: const YcooApp()));
}
