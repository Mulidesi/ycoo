/// 签到服务：签到操作、状态查询、自动签到、日志记录。
library;

import '../automation/checkin_service.dart';
import '../storage/settings_repository.dart';
import '../storage/automation_models.dart';
import '../../data/forum_api.dart';
import '../../state/settings_model.dart' show AppSettings, dayKey;
import '../../models/models.dart';
import '../automation/background_checkin.dart' as bg;

/// 签到服务。
class CheckinService {
  CheckinService({
    required this.api,
    required this.repo,
    required this.onChange,
  });

  final ForumApi api;
  final SettingsRepository repo;

  /// 状态变化回调（通知 AppState → notifyListeners）。
  final void Function() onChange;

  /// 最近签到日志，最多 100 条。
  List<CheckinLog> checkinLogs = <CheckinLog>[];

  /// 当前签到状态。
  SignStatus? signStatus;

  /// 是否正在签到中。
  bool signing = false;

  /// 上次签到时间。
  DateTime? lastSignAt;

  /// 手动签到。
  Future<SignResult> signNow(UserProfile? user) async {
    if (user == null) return const SignResult(success: false, message: '请先登录');
    if (signing) return const SignResult(success: false, message: '正在签到，请稍候');
    signing = true;
    onChange();
    try {
      final res = await api.sign();
      signStatus = await api.signStatus();
      if (res.success) {
        lastSignAt = DateTime.now();
        await repo.setLastSignDay(dayKey(DateTime.now()));
        await repo.setLastSignAt(lastSignAt!.toIso8601String());
      }
      await _recordCheckinLog(ok: res.success, message: res.message);
      return res;
    } catch (e) {
      await _recordCheckinLog(ok: false, message: e.toString());
      return SignResult(success: false, message: e.toString());
    } finally {
      signing = false;
      onChange();
    }
  }

  /// 刷新签到状态。
  Future<void> loadSignStatus(UserProfile? user) async {
    if (user == null) return;
    try {
      signStatus = await api.signStatus();
      onChange();
    } catch (_) {}
  }

  /// 自动签到：每天最多一次，支持强制刷新。
  Future<SignResult?> autoSignIfNeeded(
    UserProfile? user,
    AppSettings settings, {
    bool force = false,
  }) async {
    if (user == null || !settings.autoSign) return null;
    final today = dayKey(DateTime.now());
    if (!force &&
        (repo.getLastSignDay() == today ||
            CheckinScheduler.isDuplicate(logs: checkinLogs, now: DateTime.now()))) {
      return null;
    }
    try {
      final st = await api.signStatus();
      signStatus = st;
      onChange();
      if (st.signedToday) {
        await repo.setLastSignDay(today);
        return const SignResult(success: true, message: '今天已签到');
      }
      final res = await api.sign();
      signStatus = await api.signStatus();
      if (res.success) {
        lastSignAt = DateTime.now();
        await repo.setLastSignDay(today);
        await repo.setLastSignAt(lastSignAt!.toIso8601String());
      }
      await _recordCheckinLog(ok: res.success, message: res.message);
      onChange();
      return res;
    } catch (e) {
      await _recordCheckinLog(ok: false, message: e.toString());
      return SignResult(success: false, message: e.toString());
    }
  }

  /// 记录签到日志（新→旧，最多 100 条）。
  Future<void> _recordCheckinLog({required bool ok, String? message}) async {
    checkinLogs.insert(
      0,
      CheckinLog(at: DateTime.now(), success: ok, message: message),
    );
    if (checkinLogs.length > 100) {
      checkinLogs.removeRange(100, checkinLogs.length);
    }
    await repo.saveCheckinLogs(checkinLogs);
  }

  /// 登出时清理状态。
  void clearOnLogout() {
    signStatus = null;
  }

  /// 切站时清理状态。
  void clearOnSwitchSite() {
    signStatus = null;
  }

  /// 确保后台周期签到已注册（仅 Android）。
  Future<void> ensureBackgroundCheckin() async {
    try {
      await bg.registerBackgroundCheckin();
    } catch (_) {}
  }

  /// 取消后台周期签到。
  Future<void> cancelBackgroundCheckin() async {
    try {
      await bg.cancelBackgroundCheckin();
    } catch (_) {}
  }
}
