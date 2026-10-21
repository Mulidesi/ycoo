/// 自动回复队列：纯领域逻辑，无 Flutter / 网络依赖。
///
/// 维护待发送队列、去重集合与有效预设统计；
/// 实际发送由调用方通过 `dequeue()` 取出后完成。
library;

import 'automation_engine.dart';
import '../storage/automation_models.dart';

/// 自动回复队列。
class AutoReplyQueue {
  AutoReplyQueue({int maxPending = AutomationEngine.maxQueueSize})
      : _maxPending = maxPending;

  final int _maxPending;

  final List<PendingReply> _pending = <PendingReply>[];
  final Set<String> _processed = <String>{};

  bool _enabled = false;
  List<Preset> _presets = const <Preset>[];

  /// 总开关。
  bool get enabled => _enabled;

  /// 待发送数量。
  int get pendingCount => _pending.length;

  /// 待发送列表（只读副本）。
  List<PendingReply> get pending => List<PendingReply>.unmodifiable(_pending);

  /// 已处理数量。
  int get processedCount => _processed.length;

  /// 有效预设条数（非空且不超长）。
  int get validPresetCount => _presets.where((Preset p) => p.isValid).length;

  /// 该帖子是否已处理过。
  bool isProcessed(String siteId, int tid) =>
      _processed.contains('$siteId:$tid');

  /// 设置总开关。返回是否发生变化。
  bool setEnabled(bool value) {
    if (_enabled == value) return false;
    _enabled = value;
    if (!value) _pending.clear();
    return true;
  }

  /// 更新预设。
  void setPresets(List<Preset> presets) {
    _presets = List<Preset>.from(presets);
  }

  /// 入队。已处理过或队列满时返回 false。
  bool enqueue(PendingReply reply) {
    if (_processed.contains(reply.key)) return false;
    if (_pending.any((PendingReply p) => p.key == reply.key)) return false;
    if (_pending.length >= _maxPending) return false;
    _pending.add(reply);
    return true;
  }

  /// 出队最早一条。
  PendingReply? dequeue() => _pending.isEmpty ? null : _pending.removeAt(0);

  /// 标记已处理。
  void markProcessed(
    String siteId,
    int tid, {
    required bool ok,
    String? text,
    DateTime? now,
  }) {
    _processed.add('$siteId:$tid');
    _pending.removeWhere((PendingReply p) => p.key == '$siteId:$tid');
    if (_processed.length > 5000) {
      _processed.remove(_processed.first);
    }
    // 日志写入由调用方处理（保持本队列纯逻辑）
    assert(ok || text == null, '失败时可携带错误信息');
  }

  /// 允许某帖子再次回复（用户手动解除去重）。
  void forget(String siteId, int tid) {
    _processed.remove('$siteId:$tid');
  }

  /// 清空队列与去重记录。
  void cancelAll() {
    _pending.clear();
    _processed.clear();
  }
}
