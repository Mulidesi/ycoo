/// 帖子分享长图：下载附件图 → 渲染 → 保存。系统分享由调用方在进度框关闭后发起。
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../data/content.dart';
import '../error/app_exception.dart';
import '../image_loader.dart';
import 'share_platform.dart';
import 'share_renderer.dart';

typedef SharePersist = Future<ShareOutcome> Function({
  required Uint8List bytes,
  required String fileName,
  String shareText,
});

class ShareImageService {
  ShareImageService({
    ShareRenderer? renderer,
    this.spec = const ShareImageSpec(),
    this.fetchBytes,
    this.persist,
  }) : renderer = renderer ?? ShareRenderer(spec: spec);

  final ShareRenderer renderer;
  final ShareImageSpec spec;
  final Future<Uint8List> Function(String url)? fetchBytes;
  final SharePersist? persist;

  Future<ShareOutcome> generateAndShare({
    required String title,
    required String author,
    String? authorAvatarUrl,
    String timeText = '',
    required List<ContentBlock> blocks,
    required String siteName,
    required String threadUrl,
    void Function(String phase, double progress)? onPhase,
  }) async {
    onPhase?.call('正在准备正文', 0.05);
    final header = ShareHeader(
      title: title,
      author: author,
      avatarUrl: authorAvatarUrl,
      timeText: timeText,
    );
    final footer = ShareFooter(siteName: siteName, threadUrl: threadUrl);
    final urls = collectShareImageUrls(blocks: blocks, avatarUrl: authorAvatarUrl);
    onPhase?.call('正在下载图片', 0.1);
    final fetcher = ShareImageFetcher(
      fetchBytes: fetchBytes ?? _defaultFetch,
      spec: spec,
    );
    final images = await fetcher.load(
      urls,
      onProgress: (p) => onPhase?.call('正在下载图片', 0.1 + p * 0.6),
    );
    onPhase?.call('正在生成分享图片', 0.75);
    ui.Image? image;
    try {
      image = await renderer.render(
        header: header,
        blocks: blocks,
        footer: footer,
        images: images,
        onProgress: (p) => onPhase?.call('正在生成分享图片', 0.75 + p * 0.15),
      );
      final bytes = await _encodePng(image);
      onPhase?.call('正在保存', 0.95);
      final persistFn = persist ?? persistPng;
      return persistFn(
        bytes: bytes,
        fileName: _fileName(title),
        shareText: '$title\n$threadUrl',
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException.from(e);
    } finally {
      image?.dispose();
      for (final img in images.values) {
        img?.dispose();
      }
    }
  }

  static Future<Uint8List> _defaultFetch(String url) {
    return DiscuzImageProvider(url).fetchBytes();
  }

  static Future<Uint8List> _encodePng(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw AppException.storage(message: '图片编码失败');
    }
    return data.buffer.asUint8List();
  }

  static String _fileName(String title) {
    final cleaned = FileNameSafe.sanitize(title);
    return 'ycoo-$cleaned.png';
  }
}

abstract final class FileNameSafe {
  static final _unsafe = RegExp(r'[\\/:*?"<>|\r\n\t]');

  static String sanitize(String name) {
    final cleaned = name.replaceAll(_unsafe, '_').trim();
    if (cleaned.isEmpty) return 'share';
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }
}
