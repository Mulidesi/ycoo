/// 按 host 分桶维护的 Cookie 存储。
///
/// Discuz 的会话完全依赖 Cookie（形如 `YPSa_2132_auth`），
/// 这里提供纯内存实现供 [DiscuzClient] 使用；
/// 持久化层由 AppState 负责写入 shared_preferences / SecureStore。
library;

class CookieStore {
  final Map<String, Map<String, String>> _buckets = {};

  static String normalizeHost(String host) {
    return host.toLowerCase();
  }

  Map<String, String> snapshot(String host) {
    return Map<String, String>.from(_buckets[normalizeHost(host)] ?? {});
  }

  bool hasSession(String host) {
    final cookies = _buckets[normalizeHost(host)] ?? {};
    return cookies.isNotEmpty;
  }

  String? headerFor(String host) {
    final cookies = _buckets[normalizeHost(host)] ?? {};
    if (cookies.isEmpty) return null;
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  void load(String host, Map<String, String> cookies) {
    _buckets[normalizeHost(host)] = Map<String, String>.from(cookies);
  }

  void clear(String host) {
    _buckets.remove(normalizeHost(host));
  }

  void absorb(String host, String? setCookieHeader) {
    if (setCookieHeader == null || setCookieHeader.isEmpty) return;
    final key = normalizeHost(host);
    final bucket = _buckets.putIfAbsent(key, () => <String, String>{});
    for (final pair in setCookieHeader.split(';')) {
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final name = pair.substring(0, eq).trim();
      final value = pair.substring(eq + 1).trim();
      if (name.isEmpty) continue;
      bucket[name] = value;
    }
  }
}
