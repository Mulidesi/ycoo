/// 应用内导航注册器。
///
/// `html_content`（正文渲染）需要把站内链接跳到帖子 / 版块页，
/// 但直接 import 页面会形成循环依赖，因此页面在 main.dart 启动时
/// 把构建器注册进来，渲染层只依赖本文件与 link_resolver。
library;

import 'package:flutter/material.dart';

import '../utils/link_resolver.dart';
import '../network/site_config.dart';

typedef _TargetBuilder = Widget Function(int id);

/// 按目标类型注册的页面构建器（'thread' / 'forum'）。
final Map<InAppTargetKind, _TargetBuilder> _builders = {};

/// main.dart 启动时调用一次。
void registerInAppRoutes({
  required Widget Function(int tid) thread,
  required Widget Function(int fid) forum,
  Widget Function(int uid)? user,
}) {
  _builders[InAppTargetKind.thread] = thread;
  _builders[InAppTargetKind.forum] = forum;
  if (user != null) _builders[InAppTargetKind.user] = user;
}

/// URL 是否属于任一已知论坛域名，可解析出应用内目标则直接跳转。
/// 返回 true 表示已在应用内打开（或已注册路由并 push）。
bool openInAppIfInternal(BuildContext context, String url) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return false;
  final ForumSite? site = ForumSite.byHost(uri.host);
  if (site == null) return false;
  final InAppTarget? target = LinkResolver.resolveInAppTarget(uri, site);
  if (target == null) return false;
  final builder = _builders[target.kind];
  if (builder == null) return false;
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => builder(target.id)),
  );
  return true;
}
