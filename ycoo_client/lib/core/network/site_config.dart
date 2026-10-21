/// 站点配置与能力位。
///
/// 客户端当前以 **ycoo.net** 为主站点（单站点运行），
/// 保留 `ForumSite` 抽象以便后续接入第二个 Discuz 站点。
/// 业务层只依赖 `ForumSite`，不硬编码域名。
library;

import 'package:flutter/foundation.dart';

/// 站点能力位：UI 据此决定入口是否出现。
@immutable
class SiteCapability {
  const SiteCapability({
    this.payThread = false,
    this.checkin = false,
    this.commentFloor = false,
    this.hotTopic = false,
    this.extCreditsNamed = false,
    this.attachments = true,
    this.mobileJson = false,
  });

  /// 支持应用内购买主题。
  final bool payThread;

  /// 支持签到插件。
  final bool checkin;

  /// 支持楼中楼评论。
  final bool commentFloor;

  /// 有独立热门话题模块。
  final bool hotTopic;

  /// 扩展积分有独立名称（星币 / 经验 / 贡献）。
  final bool extCreditsNamed;

  /// 支持附件下载。
  final bool attachments;

  /// 是否开放 Discuz 移动端 JSON 接口（列表首图 / 摘要）。
  final bool mobileJson;

  static const unknown = SiteCapability();

  SiteCapability copyWith({
    bool? payThread,
    bool? checkin,
    bool? commentFloor,
    bool? hotTopic,
    bool? extCreditsNamed,
    bool? attachments,
    bool? mobileJson,
  }) {
    return SiteCapability(
      payThread: payThread ?? this.payThread,
      checkin: checkin ?? this.checkin,
      commentFloor: commentFloor ?? this.commentFloor,
      hotTopic: hotTopic ?? this.hotTopic,
      extCreditsNamed: extCreditsNamed ?? this.extCreditsNamed,
      attachments: attachments ?? this.attachments,
      mobileJson: mobileJson ?? this.mobileJson,
    );
  }
}

/// 站点定义。
@immutable
class ForumSite {
  const ForumSite({
    required this.id,
    required this.name,
    required this.origin,
    required this.mobileHint,
    this.capability = const SiteCapability(),
  });

  final String id;
  final String name;

  /// 站点根地址，例如 `https://ycoo.net/`。
  final String origin;

  /// 是否提示使用移动版页面。
  final bool mobileHint;

  final SiteCapability capability;

  Uri get baseUrl => Uri.parse(origin);

  /// ycoo.net —— 本项目主站点。
  ///
  /// 能力位由真实探测结果确定：签到插件 `k_misign` 可用、
  /// 移动端 JSON 接口 `api/mobile/index.php` 可用（列表首图 / 摘要）。
  static const ycoo = ForumSite(
    id: 'ycoo',
    name: '源论坛',
    origin: 'https://ycoo.net/',
    mobileHint: false,
    capability: SiteCapability(
      payThread: true,
      checkin: true,
      commentFloor: true,
      hotTopic: false,
      extCreditsNamed: true,
      attachments: true,
      mobileJson: true,
    ),
  );

  /// 预留：Discuz 兼容站点（结构相同，域名不同）。
  ///
  /// ycoo.net 主域名不可用或较慢时，用户可在设置里切换到此域名；
  /// 访问测试在「我的 → 站点与网络」中执行。
  static const sysbbs = ForumSite(
    id: 'sysbbs',
    name: '源论坛 Sysbbs',
    origin: 'https://pc.sysbbs.com/',
    mobileHint: false,
    capability: SiteCapability(
      payThread: true,
      checkin: true,
      commentFloor: true,
      hotTopic: false,
      extCreditsNamed: true,
      attachments: true,
      mobileJson: false,
    ),
  );

  static const all = <ForumSite>[ycoo, sysbbs];

  static ForumSite byId(String id) {
    return all.firstWhere((ForumSite s) => s.id == id, orElse: () => ycoo);
  }

  /// 按主机名找站点（正文链接 / 剪贴板识别用）；两个域名都算站内。
  /// 忽略 `www.` 前缀差异。
  static ForumSite? byHost(String host) {
    final String h = host.replaceFirst(RegExp(r'^www\.'), '').toLowerCase();
    for (final ForumSite s in all) {
      if (s.baseUrl.host.toLowerCase() == h) return s;
    }
    return null;
  }

  /// 当前运行站点。
  static const current = ycoo;

  Uri resolve(String path, [Map<String, dynamic>? query]) {
    final Uri base = Uri.parse(origin);
    final Uri target = base.resolve(path);
    if (query == null || query.isEmpty) return target;
    return target.replace(
      queryParameters: <String, String>{
        ...target.queryParameters,
        for (final MapEntry<String, dynamic> e in query.entries) e.key: '${e.value}',
      },
    );
  }

  /// 是否为当前站点的内部帖子 / 版块链接。
  bool isInternalThreadUrl(Uri url) {
    if (url.host != Uri.parse(origin).host) return false;
    final String q = url.query;
    return q.contains('mod=viewthread') ||
        q.contains('mod=forumdisplay') ||
        url.path.contains('thread-') ||
        url.path.contains('forum-');
  }

  @override
  bool operator ==(Object other) => other is ForumSite && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
