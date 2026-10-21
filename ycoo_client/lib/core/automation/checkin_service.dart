/// 自动签到调度判定（纯领域逻辑）。
library;

import '../storage/automation_models.dart';

/// 签到调度器。
abstract final class CheckinScheduler {
  /// 后台周期：每 12 小时一次。
  static const Duration periodicInterval = Duration(hours: 12);

  /// 每日去重窗口（小时）。
  static const Duration dedupWindow = Duration(hours: 12);

  /// 每日首选执行时刻（本地时间 9:00）。
  static const int preferredHour = 9;

  /// 自然日键，例如 `2026-10-20`。
  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 当天是否已有成功记录。
  static bool hasSuccessOnDay(List<CheckinLog> logs, DateTime day) {
    final String key = dayKey(day);
    return logs.any((CheckinLog l) =>
        l.success && dayKey(l.at) == key);
  }

  /// 是否到了该执行的时间（距上次成功超过去重窗口）。
  static bool shouldRun({
    required List<CheckinLog> logs,
    required DateTime now,
  }) {
    if (hasSuccessOnDay(logs, now)) return false;
    for (final CheckinLog l in logs) {
      if (!l.success) continue;
      if (now.difference(l.at) < dedupWindow) return false;
    }
    return true;
  }

  /// 是否与最近一次成功记录重复（窗口内）。
  static bool isDuplicate({
    required List<CheckinLog> logs,
    required DateTime now,
  }) {
    for (final CheckinLog l in logs) {
      if (!l.success) continue;
      if (now.difference(l.at) < dedupWindow) return true;
    }
    return false;
  }

  /// 下一次建议执行时刻：下一个 9:00。
  static DateTime nextRunAfter(DateTime from) {
    DateTime candidate = DateTime(from.year, from.month, from.day, preferredHour);
    if (!candidate.isAfter(from)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }
}
