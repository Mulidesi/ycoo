/// 设置 / 会话数据的 SharedPreferences 持久化仓库。
///
/// 统一所有本地存储的读写入口，AppState 不再直接操作 SharedPreferences。
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'automation_models.dart';

/// 持久化键名常量（与旧版 AppState 兼容）。
abstract final class _Keys {
  static const String cookies = 'cookies';
  static const String settings = 'settings';
  static const String repliedTids = 'replied_tids';
  static const String replyCount = 'reply_count';
  static const String lastSignDay = 'last_sign_day';
  static const String lastSignAt = 'last_sign_at';
  static const String replyLogs = 'reply_logs';
  static const String checkinLogs = 'checkin_logs';
  static const String clipboardSeen = 'clipboard_seen';
}

/// SharedPreferences 仓库。
class SettingsRepository {
  late SharedPreferences _prefs;

  /// 初始化（必须在使用前调用）。
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---------------------------------------------------------- Cookies

  Map<String, String>? loadCookies() {
    final raw = _prefs.getString(_Keys.cookies);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCookies(Map<String, String> cookies) =>
      _prefs.setString(_Keys.cookies, jsonEncode(cookies));

  Future<void> clearCookies() => _prefs.remove(_Keys.cookies);

  // ---------------------------------------------------------- Settings

  /// 加载持久化设置（JSON 解码由仓库内部完成）。
  Map<String, dynamic>? loadSettingsJson() {
    final raw = _prefs.getString(_Keys.settings);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  /// 保存设置（JSON 编码由仓库内部完成）。
  Future<void> saveSettingsJson(Map<String, dynamic> json) =>
      _prefs.setString(_Keys.settings, jsonEncode(json));

  // ---------------------------------------------------------- Sign

  String? getLastSignDay() => _prefs.getString(_Keys.lastSignDay);

  Future<void> setLastSignDay(String day) =>
      _prefs.setString(_Keys.lastSignDay, day);

  String? getLastSignAt() => _prefs.getString(_Keys.lastSignAt);

  Future<void> setLastSignAt(String at) =>
      _prefs.setString(_Keys.lastSignAt, at);

  // ---------------------------------------------------------- Reply

  Set<int> loadRepliedTids() {
    final raw = _prefs.getString(_Keys.repliedTids) ?? '[]';
    try {
      return (jsonDecode(raw) as List).map((e) => e as int).toSet();
    } catch (_) {
      return <int>{};
    }
  }

  Future<void> saveRepliedTids(Set<int> tids) {
    var list = tids.toList();
    if (list.length > 800) list = list.sublist(list.length - 800);
    return _prefs.setString(_Keys.repliedTids, jsonEncode(list));
  }

  Map<String, int> loadReplyCounter() {
    final raw = _prefs.getString(_Keys.replyCount) ?? '{}';
    try {
      return (jsonDecode(raw) as Map)
          .map((k, v) => MapEntry(k.toString(), v as int));
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> saveReplyCounter(Map<String, int> counter) =>
      _prefs.setString(_Keys.replyCount, jsonEncode(counter));

  // ---------------------------------------------------------- Logs

  List<AutoReplyLog> loadReplyLogs() {
    final raw = _prefs.getString(_Keys.replyLogs) ?? '[]';
    try {
      return (jsonDecode(raw) as List)
          .map((e) => AutoReplyLog.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return <AutoReplyLog>[];
    }
  }

  Future<void> saveReplyLogs(List<AutoReplyLog> logs) =>
      _prefs.setString(_Keys.replyLogs,
          jsonEncode(logs.map((l) => l.toJson()).toList()));

  List<CheckinLog> loadCheckinLogs() {
    final raw = _prefs.getString(_Keys.checkinLogs) ?? '[]';
    try {
      return (jsonDecode(raw) as List)
          .map((e) => CheckinLog.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return <CheckinLog>[];
    }
  }

  Future<void> saveCheckinLogs(List<CheckinLog> logs) =>
      _prefs.setString(_Keys.checkinLogs,
          jsonEncode(logs.map((l) => l.toJson()).toList()));

  // ---------------------------------------------------------- Clipboard

  String? getClipboardSeen() => _prefs.getString(_Keys.clipboardSeen);

  Future<void> setClipboardSeen(String url) =>
      _prefs.setString(_Keys.clipboardSeen, url);

  // ---------------------------------------------------------- Clear

  /// 清空所有自动回复相关数据。
  Future<void> clearReplyData() async {
    await _prefs.remove(_Keys.repliedTids);
    await _prefs.remove(_Keys.replyCount);
    await _prefs.remove(_Keys.replyLogs);
  }
}
