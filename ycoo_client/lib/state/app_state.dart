/// 全局状态：登录态、签到、设置、自动回复配额。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/automation/auto_reply_queue.dart';
import '../core/automation/automation_engine.dart';
import '../core/automation/background_checkin.dart';
import '../core/automation/checkin_service.dart';
import '../core/discuz_client.dart';
import '../core/image_loader.dart';
import '../core/network/site_config.dart';
import '../core/storage/automation_models.dart';
import '../data/forum_api.dart';
import '../data/parsers.dart' show setBaseUrl;
import '../models/models.dart';
import 'preview_store.dart';

class AppSettings {
  bool autoSign;
  bool autoReply;

  /// 默认自动回复预设（首次启动 / 预设被清空时写入）。
  ///
  /// 都是通用致谢语，不含具体版块或资源指向，任何帖子下发都不违和；
  /// 条数取满 [Preset.maxCount]，随机取一时有足够差异。
  static const List<String> defaultReplyPresets = <String>[
    '感谢分享，感谢楼主！',
    '感谢楼主分享，先收藏了，慢慢研究。',
    '谢谢分享，正好需要，支持一下。',
    '楼主辛苦了，感谢分享好资源。',
    '路过支持一下，感谢楼主！',
  ];

  /// 兼容旧字段：首条预设正文。
  String replyContent;

  /// 自动回复预设（最多 5 条，随机取一）。
  List<String> replyPresets;

  int dailyReplyLimit;
  Set<int> replyWhitelist;
  bool rememberPassword;
  String savedUsername;
  String savedPassword;

  /// 外观：`system` / `light` / `dark`。
  String themeMode;

  /// 主站点 id：`ycoo` / `sysbbs`（域名可在设置里切换）。
  String siteId;

  /// 剪贴板论坛链接识别开关。
  bool clipboardDetect;

  /// 收藏的版块 fid（本地持久化）。
  List<int> favoriteFids;

  /// Material You 动态取色开关（Android 12+ 生效，其余平台忽略）。
  bool dynamicColor;

  AppSettings({
    this.autoSign = true,
    this.autoReply = true,
    this.replyContent = '感谢分享，感谢楼主！',
    List<String>? replyPresets,
    this.dailyReplyLimit = 20,
    Set<int>? replyWhitelist,
    this.rememberPassword = true,
    this.savedUsername = '',
    this.savedPassword = '',
    this.themeMode = 'system',
    this.siteId = 'ycoo',
    this.clipboardDetect = true,
    List<int>? favoriteFids,
    this.dynamicColor = true,
  })  : replyPresets = _seedPresets(replyPresets),
        replyWhitelist = replyWhitelist ?? <int>{},
        favoriteFids = favoriteFids ?? <int>[];

  /// 预设初始化：空列表（首次启动 / 老版本没有该字段 / 被清空）时补默认值，
  /// 保证自动回复任何时候都有内容可发。
  ///
  /// 老版本只写过一条内置默认语（`感谢分享，感谢楼主！`）的，也视为「没设置过」，
  /// 一并升级成整套默认预设。
  static List<String> _seedPresets(List<String>? presets) {
    if (presets == null) return List<String>.of(defaultReplyPresets);
    final List<String> cleaned = <String>[
      for (final String p in presets)
        if (p.trim().isNotEmpty) p.trim(),
    ];
    if (cleaned.isEmpty) return List<String>.of(defaultReplyPresets);
    if (cleaned.length == 1 && cleaned.first == defaultReplyPresets.first) {
      return List<String>.of(defaultReplyPresets);
    }
    return cleaned;
  }

  /// 归一化后的有效预设（去空、去重、限长、最多 5 条）。
  ///
  /// 全部无效时回退到默认预设 —— 自动回复不能处在「开着但没有内容」的状态。
  List<Preset> get effectivePresets {
    final List<Preset> out = _normalize(replyPresets);
    return out.isEmpty ? _normalize(defaultReplyPresets) : out;
  }

  List<Preset> _normalize(List<String> raw) {
    final Set<String> seen = <String>{};
    final List<Preset> out = <Preset>[];
    for (final String item in raw) {
      final String t = item.trim();
      if (t.isEmpty || seen.contains(t) || t.length > Preset.maxLength) continue;
      seen.add(t);
      out.add(Preset(text: t));
      if (out.length >= Preset.maxCount) break;
    }
    return out;
  }

  /// 兼容旧逻辑：首条有效预设正文。
  String get primaryReplyContent {
    final List<Preset> p = effectivePresets;
    return p.isEmpty ? replyContent : p.first.text;
  }

  Map<String, dynamic> toJson() => {
        'autoSign': autoSign,
        'autoReply': autoReply,
        'replyContent': replyContent,
        'replyPresets': replyPresets,
        'dailyReplyLimit': dailyReplyLimit,
        'replyWhitelist': replyWhitelist.toList(),
        'rememberPassword': rememberPassword,
        'savedUsername': savedUsername,
        'savedPassword': savedPassword,
        'themeMode': themeMode,
        'siteId': siteId,
        'clipboardDetect': clipboardDetect,
        'favoriteFids': favoriteFids,
        'dynamicColor': dynamicColor,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    // 兼容旧版本：早期只有单条 replyContent，后来才有 replyPresets
    final List<dynamic>? rawPresets = j['replyPresets'] as List<dynamic>?;
    final String replyContent =
        (j['replyContent'] as String?)?.trim() ?? '';
    final List<String> presets;
    if (rawPresets == null || rawPresets.isEmpty) {
      // 没改过回复内容（还是内置那句）或压根没有：直接用整套默认预设；
      // 自定义过的则保留用户那句话作为唯一预设
      presets = replyContent.isEmpty || replyContent == defaultReplyPresets.first
          ? <String>[]
          : <String>[replyContent];
    } else {
      presets = rawPresets.map((dynamic e) => e.toString()).toList();
    }
    return AppSettings(
      autoSign: j['autoSign'] as bool? ?? true,
      autoReply: j['autoReply'] as bool? ?? true,
      replyContent: replyContent.isEmpty ? defaultReplyPresets.first : replyContent,
      replyPresets: presets,
      dailyReplyLimit: j['dailyReplyLimit'] as int? ?? 20,
      replyWhitelist:
          ((j['replyWhitelist'] as List?) ?? []).map((e) => e as int).toSet(),
      rememberPassword: j['rememberPassword'] as bool? ?? true,
      savedUsername: j['savedUsername'] as String? ?? '',
      savedPassword: j['savedPassword'] as String? ?? '',
      themeMode: j['themeMode'] as String? ?? 'system',
      siteId: j['siteId'] as String? ?? 'ycoo',
      clipboardDetect: j['clipboardDetect'] as bool? ?? true,
      favoriteFids: ((j['favoriteFids'] as List?) ?? []).map((e) => e as int).toList(),
      dynamicColor: j['dynamicColor'] as bool? ?? true,
    );
  }
}

String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class AppState extends ChangeNotifier {
  /// [client] 仅用于测试注入（MockClient），生产环境走默认实现。
  AppState({DiscuzClient? client}) : client = client ?? DiscuzClient();

  static const _kCookies = 'cookies';
  static const _kSettings = 'settings';
  static const _kReplied = 'replied_tids';
  static const _kReplyCount = 'reply_count';
  static const _kLastSignDay = 'last_sign_day';
  static const _kLastSignAt = 'last_sign_at';
  static const _kReplyLogs = 'reply_logs';
  static const _kCheckinLogs = 'checkin_logs';
  static const _kClipboardSeen = 'clipboard_seen';

  final DiscuzClient client;
  late final ForumApi api = ForumApi(client);

  /// 列表卡片的首图 / 摘要缓存
  late final PreviewStore previews = PreviewStore(client);

  /// 自动回复引擎与队列（纯逻辑，可单测）
  final AutomationEngine automation = AutomationEngine();
  final AutoReplyQueue replyQueue = AutoReplyQueue();

  /// 最近自动回复日志（新→旧），最多 200 条
  List<AutoReplyLog> replyLogs = <AutoReplyLog>[];

  /// 最近签到日志，最多 100 条
  List<CheckinLog> checkinLogs = <CheckinLog>[];

  late SharedPreferences _prefs;
  AppSettings settings = AppSettings();

  UserProfile? user;
  SignStatus? signStatus;
  bool booting = true;
  bool signing = false;
  String? bootError;

  DateTime? lastSignAt;
  int lastAutoReplyCount = 0;

  final Set<int> _repliedTids = <int>{};
  final Set<int> _replyInFlight = <int>{};
  Map<String, int> _replyCounter = <String, int>{};

  bool get loggedIn => user != null;
  bool get hasAutoRepliedToday => _todayReplyCount() > 0;
  int get todayReplyCount => _todayReplyCount();

  /// 当前主站点（设置里可切换 ycoo / sysbbs 域名）。
  ForumSite get site => ForumSite.byId(settings.siteId);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // 图片加载复用同一份登录 Cookie（站内附件图需要登录态）
    DiscuzImageProvider.cookieProvider = () => client.cookieHeader;

    final rawCookies = _prefs.getString(_kCookies);
    if (rawCookies != null) {
      try {
        client.loadCookies((jsonDecode(rawCookies) as Map).cast<String, String>());
      } catch (_) {}
    }
    final rawSettings = _prefs.getString(_kSettings);
    if (rawSettings != null) {
      try {
        settings = AppSettings.fromJson((jsonDecode(rawSettings) as Map).cast<String, dynamic>());
      } catch (_) {}
    }
    // 主域名在请求发出之前生效（请求 / 解析 / 图片 Referer 都以 kBaseUrl 为准）
    setBaseUrl(site.origin);
    _clipboardSeen = _prefs.getString(_kClipboardSeen);
    _repliedTids
      ..clear()
      ..addAll(((jsonDecode(_prefs.getString(_kReplied) ?? '[]') as List)).map((e) => e as int));
    try {
      _replyCounter = (jsonDecode(_prefs.getString(_kReplyCount) ?? '{}') as Map)
          .map((k, v) => MapEntry(k.toString(), v as int));
    } catch (_) {}
    final at = _prefs.getString(_kLastSignAt);
    if (at != null) lastSignAt = DateTime.tryParse(at);

    // 自动化日志（自动回复 / 签到），旧版本无此键
    try {
      replyLogs = (jsonDecode(_prefs.getString(_kReplyLogs) ?? '[]') as List)
          .map((e) => AutoReplyLog.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {}
    try {
      checkinLogs = (jsonDecode(_prefs.getString(_kCheckinLogs) ?? '[]') as List)
          .map((e) => CheckinLog.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {}

    // 队列状态与设置同步
    replyQueue.setEnabled(settings.autoReply);
    replyQueue.setPresets(settings.effectivePresets);

    if (client.hasSession) {
      try {
        user = await api.me();
      } catch (e) {
        bootError = e.toString();
      }
    }
    booting = false;
    notifyListeners();

    if (user != null && settings.autoSign) {
      unawaited(autoSignIfNeeded());
    }
    // 已登录：确保后台周期签到已注册（Android only）
    if (user != null) {
      unawaited(_ensureBackgroundCheckin());
    }
  }

  /// 注册后台周期签到（仅 Android；iOS 后台限制不启用）。
  Future<void> _ensureBackgroundCheckin() async {
    if (!Platform.isAndroid) return;
    try {
      await registerBackgroundCheckin();
    } catch (_) {}
  }

  // ------------------------------------------------------------ 登录

  Future<LoginResult> login(
    String username,
    String password, {
    int questionId = 0,
    String answer = '',
    bool remember = true,
  }) async {
    final res = await api.login(username, password, questionId: questionId, answer: answer);
    if (!res.success) return res;

    await _persistCookies();
    _clearImageCache();
    try {
      user = await api.me();
    } catch (_) {
      user = null;
    }
    user ??= UserProfile(uid: 0, username: username);

    settings.rememberPassword = remember;
    settings.savedUsername = remember ? username : '';
    settings.savedPassword = remember ? password : '';
    await _saveSettings();
    notifyListeners();
    unawaited(_ensureBackgroundCheckin());
    unawaited(autoSignIfNeeded());
    return res;
  }

  Future<void> refreshUser() async {
    if (!client.hasSession) return;
    try {
      final u = await api.me();
      if (u != null) {
        user = u;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    user = null;
    signStatus = null;
    client.clearCookies();
    _clearImageCache();
    await _prefs.remove(_kCookies);
    // 取消后台周期签到
    if (Platform.isAndroid) {
      try {
        await cancelBackgroundCheckin();
      } catch (_) {}
    }
    notifyListeners();
  }

  /// 登录态变化后清空图片缓存：站内附件图在游客/会员下的可见性不同
  void _clearImageCache() {
    try {
      imageCache.clear();
      imageCache.clearLiveImages();
    } catch (_) {}
  }

  Future<void> _persistCookies() async {
    await _prefs.setString(_kCookies, jsonEncode(client.cookies));
  }

  // ------------------------------------------------------------ 签到

  Future<SignResult> signNow() async {
    if (user == null) return const SignResult(success: false, message: '请先登录');
    if (signing) return const SignResult(success: false, message: '正在签到，请稍候');
    signing = true;
    notifyListeners();
    try {
      final res = await api.sign();
      signStatus = await api.signStatus();
      if (res.success) {
        lastSignAt = DateTime.now();
        await _prefs.setString(_kLastSignDay, dayKey(DateTime.now()));
        await _prefs.setString(_kLastSignAt, lastSignAt!.toIso8601String());
      }
      await _recordCheckinLog(ok: res.success, message: res.message);
      return res;
    } catch (e) {
      await _recordCheckinLog(ok: false, message: e.toString());
      return SignResult(success: false, message: e.toString());
    } finally {
      signing = false;
      notifyListeners();
    }
  }

  Future<void> loadSignStatus() async {
    if (user == null) return;
    try {
      signStatus = await api.signStatus();
      notifyListeners();
    } catch (_) {}
  }

  /// 启动 / 恢复前台时调用；每天只成功执行一次
  Future<SignResult?> autoSignIfNeeded({bool force = false}) async {
    if (user == null || !settings.autoSign) return null;
    final today = dayKey(DateTime.now());
    // 当天已成功签到则跳过；也兼容按去重窗口判定（后台周期调用）
    if (!force &&
        (_prefs.getString(_kLastSignDay) == today ||
            CheckinScheduler.isDuplicate(logs: checkinLogs, now: DateTime.now()))) {
      return null;
    }
    try {
      final st = await api.signStatus();
      signStatus = st;
      notifyListeners();
      if (st.signedToday) {
        await _prefs.setString(_kLastSignDay, today);
        return const SignResult(success: true, message: '今天已签到');
      }
      final res = await api.sign();
      signStatus = await api.signStatus();
      if (res.success) {
        lastSignAt = DateTime.now();
        await _prefs.setString(_kLastSignDay, today);
        await _prefs.setString(_kLastSignAt, lastSignAt!.toIso8601String());
      }
      await _recordCheckinLog(ok: res.success, message: res.message);
      notifyListeners();
      return res;
    } catch (e) {
      await _recordCheckinLog(ok: false, message: e.toString());
      return SignResult(success: false, message: e.toString());
    }
  }

  // ------------------------------------------------------------ 自动回复

  /// 当前站点标识（单站点运行，固定为 ycoo）。
  static const String _siteId = 'ycoo';

  bool shouldAutoReply(ThreadDetail d) {
    if (!settings.autoReply || user == null) return false;
    if (!d.needsReply || d.fid == 0) return false;
    if (_repliedTids.contains(d.tid) || _replyInFlight.contains(d.tid)) return false;
    if (settings.replyWhitelist.isNotEmpty && !settings.replyWhitelist.contains(d.fid)) return false;
    return _todayReplyCount() < settings.dailyReplyLimit;
  }

  /// 隐藏贴自动回复：仅在用户真正打开帖子时触发。
  ///
  /// 预设从 [AutomationEngine] 随机取一条，支持 `{author}` / `{title}` 占位符；
  /// 随机延时 2.2–6 秒，按 tid 去重、按自然日限额，执行结果写入日志。
  Future<ReplyResult?> maybeAutoReply(ThreadDetail d) async {
    if (!shouldAutoReply(d)) return null;
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
      _recordReplyLog(tid: d.tid, text: message, ok: res.success, error: res.message);
      replyQueue.markProcessed(_siteId, d.tid, ok: res.success, text: message);

      if (res.success) {
        _repliedTids.add(d.tid);
        _bumpReplyCount();
        lastAutoReplyCount = todayReplyCount;
        await _saveReplied();
        notifyListeners();
      }
      return res;
    } catch (e) {
      return ReplyResult(success: false, message: e.toString());
    } finally {
      _replyInFlight.remove(d.tid);
    }
  }

  /// 记录一条自动回复日志（新→旧，最多 200 条）。
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
    _prefs.setString(
      _kReplyLogs,
      jsonEncode(replyLogs.map((AutoReplyLog l) => l.toJson()).toList()),
    );
  }

  /// 记录一条签到日志（新→旧，最多 100 条）。
  Future<void> _recordCheckinLog({required bool ok, String? message}) async {
    checkinLogs.insert(
      0,
      CheckinLog(at: DateTime.now(), success: ok, message: message),
    );
    if (checkinLogs.length > 100) {
      checkinLogs.removeRange(100, checkinLogs.length);
    }
    _prefs.setString(
      _kCheckinLogs,
      jsonEncode(checkinLogs.map((CheckinLog l) => l.toJson()).toList()),
    );
  }

  Future<ReplyResult> manualReply(ThreadDetail d, String message) async {
    final res = await api.reply(tid: d.tid, fid: d.fid, message: message);
    if (res.success) {
      _repliedTids.add(d.tid);
      _bumpReplyCount();
      await _saveReplied();
      notifyListeners();
    }
    return res;
  }

  bool hasReplied(int tid) => _repliedTids.contains(tid);

  int _todayReplyCount() => _replyCounter[dayKey(DateTime.now())] ?? 0;

  void _bumpReplyCount() {
    final k = dayKey(DateTime.now());
    _replyCounter = {..._replyCounter, k: (_replyCounter[k] ?? 0) + 1};
    _prefs.setString(_kReplyCount, jsonEncode(_replyCounter));
  }

  Future<void> _saveReplied() async {
    final list = _repliedTids.toList();
    if (list.length > 800) list.removeRange(0, list.length - 800);
    await _prefs.setString(_kReplied, jsonEncode(list));
  }

  Future<void> clearAutoReplyHistory() async {
    _repliedTids.clear();
    _replyCounter = {};
    replyLogs.clear();
    replyQueue.cancelAll();
    await _prefs.remove(_kReplied);
    await _prefs.remove(_kReplyCount);
    await _prefs.remove(_kReplyLogs);
    notifyListeners();
  }

  /// 更新自动回复预设（最多 5 条）。
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
      // 清空后不留「空预设」状态：回落到默认预设
      s.replyPresets =
          out.isEmpty ? List<String>.of(AppSettings.defaultReplyPresets) : out;
      s.replyContent = s.replyPresets.first;
    });
    replyQueue.setPresets(settings.effectivePresets);
  }

  // ------------------------------------------------------------ 设置

  Future<void> updateSettings(void Function(AppSettings s) mutate) async {
    mutate(settings);
    replyQueue.setEnabled(settings.autoReply);
    replyQueue.setPresets(settings.effectivePresets);
    await _saveSettings();
    notifyListeners();
  }

  /// 切换外观模式：`system` / `light` / `dark`。
  Future<void> setThemeMode(String mode) async {
    await updateSettings((s) => s.themeMode = mode);
  }

  /// 更新自动回复预设（对外别名，供「我的」页调用）。
  Future<void> setReplyPresets(List<String> presets) => updateReplyPresets(presets);

  // ------------------------------------------------------------ 收藏版块

  bool isFavoriteBoard(int fid) => settings.favoriteFids.contains(fid);

  /// 切换版块收藏（持久化）。
  Future<void> toggleFavoriteBoard(int fid) async {
    await updateSettings((s) {
      final list = List<int>.of(s.favoriteFids);
      if (list.contains(fid)) {
        list.remove(fid);
      } else {
        list.add(fid);
      }
      s.favoriteFids = list;
    });
  }

  // ------------------------------------------------------------ 站点域名

  /// 切换主域名（ycoo ↔ sysbbs）。
  ///
  /// Cookie 按域名隔离，切换后必须清空登录态，用户需在新域名重新登录；
  /// 图片缓存同样清空（附件图可见性 / 域名都变了）。
  Future<String> switchSite(String siteId) async {
    final target = ForumSite.byId(siteId);
    if (target.id == settings.siteId) return target.origin;
    await updateSettings((s) => s.siteId = target.id);
    setBaseUrl(target.origin);
    client.clearCookies();
    await _prefs.remove(_kCookies);
    user = null;
    signStatus = null;
    _clearImageCache();
    // 域名变了，旧域名的后台签到任务一并取消，登录后再注册
    if (Platform.isAndroid) {
      try {
        await cancelBackgroundCheckin();
      } catch (_) {}
    }
    notifyListeners();
    return target.origin;
  }

  /// 访问测试：请求站点首页，返回 (延迟 ms, 是否可用)。
  ///
  /// 用一次性客户端，避免把测试站点的 Cookie 吸进主会话。
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

  String? _clipboardSeen;

  /// 该剪贴板内容是否需要弹窗提示（与上次提示过的内容不同才提示）。
  bool shouldPromptClipboard(String url) =>
      settings.clipboardDetect && url.isNotEmpty && url != _clipboardSeen;

  /// 记录已提示过的剪贴板内容（无论用户选择打开与否，避免反复打扰）。
  Future<void> markClipboardPrompted(String url) async {
    _clipboardSeen = url;
    await _prefs.setString(_kClipboardSeen, url);
  }

  // ------------------------------------------------------------ 购买主题

  /// 应用内购买付费主题（详情页「购买」按钮调用）。
  Future<BuyResult> buyThread(ThreadDetail d) => api.buyThread(d);

  Future<void> _saveSettings() async {
    await _prefs.setString(_kSettings, jsonEncode(settings.toJson()));
  }

  @override
  void dispose() {
    previews.dispose();
    client.close();
    super.dispose();
  }
}
