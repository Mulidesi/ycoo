/// 帖子分享长图：dart:ui Canvas 绘制，不依赖 Flutter widget 树。
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../data/content.dart';

class ShareImageSpec {
  const ShareImageSpec({
    this.width = 1080,
    this.pixelRatio = 2,
    this.maxImages = 20,
    this.maxImageBytes = 4 * 1024 * 1024,
    this.maxConcurrent = 4,
    this.maxHeight = 8000,
    this.maxLines = 100,
    this.padding = 48,
  });

  final double width;
  final double pixelRatio;
  final int maxImages;
  final int maxImageBytes;
  final int maxConcurrent;
  final double maxHeight;
  final int maxLines;
  final double padding;
}

class ShareHeader {
  const ShareHeader({
    required this.title,
    required this.author,
    this.avatarUrl,
    this.timeText = '',
  });

  final String title;
  final String author;
  final String? avatarUrl;
  final String timeText;
}

class ShareFooter {
  const ShareFooter({
    required this.siteName,
    required this.threadUrl,
    this.appName = '源坛 App',
  });

  final String siteName;
  final String threadUrl;
  final String appName;
}

class ShareLayout {
  const ShareLayout({
    required this.width,
    required this.height,
    required this.truncated,
  });

  final double width;
  final double height;
  final bool truncated;
}

class ShareImageFetcher {
  ShareImageFetcher({
    required this.fetchBytes,
    this.spec = const ShareImageSpec(),
  });

  final Future<Uint8List> Function(String url) fetchBytes;
  final ShareImageSpec spec;

  Future<Map<String, ui.Image?>> load(
    List<String> urls, {
    void Function(double progress)? onProgress,
  }) async {
    final unique = <String>[];
    for (final u in urls) {
      if (u.isEmpty || unique.contains(u)) continue;
      unique.add(u);
      if (unique.length >= spec.maxImages) break;
    }
    final out = <String, ui.Image?>{};
    if (unique.isEmpty) return out;
    var done = 0;
    for (var i = 0; i < unique.length; i += spec.maxConcurrent) {
      final batch = unique.skip(i).take(spec.maxConcurrent).toList();
      final got = await Future.wait(batch.map(_one));
      for (var j = 0; j < batch.length; j++) {
        out[batch[j]] = got[j];
      }
      done += batch.length;
      onProgress?.call(done / unique.length);
    }
    return out;
  }

  Future<ui.Image?> _one(String url) async {
    try {
      final bytes = await fetchBytes(url);
      if (bytes.isEmpty || bytes.length > spec.maxImageBytes) return null;
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: (spec.width * spec.pixelRatio).round(),
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }
}

class ShareRenderer {
  ShareRenderer({this.spec = const ShareImageSpec()});

  final ShareImageSpec spec;

  static const _bg = ui.Color(0xFFFFFFFF);
  static const _title = ui.Color(0xFF1A1A1A);
  static const _body = ui.Color(0xFF1A1A1A);
  static const _muted = ui.Color(0xFF64748B);
  static const _quoteBg = ui.Color(0xFFF4F6FA);
  static const _quoteBar = ui.Color(0xFF2563EB);
  static const _codeBg = ui.Color(0xFFF3F4F6);
  static const _line = ui.Color(0xFFE2E8F0);
  static const _placeholder = ui.Color(0xFFE2E8F0);
  static const _avatarBg = ui.Color(0xFFDBEAFE);
  static const _avatarFg = ui.Color(0xFF1E40AF);
  static const _link = ui.Color(0xFF2563EB);

  ShareLayout computeLayout({
    required ShareHeader header,
    required List<ContentBlock> blocks,
    required ShareFooter footer,
    Map<String, ui.Image?> images = const {},
  }) {
    final built = _build(header, blocks, footer, images);
    return ShareLayout(
      width: spec.width,
      height: built.height,
      truncated: built.truncated,
    );
  }

  Future<ui.Image> render({
    required ShareHeader header,
    required List<ContentBlock> blocks,
    required ShareFooter footer,
    Map<String, ui.Image?> images = const {},
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.82);
    final built = _build(header, blocks, footer, images);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final pr = spec.pixelRatio;
    canvas.scale(pr);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, spec.width, built.height),
      ui.Paint()..color = _bg,
    );
    for (final seg in built.segments) {
      seg.paint(canvas, seg.y);
    }
    onProgress?.call(0.92);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (spec.width * pr).round(),
      (built.height * pr).round(),
    );
    picture.dispose();
    onProgress?.call(1);
    return image;
  }

  _Built _build(
    ShareHeader header,
    List<ContentBlock> blocks,
    ShareFooter footer,
    Map<String, ui.Image?> images,
  ) {
    final pad = spec.padding;
    final contentW = spec.width - pad * 2;
    final segs = <_Seg>[];
    var y = pad;
    var truncated = false;
    var lines = 0;

    final titleP = _paragraph(
      header.title.isEmpty ? '（无标题）' : header.title,
      _style(32, _title, weight: ui.FontWeight.w600, height: 1.35),
      contentW,
    );
    segs.add(_Seg(y, titleP.height, (c, top) {
      c.drawParagraph(titleP, ui.Offset(pad, top));
    }));
    y += titleP.height + 16;

    const avatar = 48.0;
    final authorP = _paragraph(
      header.author,
      _style(16, _title, weight: ui.FontWeight.w600, height: 1.25),
      contentW - avatar - 12,
      maxLines: 1,
    );
    final timeP = _paragraph(
      header.timeText,
      _style(13, _muted, height: 1.2),
      contentW - avatar - 12,
      maxLines: 1,
    );
    final avatarImg = _pick(images, header.avatarUrl);
    segs.add(_Seg(y, avatar, (c, top) {
      _drawAvatar(c, ui.Offset(pad, top), avatar, header.author, avatarImg);
      c.drawParagraph(authorP, ui.Offset(pad + avatar + 12, top + 4));
      c.drawParagraph(timeP, ui.Offset(pad + avatar + 12, top + 26));
    }));
    y += avatar + 24;
    segs.add(_Seg(y, 1, (c, top) {
      c.drawLine(
        ui.Offset(pad, top),
        ui.Offset(spec.width - pad, top),
        ui.Paint()
          ..color = _line
          ..strokeWidth = 1,
      );
    }));
    y += 24;

    final footerH = _footerHeight(footer, contentW);
    const hintH = 40.0;

    for (final block in blocks) {
      final seg = _blockSeg(block, images, contentW, pad);
      if (seg == null) continue;
      if (y + seg.height + footerH + hintH > spec.maxHeight ||
          lines + seg.lines > spec.maxLines) {
        truncated = true;
        break;
      }
      segs.add(_Seg(y, seg.height, seg.paint));
      y += seg.height;
      lines += seg.lines;
    }

    if (truncated) {
      final hint = _paragraph(
        '内容过长，仅展示部分内容',
        _style(14, _muted, height: 1.3),
        contentW,
      );
      segs.add(_Seg(y, hint.height + 8, (c, top) {
        c.drawParagraph(hint, ui.Offset(pad, top + 8));
      }));
      y += hint.height + 16;
    }

    y += 8;
    segs.add(_Seg(y, 1, (c, top) {
      c.drawLine(
        ui.Offset(pad, top),
        ui.Offset(spec.width - pad, top),
        ui.Paint()
          ..color = _line
          ..strokeWidth = 1,
      );
    }));
    y += 16;
    final siteP = _paragraph(
      '${footer.siteName}  ·  ${footer.appName}',
      _style(13, _muted, height: 1.3),
      contentW,
    );
    final urlP = _paragraph(
      footer.threadUrl,
      _style(12, _link, height: 1.3),
      contentW,
    );
    segs.add(_Seg(y, siteP.height, (c, top) {
      c.drawParagraph(siteP, ui.Offset(pad, top));
    }));
    y += siteP.height + 6;
    segs.add(_Seg(y, urlP.height, (c, top) {
      c.drawParagraph(urlP, ui.Offset(pad, top));
    }));
    y += urlP.height + pad;

    return _Built(height: y, truncated: truncated, segments: segs);
  }

  double _footerHeight(ShareFooter footer, double contentW) {
    final siteP = _paragraph(
      '${footer.siteName}  ·  ${footer.appName}',
      _style(13, _muted, height: 1.3),
      contentW,
    );
    final urlP = _paragraph(
      footer.threadUrl,
      _style(12, _link, height: 1.3),
      contentW,
    );
    final h = 8 + 1 + 16 + siteP.height + 6 + urlP.height + spec.padding;
    siteP.dispose();
    urlP.dispose();
    return h;
  }

  _Blk? _blockSeg(
    ContentBlock block,
    Map<String, ui.Image?> images,
    double contentW,
    double pad,
  ) {
    switch (block.kind) {
      case BlockKind.text:
        if (block.plainText.trim().isEmpty) return null;
        final p = _runsParagraph(block.runs, contentW, 16, _body);
        return _Blk(p.height + 14, p.computeLineMetrics().length, (c, top) {
          c.drawParagraph(p, ui.Offset(pad, top));
        });
      case BlockKind.quote:
        final p = _runsParagraph(block.runs, contentW - 28, 15, _muted);
        final h = p.height + 28;
        return _Blk(h, p.computeLineMetrics().length, (c, top) {
          final r = ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(pad, top, contentW, h - 12),
            const ui.Radius.circular(8),
          );
          c.drawRRect(r, ui.Paint()..color = _quoteBg);
          c.drawRect(
            ui.Rect.fromLTWH(pad, top, 4, h - 12),
            ui.Paint()..color = _quoteBar,
          );
          c.drawParagraph(p, ui.Offset(pad + 16, top + 8));
        });
      case BlockKind.code:
        final p = _paragraph(
          block.code,
          _style(14, _body, height: 1.45, family: 'monospace'),
          contentW - 24,
        );
        final h = p.height + 28;
        return _Blk(h, p.computeLineMetrics().length, (c, top) {
          final r = ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(pad, top, contentW, h - 12),
            const ui.Radius.circular(8),
          );
          c.drawRRect(r, ui.Paint()..color = _codeBg);
          c.drawParagraph(p, ui.Offset(pad + 12, top + 8));
        });
      case BlockKind.image:
        final img = _pick(images, block.imageUrl);
        if (img == null) {
          const h = 96.0;
          final label = _paragraph(
            '图片加载失败',
            _style(14, _muted, height: 1.2),
            contentW,
          );
          return _Blk(h + 12, 0, (c, top) {
            final r = ui.RRect.fromRectAndRadius(
              ui.Rect.fromLTWH(pad, top, contentW, h),
              const ui.Radius.circular(8),
            );
            c.drawRRect(r, ui.Paint()..color = _placeholder);
            c.drawParagraph(
              label,
              ui.Offset(
                pad + (contentW - label.maxIntrinsicWidth) / 2,
                top + 38,
              ),
            );
          });
        }
        var w = contentW;
        var h = img.height * w / img.width;
        if (h > 900) {
          h = 900;
          w = img.width * h / img.height;
        }
        final left = pad + (contentW - w) / 2;
        return _Blk(h + 16, 0, (c, top) {
          c.drawImageRect(
            img,
            ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            ui.Rect.fromLTWH(left, top, w, h),
            ui.Paint()..filterQuality = ui.FilterQuality.medium,
          );
        });
      case BlockKind.divider:
        return _Blk(17, 0, (c, top) {
          c.drawLine(
            ui.Offset(pad, top + 8),
            ui.Offset(pad + contentW, top + 8),
            ui.Paint()
              ..color = _line
              ..strokeWidth = 1,
          );
        });
    }
  }

  void _drawAvatar(
    ui.Canvas canvas,
    ui.Offset origin,
    double size,
    String name,
    ui.Image? image,
  ) {
    final rect = ui.Rect.fromLTWH(origin.dx, origin.dy, size, size);
    canvas.save();
    canvas.clipPath(ui.Path()..addOval(rect));
    if (image != null) {
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        rect,
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
    } else {
      canvas.drawRect(rect, ui.Paint()..color = _avatarBg);
      final ch = name.isEmpty ? '源' : name.substring(0, 1);
      final p = _paragraph(
        ch,
        _style(size * 0.4, _avatarFg, weight: ui.FontWeight.w600, height: 1),
        size,
      );
      canvas.drawParagraph(
        p,
        ui.Offset(
          origin.dx + (size - p.maxIntrinsicWidth) / 2,
          origin.dy + size * 0.28,
        ),
      );
    }
    canvas.restore();
  }

  ui.Image? _pick(Map<String, ui.Image?> images, String? url) {
    if (url == null || url.isEmpty) return null;
    return images[url];
  }

  ui.Paragraph _runsParagraph(
    List<InlineRun> runs,
    double maxWidth,
    double size,
    ui.Color color,
  ) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: ui.TextAlign.left, height: 1.6),
    );
    if (runs.isEmpty) {
      builder.pushStyle(_style(size, color, height: 1.6));
      builder.addText(' ');
    } else {
      for (final r in runs) {
        builder.pushStyle(_style(
          r.fontSize ?? size,
          r.color != null ? ui.Color(r.color!) : color,
          weight: r.bold ? ui.FontWeight.w600 : ui.FontWeight.normal,
          italic: r.italic,
          underline: r.underline,
          strike: r.strike,
          height: 1.6,
        ));
        builder.addText(r.text);
        builder.pop();
      }
    }
    final p = builder.build();
    p.layout(ui.ParagraphConstraints(width: maxWidth));
    return p;
  }

  ui.Paragraph _paragraph(
    String text,
    ui.TextStyle style,
    double maxWidth, {
    int? maxLines,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.left,
        maxLines: maxLines,
        ellipsis: maxLines == null ? null : '…',
      ),
    )
      ..pushStyle(style)
      ..addText(text.isEmpty ? ' ' : text);
    final p = builder.build();
    p.layout(ui.ParagraphConstraints(width: maxWidth));
    return p;
  }

  ui.TextStyle _style(
    double size,
    ui.Color color, {
    ui.FontWeight weight = ui.FontWeight.normal,
    bool italic = false,
    bool underline = false,
    bool strike = false,
    double height = 1.4,
    String? family,
  }) {
    ui.TextDecoration? deco;
    if (underline && strike) {
      deco = ui.TextDecoration.combine(const [
        ui.TextDecoration.underline,
        ui.TextDecoration.lineThrough,
      ]);
    } else if (underline) {
      deco = ui.TextDecoration.underline;
    } else if (strike) {
      deco = ui.TextDecoration.lineThrough;
    }
    return ui.TextStyle(
      color: color,
      fontSize: size,
      fontWeight: weight,
      fontStyle: italic ? ui.FontStyle.italic : ui.FontStyle.normal,
      decoration: deco,
      height: height,
      fontFamily: family,
    );
  }
}

class _Seg {
  _Seg(this.y, this.height, this.paint);
  final double y;
  final double height;
  final void Function(ui.Canvas canvas, double y) paint;
}

class _Blk {
  _Blk(this.height, this.lines, this.paint);
  final double height;
  final int lines;
  final void Function(ui.Canvas canvas, double y) paint;
}

class _Built {
  _Built({
    required this.height,
    required this.truncated,
    required this.segments,
  });
  final double height;
  final bool truncated;
  final List<_Seg> segments;
}

bool canShareThreadAsImage(String contentHtml) {
  if (contentHtml.contains('<img')) return true;
  return contentPlainText(
    parsePostContent(contentHtml, showLockedHint: false),
  ).trim().isNotEmpty;
}

List<String> collectShareImageUrls({
  required List<ContentBlock> blocks,
  String? avatarUrl,
}) {
  final urls = <String>[];
  if (avatarUrl != null && avatarUrl.isNotEmpty) urls.add(avatarUrl);
  for (final b in blocks) {
    final u = b.imageUrl;
    if (u != null && u.isNotEmpty) urls.add(u);
  }
  return urls;
}
