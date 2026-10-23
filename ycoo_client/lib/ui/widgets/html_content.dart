import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/navigation/in_app_nav.dart';
import '../../data/content.dart';
import '../../design/tokens.dart';
import 'net_image.dart';

/// 论坛正文渲染器。
///
/// 解析逻辑放在 `data/content.dart`（纯 Dart，可离线回归），
/// 这里只负责把内容块画出来：段落 / 图片 / 引用 / 代码 / 分隔线。
/// 链接统一用主色 + 下划线；论坛站内链接（ycoo.net / pc.sysbbs.com）
/// 点击直接在应用内打开帖子 / 版块，其余链接用外部浏览器、长按复制地址。
class PostContent extends StatefulWidget {
  const PostContent({
    super.key,
    required this.html,
    this.fontSize = 15.5,
    this.selectable = true,
    this.showLockedHint = false,
    this.maxImageHeight = 420,
    this.collapseQuotes = false,
  });

  final String html;
  final double fontSize;
  final bool selectable;

  /// 是否把「回复可见 / 购买可见 / 作者被屏蔽」提示直接渲染进正文
  final bool showLockedHint;

  /// 单张图片的最大高度（长截图不会把整屏撑满，点开可看原图）
  final double maxImageHeight;

  /// 折叠长引用（评论楼中楼观感）：超过 60 字的引用默认收起为单行预览。
  final bool collapseQuotes;

  @override
  State<PostContent> createState() => _PostContentState();
}

class _PostContentState extends State<PostContent> {
  /// 按 URL 复用识别器：build 里重复创建会泄漏手势对象
  final Map<String, TapGestureRecognizer> _taps = {};
  List<ContentBlock> _blocks = const [];

  /// 已展开的引用块索引（collapseQuotes 模式）
  final Set<int> _expandedQuotes = <int>{};

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(covariant PostContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html || oldWidget.showLockedHint != widget.showLockedHint) {
      _disposeRecognizers();
      _parse();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _taps.values) {
      r.dispose();
    }
    _taps.clear();
  }

  void _parse() {
    _blocks = parsePostContent(widget.html, showLockedHint: widget.showLockedHint);
    _expandedQuotes.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = YuanSemanticColors.of(context);
    final base = TextStyle(
      fontSize: widget.fontSize,
      height: 1.72,
      color: semantic.textPrimary,
    );

    if (_blocks.isEmpty) {
      return Text('（正文为空）', style: YuanType.bodySm.copyWith(color: semantic.textTertiary));
    }

    final children = <Widget>[];
    var quoteIndex = 0;
    for (final b in _blocks) {
      switch (b.kind) {
        case BlockKind.text:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: YuanSpace.xs),
            child: _text(b.runs, base, theme),
          ));
          break;
        case BlockKind.quote:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: YuanSpace.xs),
            child: _quote(b.runs, base, theme, quoteIndex),
          ));
          break;
        case BlockKind.code:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: YuanSpace.xs),
            child: _code(b.code, theme),
          ));
          break;
        case BlockKind.image:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: YuanSpace.xs),
            child: _image(b.imageUrl!, theme),
          ));
          break;
        case BlockKind.divider:
          children.add(const Padding(
            padding: EdgeInsets.symmetric(vertical: YuanSpace.xs),
            child: Divider(height: 1),
          ));
          break;
      }
      if (b.kind == BlockKind.quote) quoteIndex++;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  List<InlineSpan> _spans(List<InlineRun> runs, TextStyle base, ThemeData theme) {
    final semantic = YuanSemanticColors.of(context);
    final linkColor = semantic.brandPrimary;
    return [
      for (final r in runs)
        TextSpan(
          text: r.text,
          style: base.copyWith(
            fontWeight: r.bold ? FontWeight.w600 : null,
            fontStyle: r.italic ? FontStyle.italic : null,
            decoration: _decoration(r),
            decorationColor: r.href != null ? linkColor.withValues(alpha: 0.6) : null,
            color: r.color != null ? Color(r.color!) : (r.href != null ? linkColor : null),
            fontSize: r.fontSize,
          ),
          recognizer: r.href == null ? null : _tap(r.href!),
        ),
    ];
  }

  TextDecoration? _decoration(InlineRun r) {
    if (r.underline && r.strike) {
      return TextDecoration.combine([TextDecoration.underline, TextDecoration.lineThrough]);
    }
    if (r.underline || r.href != null) return TextDecoration.underline;
    if (r.strike) return TextDecoration.lineThrough;
    return null;
  }

  Widget _text(List<InlineRun> runs, TextStyle base, ThemeData theme) {
    final span = TextSpan(style: base, children: _spans(runs, base, theme));
    return widget.selectable
        ? SelectableText.rich(span, textAlign: TextAlign.start)
        : Text.rich(span, textAlign: TextAlign.start);
  }

  Widget _quote(List<InlineRun> runs, TextStyle base, ThemeData theme, int quoteIndex) {
    final semantic = YuanSemanticColors.of(context);
    final style = base.copyWith(fontSize: widget.fontSize - 1, color: semantic.textSecondary);

    // 楼中楼观感：长引用默认折叠为单行预览，点击展开 / 收起
    final plain = runs.map((r) => r.text).join().trim();
    final collapsible = widget.collapseQuotes && plain.length > 60;
    if (collapsible && !_expandedQuotes.contains(quoteIndex)) {
      final preview = plain.replaceAll(RegExp(r'\s+'), ' ');
      return InkWell(
        onTap: () => setState(() => _expandedQuotes.add(quoteIndex)),
        borderRadius: BorderRadius.circular(YuanRadius.xs),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.fromLTRB(YuanSpace.sm, 8, YuanSpace.sm, 8),
          decoration: BoxDecoration(
            color: semantic.surfaceComment,
            borderRadius: BorderRadius.circular(YuanRadius.xs),
            border: Border(
              left: BorderSide(color: semantic.outlineSubtle, width: YuanSizes.replyRailWidth),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '引用：$preview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.expand_more_rounded, size: 16, color: semantic.textTertiary),
            ],
          ),
        ),
      );
    }

    final quoteBody = SelectableText.rich(TextSpan(style: style, children: _spans(runs, style, theme)));
    if (!collapsible) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.fromLTRB(YuanSpace.sm, 10, YuanSpace.sm, 10),
        decoration: BoxDecoration(
          color: semantic.surfaceComment,
          borderRadius: BorderRadius.circular(YuanRadius.xs),
          border: Border(left: BorderSide(color: semantic.outlineSubtle, width: YuanSizes.replyRailWidth)),
        ),
        child: quoteBody,
      );
    }

    // 展开状态：顶部加收起按钮
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.fromLTRB(YuanSpace.sm, 8, YuanSpace.sm, 10),
      decoration: BoxDecoration(
        color: semantic.surfaceComment,
        borderRadius: BorderRadius.circular(YuanRadius.xs),
        border: Border(left: BorderSide(color: semantic.outlineSubtle, width: YuanSizes.replyRailWidth)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => setState(() => _expandedQuotes.remove(quoteIndex)),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.expand_less_rounded, size: 15, color: semantic.textTertiary),
                    const SizedBox(width: 2),
                    Text('收起引用', style: YuanType.caption.copyWith(color: semantic.textTertiary)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          quoteBody,
        ],
      ),
    );
  }

  Widget _code(String text, ThemeData theme) {
    final semantic = YuanSemanticColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(YuanSpace.sm),
      decoration: BoxDecoration(
        color: semantic.surfaceContainer,
        borderRadius: BorderRadius.circular(YuanRadius.xs),
      ),
      child: SelectableText(
        text,
        style: YuanType.bodySm.copyWith(fontFamily: 'monospace', height: 1.5),
      ),
    );
  }

  Widget _image(String url, ThemeData theme) {
    final semantic = YuanSemanticColors.of(context);
    return GestureDetector(
      onTap: () => _preview(url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(YuanRadius.xs),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: widget.maxImageHeight),
          decoration: BoxDecoration(
            color: semantic.surfaceContainer,
            borderRadius: BorderRadius.circular(YuanRadius.xs),
          ),
          child: NetImage(
            url: url,
            width: double.infinity,
            fit: BoxFit.contain,
            placeholderBuilder: (c) => const SizedBox(
              height: 150,
              child: Center(
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
            errorBuilder: (c) => Container(
              height: 120,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined, size: 22, color: semantic.textTertiary),
                  const SizedBox(height: 6),
                  Text(
                    '图片加载失败，点此重试',
                    style: YuanType.label.copyWith(color: semantic.textTertiary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TapGestureRecognizer _tap(String url) {
    return _taps.putIfAbsent(url, () {
      return TapGestureRecognizer()..onTap = (() => _open(url));
    });
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    // 论坛站内链接：帖子 / 版块直接应用内打开，无需外部浏览器
    if (openInAppIfInternal(context, url)) return;

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _copyLink(url, hint: '无法打开，链接已复制');
    } catch (_) {
      if (mounted) _copyLink(url, hint: '无法打开，链接已复制');
    }
  }

  Future<void> _copyLink(String url, {String hint = '链接已复制'}) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(hint), duration: const Duration(milliseconds: 1200)),
    );
  }

  void _preview(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (c) => Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: NetImage(url: url, fit: BoxFit.contain, showRetry: true),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton.filledTonal(
              onPressed: () => Navigator.of(c).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}
