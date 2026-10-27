import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import 'net_image.dart';

/// 站点 `noavatar.svg` 的位图版本，用于没有自定义头像的用户。
///
/// 论坛默认头像是 SVG，Flutter 无法解码；站点同时提供同尺寸的
/// `static/image/common/tavatar.gif`，内置一份作为位图兜底。
const String defaultAvatarAsset = 'assets/images/default_avatar.gif';

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.url, this.size = 38, this.name, this.onTap});

  final String? url;
  final double size;
  final String? name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        (name == null || name!.isEmpty) ? '源' : name!.substring(0, 1),
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );

    Widget defaultAvatar() => ClipOval(
      child: Image.asset(
        defaultAvatarAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => placeholder,
      ),
    );

    final lower = url?.toLowerCase() ?? '';
    final needsDefault =
        lower.isEmpty || lower.contains('noavatar') || lower.endsWith('.svg');

    Widget child;
    if (needsDefault) {
      child = defaultAvatar();
    } else {
      child = ClipOval(
        child: NetImage(
          url: url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          showRetry: false,
          errorBuilder: (c) => defaultAvatar(),
          placeholderBuilder: (c) => placeholder,
        ),
      );
    }
    if (onTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}

class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          height: 1.3,
          color: c,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: Icons.wifi_tethering_error_rounded,
      message: message,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
    );
  }
}

/// 微光扫过动画骨架屏。
///
/// [baseColor] 为骨架底色，高光 [highlightColor] 以对角渐变形式
/// 从左向右扫过，循环播放；用于列表重建/首屏加载时的占位。
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    required this.baseColor,
    required this.highlightColor,
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (c, child) {
        final t = _ctrl.value;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child!,
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1 + 2 * t, 0),
                    end: Alignment(1 + 2 * t, 0),
                    colors: [
                      Colors.transparent,
                      widget.highlightColor.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(color: widget.baseColor),
        child: widget.child,
      ),
    );
  }
}

/// 单个帖子卡片骨架：布局对齐 [ThreadTile]
/// （头像 → 作者行 → 标题 → 摘要 → 首图 → 数据行）。
class SkeletonTile extends StatelessWidget {
  const SkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    final semantic = YuanSemanticColors.of(context);
    const avatarSize = YuanSizes.avatarReply * 0.94;
    final base = semantic.surfaceContainerHigh;
    final blockColor = semantic.surfaceDim;
    return Shimmer(
      baseColor: base,
      highlightColor: semantic.glassHighlight,
      child: Container(
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(YuanRadius.md),
          border: Border.all(color: semantic.outlineSubtle, width: 0.9),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            YuanSpace.sm + 2,
            YuanSpace.sm,
            YuanSpace.sm + 2,
            YuanSpace.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 作者行：头像 + 昵称/时间 + 版块标签
              Row(
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: blockColor,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _block(
                          blockColor,
                          height: 13,
                          width: 110,
                          radius: YuanRadius.pill,
                        ),
                        const SizedBox(height: 4),
                        _block(
                          blockColor,
                          height: 10,
                          width: 70,
                          radius: YuanRadius.pill,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _block(
                    blockColor,
                    height: 20,
                    width: 52,
                    radius: YuanRadius.pill,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 标题（两行）
              _block(blockColor, height: 15, width: 190),
              const SizedBox(height: 8),
              _block(blockColor, height: 15, width: 120),
              const SizedBox(height: 10),
              // 摘要（两行）
              _block(blockColor, height: 12, width: 200),
              const SizedBox(height: 7),
              _block(blockColor, height: 12, width: 150),
              const SizedBox(height: 10),
              // 首图（16:9）
              ClipRRect(
                borderRadius: BorderRadius.circular(YuanRadius.xs),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(color: blockColor),
                ),
              ),
              const SizedBox(height: 10),
              // 数据行
              Row(
                children: [
                  _block(
                    blockColor,
                    height: 11,
                    width: 44,
                    radius: YuanRadius.pill,
                  ),
                  const SizedBox(width: YuanSpace.md),
                  _block(
                    blockColor,
                    height: 11,
                    width: 44,
                    radius: YuanRadius.pill,
                  ),
                  const SizedBox(width: YuanSpace.md),
                  _block(
                    blockColor,
                    height: 11,
                    width: 32,
                    radius: YuanRadius.pill,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _block(
    Color color, {
    double? height,
    double? width,
    double radius = YuanRadius.xs,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// 骨架屏列表：替换列表加载期间的空白/转圈占位。
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    final barInset = BottomBarInset.of(context);
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 24 + barInset),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (c, i) => const SkeletonTile(),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// 悬浮底栏占位：底栏用 `extendBody` 盖在内容之上，
/// 滚动列表必须在底部留出 [value] 的空白，否则最后一条会被胶囊挡住。
///
/// 由 [HomeShell] 在窄屏分支注入（含系统安全区），
/// 二级页面（推入的路由）不在其子树内，[of] 返回 0，无需额外留白。
class BottomBarInset extends InheritedWidget {
  const BottomBarInset({super.key, required this.value, required super.child});

  /// 需要预留的底部高度（含安全区与呼吸距离）。
  final double value;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BottomBarInset>()?.value ?? 0;

  @override
  bool updateShouldNotify(BottomBarInset oldWidget) => oldWidget.value != value;
}

String humanNumber(int n) {
  if (n >= 10000) {
    final v = n / 10000;
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}万';
  }
  return '$n';
}

/// 大数字加千分位，与站点显示一致（1,234 / 12,345）。
String thousandCount(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return v < 0 ? '-$buf' : buf.toString();
}
