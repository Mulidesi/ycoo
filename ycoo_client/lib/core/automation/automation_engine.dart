/// 自动回复引擎（纯领域逻辑，无 Flutter / 网络依赖，便于单测）。
///
/// 职责：判定是否应该入队、随机挑选预设、渲染占位符、判定曝光是否成立。
/// 实际发送由 `AutoReplyQueue` + 调用方（AppState）完成。
library;

import 'dart:math';

import '../storage/automation_models.dart';

/// 待入队的自动回复。
class PendingReply {
  const PendingReply({
    required this.tid,
    required this.fid,
    required this.title,
    required this.authorName,
    required this.siteId,
    required this.enqueuedAt,
  });

  final int tid;
  final int fid;
  final String title;
  final String authorName;
  final String siteId;
  final DateTime enqueuedAt;

  /// 去重键：站点 + 帖子。
  String get key => '$siteId:$tid';
}

/// 自动回复引擎。
class AutomationEngine {
  AutomationEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 同一帖子在窗口期内只处理一次。
  static const Duration dedupWindow = Duration(hours: 24);

  /// 队列容量上限。
  static const int maxQueueSize = 200;

  /// 是否应该为这个帖子入队。
  ///
  /// [enabled] 总开关；[validPresetCount] 有效预设条数（至少 1 条）；
  /// [processedKeys] 已处理过的 `siteId:tid` 集合；
  /// [exposed] 是否达到曝光阈值。
  bool shouldEnqueue({
    required bool enabled,
    required int validPresetCount,
    required int tid,
    required String siteId,
    required Set<String> processedKeys,
    required bool exposed,
    required int queueLength,
  }) {
    if (!enabled) return false;
    if (validPresetCount < 1) return false;
    if (!exposed) return false;
    if (processedKeys.contains('$siteId:$tid')) return false;
    if (queueLength >= maxQueueSize) return false;
    return true;
  }

  /// 随机挑选一条预设（等概率）。
  Preset pickPreset(List<Preset> presets) {
    final List<Preset> valid = presets.where((Preset p) => p.isValid).toList();
    if (valid.isEmpty) {
      throw StateError('没有可用的自动回复预设');
    }
    return valid[_random.nextInt(valid.length)];
  }

  /// 渲染预设占位符。
  ///
  /// 支持 `{author}`（楼主昵称）与 `{title}`（帖子标题）。
  String buildMessage(
    Preset preset, {
    String authorName = '',
    String threadTitle = '',
  }) {
    return preset.text
        .replaceAll('{author}', authorName)
        .replaceAll('{title}', threadTitle)
        .trim();
  }

  /// 曝光是否成立：可见比例达标即视为有效曝光。
  ///
  /// 停留时长由调用方累计（`AppState` 里按 1.2 秒判定）。
  bool isExposed(double visibleRatio) => visibleRatio >= 0.6;
}
