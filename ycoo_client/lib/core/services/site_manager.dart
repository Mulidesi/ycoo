/// 站点切换编排：清理旧站状态 → 更新全局配置 → 通知 UI。
library;

import '../discuz_client.dart';
import '../image_loader.dart';
import '../network/site_config.dart';
import '../storage/settings_repository.dart';
import '../automation/background_checkin.dart' as bg;
import '../../data/parsers.dart' show setBaseUrl;
import 'checkin_service.dart';
import '../session/session_service.dart';

/// 站点切换编排服务。
class SiteManager {
  SiteManager({
    required this.client,
    required this.repo,
    required this.session,
    required this.checkin,
    required this.onChange,
  });

  final DiscuzClient client;
  final SettingsRepository repo;
  final SessionService session;
  final CheckinService checkin;

  /// 状态变化回调（通知 AppState → notifyListeners）。
  final void Function() onChange;

  /// 切换到另一个站点域名。
  Future<String> switchSite(String siteId, String currentSiteId) async {
    final target = ForumSite.byId(siteId);
    if (target.id == currentSiteId) return target.origin;
    setBaseUrl(target.origin);
    client.clearCookies();
    await repo.clearCookies();
    session.user = null;
    checkin.clearOnSwitchSite();
    clearAllImageCache();
    await bg.cancelBackgroundCheckin();
    onChange();
    return target.origin;
  }
}
