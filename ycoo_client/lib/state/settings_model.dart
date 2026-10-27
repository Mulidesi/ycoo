/// 用户设置数据模型（纯数据，不依赖 Flutter）。
library;

import '../core/storage/automation_models.dart';

class AppSettings {
  bool autoSign;
  bool autoReply;

  /// 默认自动回复预设（首次启动 / 预设被清空时写入）。
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

  /// 是否按标题关键词过滤帖子（默认开启，过滤「打卡」类无效帖）。
  bool postFilterEnabled;

  /// 帖子标题过滤关键词；用户可在设置里增删，空列表表示不隐藏任何帖子。
  List<String> postFilterKeywords;

  /// 首次启动 / 旧版本升级时默认过滤的关键词。
  static const List<String> defaultPostFilterKeywords = <String>['打卡'];

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
    this.postFilterEnabled = true,
    List<String>? postFilterKeywords,
    this.dynamicColor = true,
  })  : replyPresets = _seedPresets(replyPresets),
        replyWhitelist = replyWhitelist ?? <int>{},
        favoriteFids = favoriteFids ?? <int>[],
        postFilterKeywords = postFilterKeywords == null
            ? List<String>.of(defaultPostFilterKeywords)
            : sanitizePostFilterKeywords(postFilterKeywords);

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

  static List<String> sanitizePostFilterKeywords(Iterable<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in raw) {
      final t = item.trim();
      if (t.isEmpty || t.length > 30) continue;
      final key = t.toLowerCase();
      if (!seen.add(key)) continue;
      out.add(t);
      if (out.length >= 50) break;
    }
    return out;
  }

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
        'postFilterEnabled': postFilterEnabled,
        'postFilterKeywords': postFilterKeywords,
        'dynamicColor': dynamicColor,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final List<dynamic>? rawPresets = j['replyPresets'] as List<dynamic>?;
    final String replyContent =
        (j['replyContent'] as String?)?.trim() ?? '';
    final List<String> presets;
    if (rawPresets == null || rawPresets.isEmpty) {
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
      favoriteFids:
          ((j['favoriteFids'] as List?) ?? []).map((e) => e as int).toList(),
      postFilterEnabled: j['postFilterEnabled'] as bool? ?? true,
      postFilterKeywords: (j['postFilterKeywords'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      dynamicColor: j['dynamicColor'] as bool? ?? true,
    );
  }
}

/// 生成 'YYYY-MM-DD' 日键（跨服务共享的日期格式化）。
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
