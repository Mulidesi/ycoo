import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

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
  return ShareOutcome(path: fileName, bytes: bytes);
}

Future<ShareOutcome> sharePngFile({
  required String path,
  required String fileName,
  String shareText = '',
  Uint8List? bytes,
}) async {
  final data = bytes;
  if (data == null || data.isEmpty) {
    return ShareOutcome(
      path: path,
      shared: false,
      hint: '当前环境无法调起分享，请长按保存图片',
    );
  }
  try {
    await Share.shareXFiles(
      [XFile.fromData(data, mimeType: 'image/png', name: fileName)],
      text: shareText,
    );
    return ShareOutcome(path: path, shared: true, hint: '已开始下载分享图片');
  } catch (_) {
    return ShareOutcome(
      path: path,
      shared: false,
      hint: '当前环境无法调起分享，请长按保存图片',
    );
  }
}
