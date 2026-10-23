/// 设计令牌（Design Tokens）。
///
/// 唯一颜色 / 间距 / 圆角 / 字号 / 运动 / 尺寸来源。
/// **业务与 UI 代码禁止散落 Magic Number**，一律引用本文件的语义常量，
/// 便于浅色 / 深色对等切换与全站视觉统一（对应 DESIGN.md 第 4 节）。
library;

import 'package:flutter/material.dart';

/// 品牌与种子色。
abstract final class YuanColors {
  /// ColorScheme 种子色（浅色 / 深色）。
  static const seedLight = Color(0xFF2563EB);
  static const seedDark = Color(0xFF60A5FA);

  static const brandPrimaryLight = Color(0xFF2563EB);
  static const brandPrimaryDark = Color(0xFF93C5FD);

  /// 主色加深档，用于渐变端点与强调文字。
  static const brandDeepLight = Color(0xFF1E40AF);
  static const brandDeepDark = Color(0xFF1E3A8A);
  static const brandSecondaryLight = Color(0xFF0EA5E9);
  static const brandSecondaryDark = Color(0xFF38BDF8);

  /// 琥珀：星币、付费、签到奖励专用，避免与正文蓝抢层级。
  static const brandTertiaryLight = Color(0xFFF59E0B);
  static const brandTertiaryDark = Color(0xFFFBBF24);

  // ---- 表面（Surface）----
  static const surfaceBaseLight = Color(0xFFFFFBFF);
  static const surfaceBaseDark = Color(0xFF111318);
  static const surfaceDimLight = Color(0xFFF3F4F6);
  static const surfaceDimDark = Color(0xFF0B0D11);
  static const surfaceContainerLight = Color(0xFFF8F9FC);
  static const surfaceContainerDark = Color(0xFF1A1D24);
  static const surfaceContainerHighLight = Color(0xFFFFFFFF);
  static const surfaceContainerHighDark = Color(0xFF23262E);

  /// 帖子正文层（1 楼）。
  static const surfaceThreadBodyLight = Color(0xFFFFFFFF);
  static const surfaceThreadBodyDark = Color(0xFF1C1F27);

  /// 回帖层。
  static const surfaceReplyLight = Color(0xFFF4F6FA);
  static const surfaceReplyDark = Color(0xFF181B22);

  /// 楼中楼层。
  static const surfaceCommentLight = Color(0xFFEEF1F6);
  static const surfaceCommentDark = Color(0xFF15181E);

  // ---- 文字 ----
  static const textPrimaryLight = Color(0xFF0F172A);
  static const textPrimaryDark = Color(0xFFF1F5F9);
  static const textSecondaryLight = Color(0xFF475569);
  static const textSecondaryDark = Color(0xFF94A3B8);
  static const textTertiaryLight = Color(0xFF94A3B8);
  static const textTertiaryDark = Color(0xFF64748B);

  // ---- 边线 ----
  static const outlineSubtleLight = Color(0xFFE2E8F0);
  static const outlineSubtleDark = Color(0xFF2A2F3A);
  static const outlineReplyRailLight = Color(0xFFCBD5E1);
  static const outlineReplyRailDark = Color(0xFF3F4654);

  // ---- 状态 ----
  static const successLight = Color(0xFF16A34A);
  static const successDark = Color(0xFF4ADE80);
  static const dangerLight = Color(0xFFDC2626);
  static const dangerDark = Color(0xFFF87171);
  static const warningLight = Color(0xFFD97706);
  static const warningDark = Color(0xFFFBBF24);

  // ---- 玻璃 ----
  static const glassFillLight = Color(0x9EFFFFFF);
  static const glassFillDark = Color(0x8C16181F);
  static const glassStrokeLight = Color(0x8CFFFFFF);
  static const glassStrokeDark = Color(0x1FFFFFFF);
  static const glassHighlightLight = Color(0xD9FFFFFF);
  static const glassHighlightDark = Color(0x2EFFFFFF);
}

/// 间距：`4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48`。
abstract final class YuanSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 40.0;
  static const huge = 48.0;

  /// 页面水平边距。
  static const pageHorizontal = md;

  /// 悬浮底栏左右外边距 / 底部外边距。
  static const barHorizontal = md;
  static const barBottom = sm;
}

/// 圆角。
abstract final class YuanRadius {
  static const xs = 8.0; // Chip、楼中楼气泡
  static const sm = 12.0; // 回帖卡片、输入框
  static const md = 16.0; // 帖子卡片、板块磁贴
  static const lg = 24.0; // 底栏胶囊、对话框
  static const pill = 999.0; // 选中指示、徽章
}

/// 字号（含行高与字重）。
///
/// 正文 / 回帖 / 楼中楼的字号差是**硬约束**：
/// `bodyLg 16/26` > `bodyMd 14/22` > `bodySm 13/20`。
abstract final class YuanType {
  static const display =
      TextStyle(fontSize: 28, height: 36 / 28, fontWeight: FontWeight.w600);
  static const titleLg =
      TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600);
  static const titleMd =
      TextStyle(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600);
  static const titleSm =
      TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600);

  /// **帖子正文**。
  static const bodyLg = TextStyle(fontSize: 16, height: 26 / 16);

  /// **回帖正文**。
  static const bodyMd = TextStyle(fontSize: 14, height: 22 / 14);

  /// **楼中楼**。
  static const bodySm = TextStyle(fontSize: 13, height: 20 / 13);

  static const label =
      TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500);
  static const caption = TextStyle(fontSize: 11, height: 14 / 11);
}

/// 运动。
abstract final class YuanMotion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);

  static const emphasized = Curves.easeOutCubic;
  static const standard = Curves.easeInOutCubicEmphasized;
  static const springNav = Curves.easeOutBack;
}

/// 液态玻璃（liquid_glass_widgets）统一参数。
///
/// 底栏与回帖栏共用一组参数，避免两个玻璃面出现厚度/磨砂不一致。
/// `blur` / `thickness` 直接对应 `LiquidGlassSettings.blur/thickness`；
/// 渲染器不支持 Shader 时组件库自动降级，参数仍生效于磨砂回退。
abstract final class YuanGlass {
  /// 磨砂强度（逻辑像素，typical 2–8）。
  static const blur = 6.0;

  /// 玻璃厚度 / 折射深度（逻辑像素，typical 10–40）。
  static const thickness = 24.0;

  /// 回帖栏离屏幕左右 / 底部的呼吸边距。
  static const replyBarMargin = YuanSpace.sm;

  /// 回帖栏收起态高度 / 展开态最小高度。
  static const replyBarCollapsedHeight = 56.0;
  static const replyBarExpandedMinHeight = 148.0;
}

/// 尺寸与派生常量。
abstract final class YuanSizes {
  /// 悬浮底栏高度。
  static const barHeight = 64.0;

  /// 悬浮底栏总占位高度（不含系统安全区）：
  /// 上外边距 + 胶囊高度 + 下外边距。
  static const barTotalHeight = YuanSpace.xxs + barHeight + YuanSpace.barBottom;

  /// 滚动内容为悬浮底栏预留空间时，额外留出的呼吸距离。
  static const barContentGap = 16.0;

  /// 悬浮底栏需要内容预留的底部高度：安全区 + 胶囊 + 外边距 + 呼吸距离。
  ///
  /// [safeBottom] 取 `MediaQuery.viewPadding.bottom`（刘海屏 / 手势条）。
  static double bottomBarInset(double safeBottom) =>
      safeBottom + barTotalHeight + barContentGap;

  /// 无障碍最小点击区域。
  static const minTapTarget = 48.0;

  /// 头像尺寸：正文 / 回帖 / 楼中楼 / 个人资料。
  static const avatarThreadBody = 48.0;
  static const avatarReply = 36.0;
  static const avatarComment = 24.0;
  static const avatarProfile = 72.0;

  /// 回帖左轨线宽度 / 楼中楼缩进。
  static const replyRailWidth = 3.0;
  static const commentIndent = 12.0;

  /// 正文长图限高（点开看全图）。
  static const maxLongImageHeight = 360.0;

  /// 正文图片渲染上限（本页 v1.0.3 取值，小于长图限高）。
  static const maxPostImageHeight = 420.0;

  static const postEmojiSize = 22.0;

  /// 自动回复曝光判定：可见比例阈值。
  static const exposureMinVisibleRatio = 0.6;

  /// 自动回复曝光判定：最短停留毫秒数。
  static const exposureMinDurationMs = 1200;

  /// 自动回复每日去重窗口（小时）。
  static const autoReplyDedupWindowHours = 24;

  /// 自动签到去重窗口（小时）。
  static const autoCheckinDedupWindowHours = 12;

  /// 自动回复队列上限。
  static const autoReplyMaxQueueSize = 200;
}

/// 语义色集合，作为 `ThemeExtension` 挂到 ThemeData 上。
///
/// 任何 Widget 通过 `YuanSemanticColors.of(context)` 取色，
/// 禁止自行判断 `ThemeMode` 后再拼颜色。
class YuanSemanticColors extends ThemeExtension<YuanSemanticColors> {
  const YuanSemanticColors({
    required this.surfaceBase,
    required this.surfaceDim,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceThreadBody,
    required this.surfaceReply,
    required this.surfaceComment,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.outlineSubtle,
    required this.outlineReplyRail,
    required this.success,
    required this.danger,
    required this.warning,
    required this.brandPrimary,
    required this.brandSecondary,
    required this.brandTertiary,
    required this.glassFill,
    required this.glassStroke,
    required this.glassHighlight,
  });

  final Color surfaceBase;
  final Color surfaceDim;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceThreadBody;
  final Color surfaceReply;
  final Color surfaceComment;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color outlineSubtle;
  final Color outlineReplyRail;
  final Color success;
  final Color danger;
  final Color warning;
  final Color brandPrimary;
  final Color brandSecondary;
  final Color brandTertiary;
  final Color glassFill;
  final Color glassStroke;
  final Color glassHighlight;

  static const light = YuanSemanticColors(
    surfaceBase: YuanColors.surfaceBaseLight,
    surfaceDim: YuanColors.surfaceDimLight,
    surfaceContainer: YuanColors.surfaceContainerLight,
    surfaceContainerHigh: YuanColors.surfaceContainerHighLight,
    surfaceThreadBody: YuanColors.surfaceThreadBodyLight,
    surfaceReply: YuanColors.surfaceReplyLight,
    surfaceComment: YuanColors.surfaceCommentLight,
    textPrimary: YuanColors.textPrimaryLight,
    textSecondary: YuanColors.textSecondaryLight,
    textTertiary: YuanColors.textTertiaryLight,
    outlineSubtle: YuanColors.outlineSubtleLight,
    outlineReplyRail: YuanColors.outlineReplyRailLight,
    success: YuanColors.successLight,
    danger: YuanColors.dangerLight,
    warning: YuanColors.warningLight,
    brandPrimary: YuanColors.brandPrimaryLight,
    brandSecondary: YuanColors.brandSecondaryLight,
    brandTertiary: YuanColors.brandTertiaryLight,
    glassFill: YuanColors.glassFillLight,
    glassStroke: YuanColors.glassStrokeLight,
    glassHighlight: YuanColors.glassHighlightLight,
  );

  static const dark = YuanSemanticColors(
    surfaceBase: YuanColors.surfaceBaseDark,
    surfaceDim: YuanColors.surfaceDimDark,
    surfaceContainer: YuanColors.surfaceContainerDark,
    surfaceContainerHigh: YuanColors.surfaceContainerHighDark,
    surfaceThreadBody: YuanColors.surfaceThreadBodyDark,
    surfaceReply: YuanColors.surfaceReplyDark,
    surfaceComment: YuanColors.surfaceCommentDark,
    textPrimary: YuanColors.textPrimaryDark,
    textSecondary: YuanColors.textSecondaryDark,
    textTertiary: YuanColors.textTertiaryDark,
    outlineSubtle: YuanColors.outlineSubtleDark,
    outlineReplyRail: YuanColors.outlineReplyRailDark,
    success: YuanColors.successDark,
    danger: YuanColors.dangerDark,
    warning: YuanColors.warningDark,
    brandPrimary: YuanColors.brandPrimaryDark,
    brandSecondary: YuanColors.brandSecondaryDark,
    brandTertiary: YuanColors.brandTertiaryDark,
    glassFill: YuanColors.glassFillDark,
    glassStroke: YuanColors.glassStrokeDark,
    glassHighlight: YuanColors.glassHighlightDark,
  );

  /// 取当前主题的语义色，未注入时回落到浅色。
  static YuanSemanticColors of(BuildContext context) {
    return Theme.of(context).extension<YuanSemanticColors>() ?? light;
  }

  @override
  YuanSemanticColors copyWith({
    Color? surfaceBase,
    Color? surfaceDim,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceThreadBody,
    Color? surfaceReply,
    Color? surfaceComment,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? outlineSubtle,
    Color? outlineReplyRail,
    Color? success,
    Color? danger,
    Color? warning,
    Color? brandPrimary,
    Color? brandSecondary,
    Color? brandTertiary,
    Color? glassFill,
    Color? glassStroke,
    Color? glassHighlight,
  }) {
    return YuanSemanticColors(
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceDim: surfaceDim ?? this.surfaceDim,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceThreadBody: surfaceThreadBody ?? this.surfaceThreadBody,
      surfaceReply: surfaceReply ?? this.surfaceReply,
      surfaceComment: surfaceComment ?? this.surfaceComment,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      outlineSubtle: outlineSubtle ?? this.outlineSubtle,
      outlineReplyRail: outlineReplyRail ?? this.outlineReplyRail,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandSecondary: brandSecondary ?? this.brandSecondary,
      brandTertiary: brandTertiary ?? this.brandTertiary,
      glassFill: glassFill ?? this.glassFill,
      glassStroke: glassStroke ?? this.glassStroke,
      glassHighlight: glassHighlight ?? this.glassHighlight,
    );
  }

  @override
  YuanSemanticColors lerp(ThemeExtension<YuanSemanticColors>? other, double t) {
    if (other is! YuanSemanticColors) return this;
    return YuanSemanticColors(
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceDim: Color.lerp(surfaceDim, other.surfaceDim, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      surfaceContainerHigh:
          Color.lerp(surfaceContainerHigh, other.surfaceContainerHigh, t)!,
      surfaceThreadBody:
          Color.lerp(surfaceThreadBody, other.surfaceThreadBody, t)!,
      surfaceReply: Color.lerp(surfaceReply, other.surfaceReply, t)!,
      surfaceComment: Color.lerp(surfaceComment, other.surfaceComment, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      outlineSubtle: Color.lerp(outlineSubtle, other.outlineSubtle, t)!,
      outlineReplyRail: Color.lerp(outlineReplyRail, other.outlineReplyRail, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      brandSecondary: Color.lerp(brandSecondary, other.brandSecondary, t)!,
      brandTertiary: Color.lerp(brandTertiary, other.brandTertiary, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassStroke: Color.lerp(glassStroke, other.glassStroke, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
    );
  }
}
