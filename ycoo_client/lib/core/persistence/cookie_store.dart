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
    // Set-Cookie headers are joined with "," (no space) by the http package,
    // but `expires` dates contain ", " (comma+space). Splitting by ", " would
    // break on dates and lose cookies. Instead, match all name=value pairs
    // and skip known cookie attributes.
    final regex = RegExp(r'([^,;=\s]+)=([^,;]+?)(?=;|,|$)');
    for (final m in regex.allMatches(setCookieHeader)) {
      final name = m.group(1)!;
      final value = m.group(2)!.trim();
      if (name.isEmpty) continue;
      // Skip cookie attributes (expires, path, domain, secure, httponly, max-age, samesite)
      if ({'expires', 'path', 'domain', 'secure', 'httponly', 'max-age', 'samesite'}
          .contains(name.toLowerCase())) {
        continue;
      }
      bucket[name] = value;
    }
  }
}
