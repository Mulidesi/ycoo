/// GitHub Release 更新元数据的解析与版本比较。
///
/// 这里保持纯 Dart（只依赖 dart:convert），便于离线单元测试。
library;

import 'dart:convert';

/// 更新来源仓库。
const updateRepoSlug = 'Mulidesi/ycoo';

/// 国内 GitHub 加速前缀：`前缀 + 原始 GitHub URL`。
const updateProxyPrefix = 'https://gproxy.mulides.cc.cd/';

/// 最新 Release 中随 APK 一起上传的元数据（稳定地址）。
const updateManifestUrl =
    'https://github.com/$updateRepoSlug/releases/latest/download/latest.json';

/// GitHub Releases API（元数据缺失时的兜底）。
const updateApiUrl =
    'https://api.github.com/repos/$updateRepoSlug/releases/latest';

/// 浏览器中打开的 Release 页面。
const updateReleasePageUrl =
    'https://github.com/$updateRepoSlug/releases/latest';

/// 一条可用的更新信息。
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.apkUrl,
    this.tag,
    this.size,
    this.sha256,
    this.notes = '',
    this.publishedAt,
    this.abi,
  });

  /// 纯版本号，如 `1.0.17`。
  final String version;
  final String apkUrl;
  final String? tag;
  final int? size;
  final String? sha256;
  final String notes;
  final String? publishedAt;
  final String? abi;

  String get displayTag => tag ?? 'v$version';

  /// 把 Release 说明里的 Markdown 标题 / 列表符号转成便于直接展示的文本。
  String get plainNotes => notes
      .split('\n')
      .map(
        (line) => line
            .replaceFirst(RegExp(r'^#{1,6}\s*'), '')
            .replaceFirst(RegExp(r'^[-*]\s+'), '• '),
      )
      .join('\n')
      .trim();

  String get apkFileName {
    final raw = apkUrl.split('/').last.split('?').first;
    final name = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return name.isEmpty ? 'ycoo-client-$version.apk' : name;
  }
}

/// 在原始 GitHub 地址前加上国内加速前缀；已带前缀时原样返回。
String proxiedUrl(String url) {
  if (url.startsWith(updateProxyPrefix)) return url;
  return '$updateProxyPrefix$url';
}

/// 把 `v1.0.17` / `1.0.17+18` 归一化为 `1.0.17`。
String normalizeVersion(String raw) {
  var v = raw.trim();
  if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
  final plus = v.indexOf('+');
  if (plus >= 0) v = v.substring(0, plus);
  return v;
}

int _versionPart(String part) {
  final digits = part.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(digits) ?? 0;
}

/// 比较两个版本号：a > b 返回正数，相等返回 0。
int compareVersions(String a, String b) {
  final left = normalizeVersion(a).split('.').map(_versionPart).toList();
  final right = normalizeVersion(b).split('.').map(_versionPart).toList();
  final len = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < len; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

/// [candidate] 是否比当前版本更新。
bool isNewerVersion(String candidate, String current) =>
    compareVersions(candidate, current) > 0;

/// 只接受 GitHub / 加速域名下的 HTTPS 安装包地址，避免元数据被篡改后
/// 诱导安装任意来源的 APK。
bool isSafeApkUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  const allowedHosts = {
    'github.com',
    'objects.githubusercontent.com',
    'gproxy.mulides.cc.cd',
  };
  return allowedHosts.contains(uri.host);
}

String? _readString(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

int? _readInt(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

ReleaseInfo? _fromMap(Map<dynamic, dynamic> map, String? targetAbi) {
  final version = normalizeVersion(
    _readString(map, const ['version', 'tag', 'tag_name']) ?? '',
  );

  // 优先从 apks 数组中挑选匹配当前 ABI 的安装包
  final apks = map['apks'];
  if (apks is List && apks.isNotEmpty) {
    for (final entry in apks) {
      if (entry is! Map) continue;
      final abi = _readString(entry, const ['abi']);
      if (abi != null && abi == targetAbi) {
        final url = _readString(entry, const ['url', 'apk_url', 'apkUrl']);
        if (url != null && isSafeApkUrl(url)) {
          return ReleaseInfo(
            version: version,
            apkUrl: url,
            tag: _readString(map, const ['tag', 'tag_name']),
            size: _readInt(entry, const ['size', 'apk_size', 'apkSize']),
            sha256: _readString(entry, const ['sha256', 'apk_sha256', 'apkSha256']),
            notes: _readString(map, const ['notes', 'body']) ?? '',
            publishedAt: _readString(map, const ['published_at', 'publishedAt']),
            abi: abi,
          );
        }
      }
    }
    // 未匹配到 ABI 时回退到 arm64-v8a（最常见）
    for (final entry in apks) {
      if (entry is! Map) continue;
      final abi = _readString(entry, const ['abi']);
      if (abi == 'arm64-v8a') {
        final url = _readString(entry, const ['url', 'apk_url', 'apkUrl']);
        if (url != null && isSafeApkUrl(url)) {
          return ReleaseInfo(
            version: version,
            apkUrl: url,
            tag: _readString(map, const ['tag', 'tag_name']),
            size: _readInt(entry, const ['size', 'apk_size', 'apkSize']),
            sha256: _readString(entry, const ['sha256', 'apk_sha256', 'apkSha256']),
            notes: _readString(map, const ['notes', 'body']) ?? '',
            publishedAt: _readString(map, const ['published_at', 'publishedAt']),
            abi: abi,
          );
        }
      }
    }
    // 最后回退到数组第一项
    final first = apks.first;
    if (first is Map) {
      final url = _readString(first, const ['url', 'apk_url', 'apkUrl']);
      if (url != null && isSafeApkUrl(url)) {
        return ReleaseInfo(
          version: version,
          apkUrl: url,
          tag: _readString(map, const ['tag', 'tag_name']),
          size: _readInt(first, const ['size', 'apk_size', 'apkSize']),
          sha256: _readString(first, const ['sha256', 'apk_sha256', 'apkSha256']),
          notes: _readString(map, const ['notes', 'body']) ?? '',
          publishedAt: _readString(map, const ['published_at', 'publishedAt']),
          abi: _readString(first, const ['abi']),
        );
      }
    }
  }

  final apkUrl = _readString(map, const ['apk_url', 'apkUrl', 'url']);
  if (version.isEmpty || apkUrl == null) return null;
  return ReleaseInfo(
    version: version,
    apkUrl: apkUrl,
    tag: _readString(map, const ['tag', 'tag_name']),
    size: _readInt(map, const ['size', 'apk_size', 'apkSize']),
    sha256: _readString(map, const ['sha256', 'apk_sha256', 'apkSha256']),
    notes: _readString(map, const ['notes', 'body']) ?? '',
    publishedAt: _readString(map, const ['published_at', 'publishedAt']),
  );
}

/// 解析随 Release 上传的 `latest.json`。
///
/// [targetAbi] 为空时使用默认回退策略（arm64-v8a → 第一项）。
ReleaseInfo? parseLatestManifest(String body, {String? targetAbi}) {
  final decoded = _tryDecode(body);
  if (decoded is! Map) return null;
  final info = _fromMap(decoded, targetAbi);
  if (info == null || !isSafeApkUrl(info.apkUrl)) return null;
  return info;
}

/// 解析 GitHub Releases API (`/releases/latest`) 的响应。
///
/// 当 [targetAbi] 非空时，优先挑选文件名中包含该 ABI 的 APK 资源。
ReleaseInfo? parseGitHubRelease(String body, {String? targetAbi}) {
  final decoded = _tryDecode(body);
  if (decoded is! Map) return null;
  final version = normalizeVersion(
    _readString(decoded, const ['tag_name', 'name']) ?? '',
  );
  if (version.isEmpty) return null;
  final assets = decoded['assets'];
  if (assets is! List) return null;

  if (targetAbi != null && targetAbi.isNotEmpty) {
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = _readString(asset, const ['name']) ?? '';
      if (!name.contains(targetAbi)) continue;
      final url = _readString(asset, const ['browser_download_url']);
      if (!name.toLowerCase().endsWith('.apk') || url == null) continue;
      if (!isSafeApkUrl(url)) continue;
      return ReleaseInfo(
        version: version,
        apkUrl: url,
        tag: _readString(decoded, const ['tag_name']),
        size: _readInt(asset, const ['size']),
        sha256: _readString(asset, const ['digest'])?.replaceFirst('sha256:', ''),
        notes: _readString(decoded, const ['body']) ?? '',
        publishedAt: _readString(decoded, const ['published_at']),
        abi: targetAbi,
      );
    }
  }

  for (final asset in assets) {
    if (asset is! Map) continue;
    final name = _readString(asset, const ['name']) ?? '';
    final url = _readString(asset, const ['browser_download_url']);
    if (!name.toLowerCase().endsWith('.apk') || url == null) continue;
    if (!isSafeApkUrl(url)) continue;
    return ReleaseInfo(
      version: version,
      apkUrl: url,
      tag: _readString(decoded, const ['tag_name']),
      size: _readInt(asset, const ['size']),
      sha256: _readString(asset, const ['digest'])?.replaceFirst('sha256:', ''),
      notes: _readString(decoded, const ['body']) ?? '',
      publishedAt: _readString(decoded, const ['published_at']),
    );
  }
  return null;
}

Object? _tryDecode(String body) {
  try {
    return const JsonDecoder().convert(body);
  } catch (_) {
    return null;
  }
}

/// 人类可读的字节数，如 `24.6 MB`。
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}
