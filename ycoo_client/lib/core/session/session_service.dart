/// 会话管理服务：登录 / 登出 / 用户信息 / Cookie 持久化。
library;

import '../discuz_client.dart';
import '../image_loader.dart';
import '../storage/settings_repository.dart';
import '../../data/forum_api.dart';
import '../../models/models.dart';

/// 会话管理服务。
class SessionService {
  SessionService({
    required this.client,
    required this.repo,
    required this.onChange,
  }) : api = ForumApi(client);

  final DiscuzClient client;
  final ForumApi api;
  final SettingsRepository repo;

  /// 状态变化回调（通知 AppState → notifyListeners）。
  final void Function() onChange;

  /// 当前登录用户。
  UserProfile? user;

  bool get loggedIn => user != null;

  Future<LoginResult> login(
    String username,
    String password, {
    int questionId = 0,
    String answer = '',
  }) async {
    final res = await api.login(
      username,
      password,
      questionId: questionId,
      answer: answer,
    );
    if (!res.success) return res;

    await repo.saveCookies(client.cookies);
    clearAllImageCache();
    try {
      user = await api.me();
    } catch (_) {
      user = null;
    }
    user ??= UserProfile(uid: 0, username: username);
    onChange();
    return res;
  }

  Future<void> logout() async {
    user = null;
    client.clearCookies();
    clearAllImageCache();
    await repo.clearCookies();
    onChange();
  }

  Future<void> refreshUser() async {
    if (!client.hasSession) return;
    try {
      final u = await api.me();
      if (u != null) {
        user = u;
        onChange();
      }
    } catch (_) {}
  }

  /// 从持久化 Cookie 恢复会话。
  Future<UserProfile?> restoreSession() async {
    final cookies = repo.loadCookies();
    if (cookies != null) {
      try {
        client.loadCookies(cookies);
      } catch (_) {}
    }
    if (client.hasSession) {
      try {
        user = await api.me();
      } catch (_) {
        user = null;
      }
    }
    return user;
  }
}
