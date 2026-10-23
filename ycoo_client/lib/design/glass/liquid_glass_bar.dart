/// 悬浮液态玻璃底栏。
///
/// 三入口胶囊底栏：`SafeArea` → 外边距 → `GlassContainer`（liquid_glass_widgets）。
/// 选中项**不再有小方块/胶囊背景**，仅以高亮色（brandPrimary）区分；
/// 未选中用次级文字色。交互与视觉约束见 DESIGN.md 第 5 节。
library;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../tokens.dart';

/// 单个底栏入口。
@immutable
class BarDestination {
  const BarDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  /// 未选中（线性图标）。
  final IconData icon;

  /// 选中（填充图标）。
  final IconData selectedIcon;

  /// 标签。
  final String label;
}

/// 悬浮液态玻璃底栏，**恰好 3 个入口**。
class LiquidGlassBar extends StatelessWidget {
  const LiquidGlassBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
    this.badgeCounts = const <int, int>{},
  }) : assert(destinations.length == 3, '底栏必须恰好 3 个一级入口');

  final List<BarDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// Tab 角标：`index → 数量`，0 不显示。
  final Map<int, int> badgeCounts;

  @override
  Widget build(BuildContext context) {
    final semantic = YuanSemanticColors.of(context);
    final disableAnim = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          YuanSpace.barHorizontal,
          YuanSpace.xxs,
          YuanSpace.barHorizontal,
          YuanSpace.barBottom,
        ),
        child: GlassContainer(
          height: YuanSizes.barHeight,
          shape: const LiquidRoundedSuperellipse(
            borderRadius: YuanRadius.lg,
          ),
          settings: LiquidGlassSettings(
            glassColor: semantic.glassFill,
            blur: YuanGlass.blur,
            thickness: YuanGlass.thickness,
          ),
          // 底栏固定在视口底部：独立合成层，避免随列表滚动重绘。
          useOwnLayer: true,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _BarItem(
                    destination: destinations[i],
                    selected: i == currentIndex,
                    badge: badgeCounts[i] ?? 0,
                    disableAnim: disableAnim,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.destination,
    required this.selected,
    required this.badge,
    required this.disableAnim,
    required this.onTap,
  });

  final BarDestination destination;
  final bool selected;
  final int badge;
  final bool disableAnim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = YuanSemanticColors.of(context);
    final color = selected ? semantic.brandPrimary : semantic.textSecondary;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(YuanRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: YuanSpace.xs),
          child: AnimatedSlide(
            duration: disableAnim ? Duration.zero : YuanMotion.fast,
            curve: YuanMotion.springNav,
            offset: selected ? const Offset(0, -0.08) : Offset.zero,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 选中态只用高亮色区分，不再绘制背景块 / 胶囊。
                    AnimatedSwitcher(
                      duration:
                          disableAnim ? Duration.zero : YuanMotion.fast,
                      switchInCurve: YuanMotion.emphasized,
                      switchOutCurve: YuanMotion.emphasized,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: Icon(
                        selected
                            ? destination.selectedIcon
                            : destination.icon,
                        key: ValueKey<bool>(selected),
                        size: 24,
                        color: color,
                      ),
                    ),
                    if (badge > 0)
                      Positioned(
                        right: -10,
                        top: -6,
                        child: _Badge(count: badge),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: disableAnim ? Duration.zero : YuanMotion.fast,
                  curve: YuanMotion.emphasized,
                  style: YuanType.label.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final semantic = YuanSemanticColors.of(context);
    final text = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: semantic.danger,
        borderRadius: BorderRadius.circular(YuanRadius.pill),
        border: Border.all(color: semantic.glassStroke, width: 1),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
