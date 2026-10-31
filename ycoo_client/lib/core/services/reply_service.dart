/// 自动回复 / 手动回复服务：自动回复判定、执行、去重、限额、日志。
library;

import 'dart:math';

import '../automation/auto_reply_queue.dart';
import '../automation/automation_engine.dart';
import '../error/app_exception.dart';
import '../storage/automation_models.dart';
import '../storage/settings_repository.dart';
import '../../data/forum_api.dart';
import '../../state/settings_model.dart' show AppSettings, dayKey;
import '../../models/models.dart';

/// 自动回复服务。
class ReplyService {
  ReplyService({
    required this.api,
    required this.repo,
    required this.onChange,
  });

  final ForumApi api;
  final SettingsRepository repo;

  /// 状态变化回调（通知 AppState → notifyListeners）。
  final void Function() onChange;

  /// 自动回复引擎（纯逻辑，可单测）。
  final AutomationEngine automation = AutomationEngine();

  /// 自动回复队列。
  final AutoReplyQueue replyQueue = AutoReplyQueue();

  /// 最近自动回复日志（新→旧），最多 200 条。
  List<AutoReplyLog> replyLogs = <AutoReplyLog>[];

  /// 当前站点标识（单站点运行，固定为 ycoo）。
  static const String _siteId = 'ycoo';

  final Set<int> _repliedTids = <int>{};
  final Set<int> _replyInFlight = <int>{};
  Map<String, int> _replyCounter = <String, int>{};

  /// 今天已自动回复的数量。
  int get todayReplyCount => _replyCounter[dayKey(DateTime.now())] ?? 0;

  /// 今天是否已自动回复过。
  bool get hasAutoRepliedToday => todayReplyCount > 0;

  /// 最后一次自动回复总数。
  int lastAutoReplyCount = 0;

  /// 该帖子是否应该自动回复。
  bool shouldAutoReply(ThreadDetail d, AppSettings settings, UserProfile? user) {
    if (!settings.autoReply || user == null) return false;
    if (!d.needsReply || d.fid == 0) return false;
    if (_repliedTids.contains(d.tid) || _replyInFlight.contains(d.tid)) return false;
    if (settings.replyWhitelist.isNotEmpty &&
        !settings.replyWhitelist.contains(d.fid)) {
      return false;
    }
    return todayReplyCount < settings.dailyReplyLimit;
  }

  /// 加载持久化数据（在 AppState.init 中调用）。
  void loadPersisted(SettingsRepository repo) {
    _repliedTids
      ..clear()
      ..addAll(repo.loadRepliedTids());
    _replyCounter = repo.loadReplyCounter();
  }

  /// 隐藏贴自动回复：仅在用户真正打开帖子时触发。
  Future<ReplyResult?> maybeAutoReply(
    ThreadDetail d,
    AppSettings settings,
    UserProfile? user,
  ) async {
    if (!shouldAutoReply(d, settings, user)) return null;
    _replyInFlight.add(d.tid);
    try {
      await Future.delayed(Duration(milliseconds: 2200 + Random().nextInt(3800)));

      final Preset preset;
      try {
        preset = automation.pickPreset(settings.effectivePresets);
      } on StateError {
        return const ReplyResult(
          success: false,
          message: '没有可用的自动回复预设，请先在「我的 → 自动回复内容」中添加',
        );
      }

      final String message = automation.buildMessage(
        preset,
        authorName: d.posts.isNotEmpty ? d.posts.first.author : '',
        threadTitle: d.title,
      );

      final res = await api.reply(tid: d.tid, fid: d.fid, message: message);
      await _recordReplyLog(
        tid: d.tid,
        text: message,
        ok: res.success,
        error: res.message,
      );
      replyQueue.markProcessed(_siteId, d.tid, ok: res.success, text: message);

      if (res.success) {
        _repliedTids.add(d.tid);
        _bumpReplyCount();
        lastAutoReplyCount = todayReplyCount;
        await repo.saveRepliedTids(_repliedTids);
        onChange();
      }
      return res;
    } catch (e) {
      return ReplyResult(success: false, message: e.toString());
    } finally {
      _replyInFlight.remove(d.tid);
    }
  }

  /// 手动回复。
  Future<ReplyResult> manualReply(ThreadDetail d, String message) async {
    ReplyResult res;
    try {
      res = await api.reply(tid: d.tid, fid: d.fid, message: message);
    } on AppException catch (e) {
      return ReplyResult(success: false, message: e.displayMessage);
    } catch (_) {
      return const ReplyResult(success: false, message: '回复失败，网络异常，请重试');
    }
    if (res.success) {
      _repliedTids.add(d.tid);
      _bumpReplyCount();
      await repo.saveRepliedTids(_repliedTids);
      onChange();
    }
    return res;
  }

  /// 该帖子是否已回复过。
  bool hasReplied(int tid) => _repliedTids.contains(tid);

  /// 记录自动回复日志（新→旧，最多 200 条）。
  Future<void> _recordReplyLog({
    required int tid,
    required String text,
    required bool ok,
    String? error,
  }) async {
    replyLogs.insert(
      0,
      AutoReplyLog(
        tid: tid,
        siteId: _siteId,
        sentText: text,
        success: ok,
        at: DateTime.now(),
        error: error,
      ),
    );
    if (replyLogs.length > 200) {
      replyLogs.removeRange(200, replyLogs.length);
    }
    await repo.saveReplyLogs(replyLogs);
  }

  void _bumpReplyCount() {
    final k = dayKey(DateTime.now());
    _replyCounter = {..._replyCounter, k: (_replyCounter[k] ?? 0) + 1};
    repo.saveReplyCounter(_replyCounter);
  }

  /// 清空所有自动回复历史。
  Future<void> clearAutoReplyHistory() async {
    _repliedTids.clear();
    _replyCounter = {};
    replyLogs.clear();
    replyQueue.cancelAll();
    await repo.clearReplyData();
    onChange();
  }

  /// 同步队列开关与预设。
  void syncQueue(AppSettings settings) {
    replyQueue.setEnabled(settings.autoReply);
    replyQueue.setPresets(settings.effectivePresets);
  }
}
