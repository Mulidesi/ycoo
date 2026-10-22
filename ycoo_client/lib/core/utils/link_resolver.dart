/// 链接解析：判断是否为站内链接、是否可在应用内打开。
library;

import '../network/site_config.dart';

/// 应用内可打开的目标类型。
enum InAppTargetKind {
  /// 帖子详情。
  thread,

  /// 版块列表。
  forum,

  /// 用户个人中心。
  user,
}

/// 应用内跳转目标。
class InAppTarget {
  const InAppTarget({required this.kind, required this.id});

  final InAppTargetKind kind;

  /// tid 或 fid。
  final int id;

  @override
  String toString() => 'InAppTarget($kind, $id)';
}

/// 链接解析工具。
abstract final class LinkResolver {
  static final RegExp _tidRe = RegExp(r'(?:tid=|thread-(\d+))');
  static final RegExp _fidRe = RegExp(r'(?:fid=|forum-(\d+))');

  /// 是否属于当前站点。
  static bool isSameSite(Uri url, ForumSite site) {
    final Uri base = site.baseUrl;
    return url.host == base.host;
  }

  /// 解析应用内目标；不是站内帖 / 版块时返回 null。
  static InAppTarget? resolveInAppTarget(Uri url, ForumSite site) {
    if (!isSameSite(url, site)) return null;

    final String path = url.path;
    final String query = url.query;

    // 帖子：thread-{tid}-...html 或 ?tid= / mod=viewthread&tid=
    final RegExpMatch? pathThread = RegExp(r'thread-(\d+)').firstMatch(path);
    if (pathThread != null) {
      final int? tid = int.tryParse(pathThread.group(1)!);
      if (tid != null) return InAppTarget(kind: InAppTargetKind.thread, id: tid);
    }
    final RegExpMatch? qThread = _tidRe.firstMatch(query);
    if (qThread != null) {
      final String raw = qThread.group(1) ?? qThread.group(0)!.split('=')[1];
      final int? tid = int.tryParse(raw);
      if (tid != null) return InAppTarget(kind: InAppTargetKind.thread, id: tid);
    }
    if (query.contains('mod=viewthread')) {
      final RegExpMatch? m = RegExp(r'tid=(\d+)').firstMatch(query);
      if (m != null) {
        final int? tid = int.tryParse(m.group(1)!);
        if (tid != null) return InAppTarget(kind: InAppTargetKind.thread, id: tid);
      }
    }

    // 版块：forum-{fid}-...html 或 ?fid= / mod=forumdisplay&fid=
    final RegExpMatch? pathForum = RegExp(r'forum-(\d+)').firstMatch(path);
    if (pathForum != null) {
      final int? fid = int.tryParse(pathForum.group(1)!);
      if (fid != null) return InAppTarget(kind: InAppTargetKind.forum, id: fid);
    }
    final RegExpMatch? qForum = _fidRe.firstMatch(query);
    if (qForum != null) {
      final String raw = qForum.group(1) ?? qForum.group(0)!.split('=')[1];
      final int? fid = int.tryParse(raw);
      if (fid != null) return InAppTarget(kind: InAppTargetKind.forum, id: fid);
    }
    if (query.contains('mod=forumdisplay')) {
      final RegExpMatch? m = RegExp(r'fid=(\d+)').firstMatch(query);
      if (m != null) {
        final int? fid = int.tryParse(m.group(1)!);
        if (fid != null) return InAppTarget(kind: InAppTargetKind.forum, id: fid);
      }
    }

    final RegExpMatch? pathUser = RegExp(r'space-uid-(\d+)').firstMatch(path);
    if (pathUser != null) {
      final int? uid = int.tryParse(pathUser.group(1)!);
      if (uid != null && uid > 0) return InAppTarget(kind: InAppTargetKind.user, id: uid);
    }
    if (path.contains('home.php') || query.contains('mod=space')) {
      final RegExpMatch? m = RegExp(r'(?:^|&)uid=(\d+)').firstMatch(query);
      if (m != null) {
        final int? uid = int.tryParse(m.group(1)!);
        if (uid != null && uid > 0) return InAppTarget(kind: InAppTargetKind.user, id: uid);
      }
    }

    return null;
  }

  /// 从正文里提取的裸 URL 是否应优先在应用内打开。
  static bool shouldOpenInApp(String href, ForumSite site) {
    final Uri? uri = Uri.tryParse(href);
    if (uri == null) return false;
    return isSameSite(uri, site);
  }

  /// 从任意文本（剪贴板、分享语）中提取第一个论坛链接。
  ///
  /// 同时匹配两个已知域名；返回的 URL 保证带 scheme（`www.`/裸域名自动补 https）。
  /// 未找到论坛链接返回 null。
  static Uri? findForumUrlInText(String text) {
    if (text.isEmpty || text.length > 4096) return null;
    final RegExp re = RegExp(
      r'(?:https?://)?(?:www\.)?(ycoo\.net|pc\.sysbbs\.com)/[^\s<>"“”‘’]+',
      caseSensitive: false,
    );
    final m = re.firstMatch(text);
    if (m == null) return null;
    var raw = m.group(0)!;
    // 归一化：统一 https 并去掉 www. 前缀，保证与站点 origin 的 host 一致
    raw = raw.replaceFirst(RegExp(r'^(?:https?://)?(?:www\.)?', caseSensitive: false), 'https://');
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    // 域名命中但不是帖子 / 版块链接（如首页）也返回，调用方可按需打开首页
    return uri;
  }

  /// 在全部已知站点中解析应用内目标（正文链接可能属于任一域名）。
  static ({ForumSite site, InAppTarget target})? resolveInAnySite(Uri url) {
    for (final site in ForumSite.all) {
      if (!isSameSite(url, site)) continue;
      final target = resolveInAppTarget(url, site);
      if (target != null) return (site: site, target: target);
    }
    return null;
  }
}
