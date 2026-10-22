import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/update_manifest.dart';

class UpdateException implements Exception {
  UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 用户主动取消下载。
class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

/// 检查 GitHub Release 并下载 APK。
///
/// 元数据优先读取随 Release 上传的 `latest.json`，
/// 国内用户走 GitHub 加速线路，失败时自动回退直连。
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 20);

  List<String> _manifestCandidates() {
    // 带时间戳绕过 CDN / 加速线路的陈旧缓存
    final manifestUrl =
        '$updateManifestUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    return [
      proxiedUrl(manifestUrl),
      manifestUrl,
      updateApiUrl,
      proxiedUrl(updateApiUrl),
    ];
  }

  /// 拉取最新版本信息；全部线路失败时抛出 [UpdateException]。
  Future<ReleaseInfo> fetchLatest() async {
    Object? lastError;
    for (final url in _manifestCandidates()) {
      try {
        final res = await _client.get(
          Uri.parse(url),
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'ycoo-client',
          },
        ).timeout(_timeout);
        if (res.statusCode != 200) {
          throw UpdateException('HTTP ${res.statusCode}');
        }
        final body = _decodeBody(res);
        final isApi = Uri.parse(url).host == 'api.github.com';
        final info =
            isApi ? parseGitHubRelease(body) : parseLatestManifest(body);
        if (info == null) throw UpdateException('更新信息格式异常');
        return info;
      } catch (e) {
        lastError = e;
      }
    }
    throw UpdateException('检查更新失败：$lastError');
  }

  /// 下载 APK 到应用缓存目录，返回本地文件。
  ///
  /// 先走加速线路，再回退 GitHub 直连；提供 sha256 时校验完整性。
  Future<File> download(
    ReleaseInfo info, {
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    await dir.create(recursive: true);
    final file = File('${dir.path}/${info.apkFileName}');
    final candidates = [proxiedUrl(info.apkUrl), info.apkUrl];

    Object? lastError;
    for (final url in candidates) {
      try {
        await _downloadTo(
          url,
          file,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
        await _verify(file, info);
        return file;
      } on UpdateCancelled {
        await _deleteQuietly(file);
        rethrow;
      } catch (e) {
        lastError = e;
        await _deleteQuietly(file);
      }
    }
    throw UpdateException('下载失败：$lastError');
  }

  Future<void> _downloadTo(
    String url,
    File file, {
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    request.headers['User-Agent'] = 'ycoo-client';
    final response = await _client.send(request).timeout(_timeout);
    if (response.statusCode != 200) {
      throw UpdateException('HTTP ${response.statusCode}');
    }
    final total = response.contentLength != null && response.contentLength! > 0
        ? response.contentLength
        : null;
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream.timeout(_timeout)) {
        if (isCancelled?.call() == true) throw const UpdateCancelled();
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (received == 0) throw UpdateException('下载内容为空');
  }

  Future<void> _verify(File file, ReleaseInfo info) async {
    final length = await file.length();
    if (info.size != null && info.size! > 0 && length != info.size) {
      throw UpdateException('安装包大小不符（$length / ${info.size}）');
    }
    final expected = info.sha256?.toLowerCase();
    if (expected != null && expected.isNotEmpty) {
      final actual = (await sha256.bind(file.openRead()).first).toString();
      if (actual != expected) {
        throw UpdateException('安装包校验失败，请稍后重试');
      }
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 清理失败不影响主流程
    }
  }

  /// GitHub / 加速线路不一定返回 charset，`http.Response.body` 会按
  /// latin1 解码，中文说明就会变成乱码。优先用响应头里的编码，
  /// 没有声明时按 JSON 规范使用 UTF-8。
  static String _decodeBody(http.Response res) {
    final contentType = res.headers['content-type'] ?? '';
    final match = RegExp(r'charset\s*=\s*"?([^;"\s]+)', caseSensitive: false)
        .firstMatch(contentType);
    final declared = match == null ? null : Encoding.getByName(match.group(1)!);
    if (declared != null) {
      try {
        return declared.decode(res.bodyBytes);
      } catch (_) {
        // 声明与实际内容不符时继续按 UTF-8 尝试
      }
    }
    try {
      return utf8.decode(res.bodyBytes);
    } catch (_) {
      return latin1.decode(res.bodyBytes);
    }
  }

  void close() => _client.close();
}
