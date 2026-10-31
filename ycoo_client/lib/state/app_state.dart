/// 全局状态：登录态、签到、设置、自动回复配额。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/automation/auto_reply_queue.dart';
import '../core/automation/automation_engine.dart';
import '../core/discuz_client.dart';
import '../core/image_loader.dart';
import '../core/network/site_config.dart';
import '../core/services/checkin_service.dart';
import '../core/services/reply_service.dart';
import '../core/services/site_manager.dart';
import '../core/session/session_service.dart';
import '../core/storage/automation_models.dart';
import '../core/storage/settings_repository.dart';
import '../data/forum_api.dart';
import '../data/parsers.dart' show setBaseUrl;
import '../models/models.dart';
import 'preview_store.dart';
import 'settings_model.dart';

// 设置模型已拆分到 settings_model.dart；此处 re-export 保持旧引用兼容。
export 'settings_model.dart' show AppSettings, dayKey;

class AppState extends ChangeNotifier {
  /// [client] 仅用于测试注入（MockClient），生产环境走默认实现。
  AppState({DiscuzClient? client}) : client = client ?? DiscuzClient();

  final DiscuzClient client;
  late final ForumApi api = ForumApi(client);
  late final PreviewStore previews = PreviewStore(client);

  /// 自动回复引擎（委托给 ReplyService）。
  AutomationEngine get automation => _reply.automation;

  late SettingsRepository _repo;
  late SessionService _session;
  late CheckinService _checkin;
  late ReplyService _reply;
  late SiteManager _site;

  SettingsRepository get repo => _repo;
  SessionService get session => _session;
  CheckinService get checkinService => _checkin;
  ReplyService get replyService => _reply;

  AppSettings settings = AppSettings();

  UserProfile? get user => _session.user;
  set user(UserProfile? value) => _session.user = value;
  SignStatus? get signStatus => _checkin.signStatus;
  bool get signing => _checkin.signing;
  bool booting = true;
  String? bootError;
  int homeTabIndex = 0;
  int homeRefreshTick = 0;
  DateTime? get lastSignAt => _checkin.lastSignAt;
  List<AutoReplyLog> get replyLogs => _reply.replyLogs;
  List<CheckinLog> get checkinLogs => _checkin.checkinLogs;
  bool get loggedIn => _session.loggedIn;
  bool get hasAutoRepliedToday => _reply.hasAutoRepliedToday;
  int get todayReplyCount => _reply.todayReplyCount;
  int get lastAutoReplyCount => _reply.lastAutoReplyCount;
  AutoReplyQueue get replyQueue => _reply.replyQueue;

  String? _clipboardSeen;

  void selectHomeTab(int index) {
    if (index < 0 || index > 2) return;
    if (index == 0) {
      homeTabIndex = 0;
      homeRefreshTick++;
    } else if (index != homeTabIndex) {
      homeTabIndex = index;
    } else {
      return;
    }
    notifyListeners();
  }

  ForumSite get site => ForumSite.byId(settings.siteId);

  Future<void> init() async {
    _repo = SettingsRepository();
    await _repo.init();
    DiscuzImageProvider.cookieProvider = () => client.cookieHeader;
    final settingsJson = _repo.loadSettingsJson();
    if (settingsJson != null) {
      try {
        settings = AppSettings.fromJson(settingsJson);
      } catch (_) {}
    }
    setBaseUrl(site.origin);
    client.baseUrl = site.origin;
    _clipboardSeen = _repo.getClipboardSeen();
    _session = SessionService(
      client: client, repo: _repo, onChange: notifyListeners);
    _checkin = CheckinService(
      api: api, repo: _repo, onChange: notifyListeners);
    _reply = ReplyService(
      api: api, repo: _repo, onChange: notifyListeners);
    _site = SiteManager(
      client: client,
      repo: _repo,
      session: _session,
      checkin: _checkin,
      onChange: notifyListeners,
    );
    final at = _repo.getLastSignAt();
    if (at != null) _checkin.lastSignAt = DateTime.tryParse(at);
    _checkin.checkinLogs = _repo.loadCheckinLogs();
    _reply.loadPersisted(_repo);
    _reply.syncQueue(settings);
    await _session.restoreSession();
    booting = false;
    notifyListeners();
    if (user != null) {
      if (settings.autoSign) unawaited(autoSignIfNeeded());
      unawaited(_checkin.ensureBackgroundCheckin());
    }
  }

  // ------------------------------------------------------------ 登录

  Future<LoginResult> login(
    String username,
    String password, {
    int questionId = 0,
    String answer = '',
    bool remember = true,
  }) async {
    final res = await _session.login(
      username,
      password,
      questionId: questionId,
      answer: answer,
    );
    if (!res.success) return res;
    settings.rememberPassword = remember;
    settings.savedUsername = remember ? username : '';
    settings.savedPassword = remember ? password : '';
    await _saveSettings();
    unawaited(_checkin.ensureBackgroundCheckin());
    unawaited(autoSignIfNeeded());
    return res;
  }

  Future<void> refreshUser() => _session.refreshUser();

  Future<void> logout() async {
    _checkin.clearOnLogout();
    await _session.logout();
    notifyListeners();
  }

  // ------------------------------------------------------------ 签到

  Future<SignResult> signNow() => _checkin.signNow(user);
  Future<void> loadSignStatus() => _checkin.loadSignStatus(user);
  Future<SignResult?> autoSignIfNeeded({bool force = false}) =>
      _checkin.autoSignIfNeeded(user, settings, force: force);

  // ------------------------------------------------------------ 自动回复

  bool shouldAutoReply(ThreadDetail d) =>
      _reply.shouldAutoReply(d, settings, user);
  Future<ReplyResult?> maybeAutoReply(ThreadDetail d) =>
      _reply.maybeAutoReply(d, settings, user);
  Future<ReplyResult> manualReply(ThreadDetail d, String message) =>
      _reply.manualReply(d, message);
  bool hasReplied(int tid) => _reply.hasReplied(tid);
  Future<void> clearAutoReplyHistory() => _reply.clearAutoReplyHistory();
  Future<void> updateReplyPresets(List<String> presets) async {
    await updateSettings((s) {
      final seen = <String>{};
      final out = <String>[];
      for (final raw in presets) {
        final t = raw.trim();
        if (t.isEmpty || seen.contains(t)) continue;
        seen.add(t);
        out.add(t);
        if (out.length >= Preset.maxCount) break;
      }
      s.replyPresets =
          out.isEmpty ? List<String>.of(AppSettings.defaultReplyPresets) : out;
      s.replyContent = s.replyPresets.first;
    });
    _reply.syncQueue(settings);
  }

  // ------------------------------------------------------------ 设置

  Future<void> updateSettings(void Function(AppSettings s) mutate) async {
    mutate(settings);
    _reply.syncQueue(settings);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async =>
      updateSettings((s) => s.themeMode = mode);
  Future<void> setReplyPresets(List<String> presets) => updateReplyPresets(presets);

  // ------------------------------------------------------------ 收藏版块

  bool isFavoriteBoard(int fid) => settings.favoriteFids.contains(fid);
  Future<void> toggleFavoriteBoard(int fid) async {
    await updateSettings((s) {
      final list = List<int>.of(s.favoriteFids);
      list.contains(fid) ? list.remove(fid) : list.add(fid);
      s.favoriteFids = list;
    });
  }

  // ------------------------------------------------------------ 站点域名

  Future<String> switchSite(String siteId) async {
    final origin = await _site.switchSite(siteId, settings.siteId);
    settings.siteId = ForumSite.byId(siteId).id;
    await _saveSettings();
    notifyListeners();
    return origin;
  }

  Future<(int, bool)> probeSite(ForumSite site) async {
    final sw = Stopwatch()..start();
    final probe = DiscuzClient();
    try {
      final r = await probe.get('${site.origin}forum.php');
      sw.stop();
      return (sw.elapsedMilliseconds, r.statusCode == 200 && r.body.isNotEmpty);
    } catch (_) {
      sw.stop();
      return (sw.elapsedMilliseconds, false);
    } finally {
      probe.close();
    }
  }

  // ------------------------------------------------------------ 剪贴板识别

  bool shouldPromptClipboard(String url) =>
      settings.clipboardDetect && url.isNotEmpty && url != _clipboardSeen;
  Future<void> markClipboardPrompted(String url) async {
    _clipboardSeen = url;
    await _repo.setClipboardSeen(url);
  }

  // ------------------------------------------------------------ 购买主题

  Future<BuyResult> buyThread(ThreadDetail d) => api.buyThread(d);

  Future<void> _saveSettings() async {
    await _repo.saveSettingsJson(settings.toJson());
  }

  @override
  void dispose() {
    previews.dispose();
    client.close();
    super.dispose();
  }
}
