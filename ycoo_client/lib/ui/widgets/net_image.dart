import 'package:flutter/material.dart';

import '../../core/image_loader.dart';

/// 统一网络图片组件：自带登录态、防盗链降级、加载占位与失败重试。
///
/// 相比 `Image.network`，它能在失败时给出具体原因（HTTP 状态 / 网络异常），
/// 并支持点一下重试；SVG 头像这类无法解码的资源会走 errorBuilder 而不是报红。
class NetImage extends StatefulWidget {
  const NetImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorBuilder,
    this.placeholderBuilder,
    this.semanticLabel,
    this.showRetry = true,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final WidgetBuilder? errorBuilder;
  final WidgetBuilder? placeholderBuilder;
  final String? semanticLabel;
  final bool showRetry;

  @override
  State<NetImage> createState() => _NetImageState();
}

class _NetImageState extends State<NetImage> {
  late DiscuzImageProvider _provider;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _provider = DiscuzImageProvider(widget.url);
  }

  @override
  void didUpdateWidget(covariant NetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _provider = DiscuzImageProvider(widget.url);
      _attempt = 0;
    }
  }

  void _retry() {
    imageCache.evict(_provider);
    setState(() {
      _provider = DiscuzImageProvider(widget.url);
      _attempt++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget image = Image(
      key: ValueKey('${widget.url}#$_attempt'),
      image: _provider,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      semanticLabel: widget.semanticLabel,
      loadingBuilder: (c, child, progress) {
        if (progress == null) return child;
        return widget.placeholderBuilder?.call(c) ??
            _box(
              theme,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
      },
      errorBuilder: (c, error, stack) {
        if (widget.errorBuilder != null) return widget.errorBuilder!(c);
        return _errorBox(theme, error);
      },
    );

    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }
    return image;
  }

  Widget _box(ThemeData theme, {required Widget child}) {
    return Container(
      width: widget.width,
      height: widget.height ?? 120,
      alignment: Alignment.center,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
      child: child,
    );
  }

  Widget _errorBox(ThemeData theme, Object error) {
    final msg = error is ImageFetchException ? error.message : '图片加载失败';
    return Container(
      width: widget.width,
      height: widget.height ?? 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: widget.borderRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 20, color: theme.colorScheme.outline),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              msg,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.outline),
            ),
          ),
          if (widget.showRetry)
            TextButton(
              onPressed: _retry,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('重试', style: TextStyle(fontSize: 11.5)),
            ),
        ],
      ),
    );
  }
}
