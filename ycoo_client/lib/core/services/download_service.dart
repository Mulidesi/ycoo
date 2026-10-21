/// 附件下载：目标目录、文件名策略与流式下载。
///
/// Android 保存到公共下载目录 `/storage/emulated/0/Download/`；
/// 其它平台保存到应用文档目录。需要存储权限时先申请。
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 下载路径策略。
abstract final class DownloadPaths {
  /// Android 公共下载目录（用户可见的 `Download/`）。
  static const String androidPublicDownload = '/storage/emulated/0/Download/';

  /// 解析目标目录。Android 返回公共下载目录，其它平台返回 null（由调用方回落）。
  static String? resolveForPlatform(String platform) {
    if (platform == 'android') return androidPublicDownload;
    return null;
  }

  /// 回落目录：公共 Download 不可写（Android 10+ scoped storage）时使用。
  ///
  /// Android 用应用专属外部目录（无需权限，文件管理器可见），
  /// 其它平台用系统文档目录。
  static Future<String> fallbackAppDir() async {
    if (Platform.isAndroid) {
      try {
        final Directory? d = await getExternalStorageDirectory();
        if (d != null) {
          final Directory target = Directory('${d.path}/Download');
          if (!await target.exists()) await target.create(recursive: true);
          return target.path;
        }
      } catch (_) {}
    }
    try {
      final Directory d = await getApplicationDocumentsDirectory();
      final Directory target = Directory('${d.path}/downloads');
      if (!await target.exists()) await target.create(recursive: true);
      return target.path;
    } catch (_) {
      return Directory.systemTemp.path;
    }
  }
}

/// 文件名策略。
abstract final class FileNamePolicy {
  static final RegExp _unsafeChars = RegExp(r'[\\/:*?"<>|\r\n\t]');

  /// 清洗文件名中的非法字符。
  static String sanitize(String name) {
    final String cleaned = name.replaceAll(_unsafeChars, '_').trim();
    if (cleaned.isEmpty) return 'download';
    return cleaned.length > 120 ? cleaned.substring(0, 120) : cleaned;
  }

  /// 从 `Content-Disposition` 头解析文件名（支持 RFC 5987 `filename*=`）。
  ///
  /// 解析失败时回落到 [fallback]，**始终返回非空**。
  static String fromContentDisposition(String? header, {required String fallback}) {
    if (header == null || header.isEmpty) return sanitize(fallback);

    // filename*=UTF-8''%E4%B8%AD%E6%96%87.jpg
    final RegExpMatch? extended =
        RegExp(r"filename\*\s*=\s*[^']*''([^;]+)", caseSensitive: false)
            .firstMatch(header);
    if (extended != null) {
      final String raw = extended.group(1)!.trim();
      try {
        return sanitize(Uri.decodeComponent(raw));
      } catch (_) {
        return sanitize(raw);
      }
    }

    // filename="xxx.jpg" 或 filename=xxx.jpg
    final RegExpMatch? plain =
        RegExp(r'filename\s*=\s*"?([^";]+)"?', caseSensitive: false)
            .firstMatch(header);
    if (plain != null) {
      return sanitize(plain.group(1)!.trim());
    }
    return sanitize(fallback);
  }
}

/// 下载服务接口。
abstract interface class DownloadService {
  /// 目标目录。
  Future<String> resolveTargetDirectory();

  /// 下载到 [targetDir]，返回落盘文件路径。
  Future<String> download({
    required Uri url,
    required String targetDir,
    required String suggestedName,
    Map<String, String> headers = const <String, String>{},
    void Function(int received, int? total)? onProgress,
  });
}

/// 基于 `dart:io` 的实现（Android / iOS / 桌面）。
class IoDownloadService implements DownloadService {
  const IoDownloadService({this.clientFactory});

  /// 可注入的 HttpClient 工厂（测试用）。
  final HttpClient Function()? clientFactory;

  HttpClient _newClient() {
    final HttpClient c = clientFactory?.call() ?? HttpClient();
    c.connectionTimeout = const Duration(seconds: 20);
    return c;
  }

  @override
  Future<String> resolveTargetDirectory() async {
    if (Platform.isAndroid) {
      final Directory dir = Directory(DownloadPaths.androidPublicDownload);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    }
    // 非 Android：用系统临时目录下的 downloads 子目录，保证可写。
    final Directory dir = Directory('${Directory.systemTemp.path}/downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  @override
  Future<String> download({
    required Uri url,
    required String targetDir,
    required String suggestedName,
    Map<String, String> headers = const <String, String>{},
    void Function(int received, int? total)? onProgress,
  }) async {
    final HttpClient client = _newClient();
    try {
      final HttpClientRequest req = await client.getUrl(url);
      headers.forEach(req.headers.set);
      final HttpClientResponse res = await req.close();

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HttpException('HTTP ${res.statusCode}', uri: url);
      }

      final String name = FileNamePolicy.fromContentDisposition(
        res.headers.value('content-disposition'),
        fallback: suggestedName,
      );
      final String safe = FileNamePolicy.sanitize(name);

      final Directory dir = Directory(targetDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final File file = File('${dir.path}/$safe');
      final IOSink sink = file.openWrite();
      var received = 0;
      final int? total = res.contentLength >= 0 ? res.contentLength : null;
      await for (final List<int> chunk in res) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      return file.path;
    } finally {
      client.close(force: true);
    }
  }
}
