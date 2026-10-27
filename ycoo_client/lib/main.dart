import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/automation/background_checkin.dart';
import 'core/navigation/in_app_nav.dart';
import 'design/tokens.dart';
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
  // 后台周期签到（内部自行判断平台，非 Android 直接跳过）
  try {
    await initBackgroundCheckin();
  } catch (_) {}
  // 液态玻璃：预热 shader（首帧不闪白），并统一磨砂/厚度与降级策略。
  await LiquidGlassWidgets.initialize();
  final state = AppState();
  await state.init();
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: LiquidGlassWidgets.wrap(
        adaptiveQuality: true,
        respectSystemAccessibility: true,
        brightnessResolver: Theme.maybeBrightnessOf,
        theme: GlassThemeData.simple(
          blur: YuanGlass.blur,
          thickness: YuanGlass.thickness,
        ),
        child: const YcooApp(),
      ),
    ),
  );
}
