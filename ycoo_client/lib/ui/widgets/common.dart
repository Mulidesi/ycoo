import 'package:flutter/material.dart';

import 'net_image.dart';

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

    Widget child;
    if (url == null || url!.isEmpty) {
      child = placeholder;
    } else {
      child = ClipOval(
        child: NetImage(
          url: url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          showRetry: false,
          errorBuilder: (c) => placeholder,
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
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, height: 1.3, color: c, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined, this.action});

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
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
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

class LoadingList extends StatelessWidget {
  const LoadingList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (c, i) => Container(
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

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
