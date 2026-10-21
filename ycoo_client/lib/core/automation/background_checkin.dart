/// 后台周期签到（workmanager）。
///
/// 仅 Android 生效：登录后注册 ~4 小时周期任务，回调在独立 isolate 里
/// 重建 AppState 并执行 `autoSignIfNeeded`（内部有当日去重 / 12h 窗口），
/// 因此重复唤醒不会重复签到。签到开关、每日上限沿用设置。
library;

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../state/app_state.dart';

/// 周期任务唯一名（同时用作 tag）。
const String kBgCheckinTask = 'net.ycoo.ycoo_client.autoCheckin';

/// main.dart 启动时调用一次（仅 Android）。
Future<void> initBackgroundCheckin() async {
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
}

/// 登录后注册周期任务。
Future<void> registerBackgroundCheckin() async {
  await Workmanager().registerPeriodicTask(
    kBgCheckinTask,
    kBgCheckinTask,
    frequency: const Duration(hours: 4),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}

/// 登出后取消。
Future<void> cancelBackgroundCheckin() async {
  await Workmanager().cancelByUniqueName(kBgCheckinTask);
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final AppState state = AppState();
      await state.init();
      try {
        // 未登录 / 设置关闭自动签到时内部直接跳过；当日已签去重。
        await state.autoSignIfNeeded();
      } finally {
        state.dispose();
      }
    } catch (_) {
      // 后台任务失败不打断；下个周期会再试
    }
    return true;
  });
}
