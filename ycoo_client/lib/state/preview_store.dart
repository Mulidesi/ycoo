/// 列表预览（首图 / 摘要 / 点赞）的内存缓存与后台加载。
///
/// 设计要点：
///   * 按 **版块 + 页码** 请求，一次拿回整页帖子的预览，避免逐帖抓详情；
///   * 并发 2 + 每次请求间隔 250ms，列表打开时不会瞬间打出一串请求；
///   * 命中 429 时整体冷却 8 秒再继续，避免被站点限流；
///   * 请求成功后通知 UI 增量刷新，卡片先出文字、再补首图，不阻塞首屏；
///   * 同一版块同一页只请求一次（失败也记住，不反复重试）。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/discuz_client.dart';
import '../data/previews.dart';
import '../models/models.dart';

class PreviewStore extends ChangeNotifier {
  PreviewStore(this._client);

  final DiscuzClient _client;

  final Map<int, ThreadPreview> _byTid = <int, ThreadPreview>{};
  final Map<String, int> _fidState = <String, int>{}; // 0=进行中 1=成功 2=失败
  final List<({int fid, int page})> _queue = <({int fid, int page})>[];
  int _active = 0;
  bool _notifyScheduled = false;
  bool _disposed = false;
  DateTime? _cooldownUntil;
  Timer? _cooldownTimer;

  static const int _maxConcurrent = 2;
  static const int _maxCache = 2000;
  static const Duration _pacing = Duration(milliseconds: 250);
  static const Duration _cooldown = Duration(seconds: 8);

  ThreadPreview? of(int tid) => _byTid[tid];

  /// 请求一批条目的预览。已缓存 / 已请求过的版块会被跳过。
  void request(Iterable<ThreadItem> items, {int page = 1}) {
    if (_disposed) return;
    final byFid = <int, int>{};
    for (final it in items) {
      if (_byTid.containsKey(it.tid)) continue;
      final fid = it.fid;
      if (fid == null || fid == 0) continue;
      byFid[fid] = page;
    }
    if (byFid.isEmpty) return;

    var queued = false;
    byFid.forEach((fid, p) {
      final key = '$fid:$p';
      if (_fidState.containsKey(key)) return;
      _fidState[key] = 0;
      _queue.add((fid: fid, page: p));
      queued = true;
    });
    if (queued) _pump();
  }

  void _pump() {
    if (_disposed) return;
    final until = _cooldownUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      _cooldownTimer ??= Timer(until.difference(DateTime.now()) + const Duration(milliseconds: 50), () {
        _cooldownTimer = null;
        _pump();
      });
      return;
    }
    while (_active < _maxConcurrent && _queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      _active++;
      unawaited(_fetch(job.fid, job.page));
    }
  }

  Future<void> _fetch(int fid, int page) async {
    final key = '$fid:$page';
    try {
      // 简单节流：让请求之间留出间隔
      await Future<void>.delayed(_pacing);
      if (_disposed) return;
      final res = await _client.get(
        'api/mobile/index.php?version=4&module=forumdisplay&fid=$fid&page=$page',
        referer: 'https://ycoo.net/forum-$fid-$page.html',
      );
      if (res.statusCode == 429) {
        // 被限流：放回队列，整体冷却后再试
        _fidState.remove(key);
        _queue.add((fid: fid, page: page));
        _cooldownUntil = DateTime.now().add(_cooldown);
        return;
      }
      final map = res.statusCode == 200 ? parseForumDisplayPreviews(res.body) : <int, ThreadPreview>{};
      if (map.isEmpty) {
        _fidState[key] = 2;
      } else {
        _byTid.addAll(map);
        _fidState[key] = 1;
        if (_byTid.length > _maxCache) {
          _byTid.clear();
          _fidState.clear();
        }
      }
    } catch (_) {
      _fidState[key] = 2;
    } finally {
      _active--;
      _scheduleNotify();
      _pump();
    }
  }

  /// 一批请求完成后只通知一次，避免列表重复重建
  void _scheduleNotify() {
    if (_disposed || _notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _cooldownTimer?.cancel();
    _queue.clear();
    super.dispose();
  }
}
