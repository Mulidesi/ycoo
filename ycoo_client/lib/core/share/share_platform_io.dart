import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../error/app_exception.dart';
import '../services/download_service.dart';

class ShareOutcome {
  const ShareOutcome({
    required this.path,
    this.shared = false,
    this.hint,
    this.bytes,
  });

  final String path;
  final bool shared;
  final String? hint;
  final Uint8List? bytes;
}

Future<ShareOutcome> persistPng({
  required Uint8List bytes,
  required String fileName,
  String shareText = '',
}) async {
  final dir = await _resolveDir();
  final file = File('${dir.path}/$fileName');
  try {
    await file.writeAsBytes(bytes, flush: true);
  } catch (e) {
    throw AppException.storage(message: '$e', cause: e);
  }
  return ShareOutcome(path: file.path, bytes: bytes);
}

Future<ShareOutcome> sharePngFile({
  required String path,
  required String fileName,
  String shareText = '',
  Uint8List? bytes,
}) async {
  try {
    await Share.shareXFiles(
      [XFile(path, mimeType: 'image/png', name: fileName)],
      text: shareText,
    );
    return ShareOutcome(path: path, shared: true);
  } catch (_) {
    return ShareOutcome(
      path: path,
      shared: false,
      hint: '已保存：$path',
    );
  }
}

Future<Directory> _resolveDir() async {
  if (Platform.isAndroid) {
    try {
      final public = Directory(DownloadPaths.androidPublicDownload);
      if (!await public.exists()) await public.create(recursive: true);
      final probe = File('${public.path}/.ycoo_share_probe');
      await probe.writeAsString('ok');
      await probe.delete();
      return public;
    } catch (_) {
      return Directory(await DownloadPaths.fallbackAppDir());
    }
  }
  try {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/share');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  } catch (_) {
    final dir = Directory('${Directory.systemTemp.path}/share');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
