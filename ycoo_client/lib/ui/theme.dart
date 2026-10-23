import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// 主题构建器。
///
/// 颜色 / 间距 / 圆角 / 字号一律来自 `lib/design/tokens.dart`，
/// 语义色通过 `YuanSemanticColors` ThemeExtension 注入，
/// 浅色与深色对等（见 DESIGN.md 第 3、8 节）。
class AppTheme {
  /// 兼容旧调用点：品牌蓝（浅色）。
  static const Color brand = YuanColors.brandPrimaryLight;
  static const Color brandDeep = Color(0xFF1E40AF);
  static const Color accent = YuanColors.brandTertiaryLight;
  static const Color surfaceTint = YuanColors.surfaceDimLight;

  /// [dynamicScheme] 来自 dynamic_color（Material You 壁纸取色），
  /// 传入时覆盖品牌种子色方案；null 时按 tokens 构建品牌主题。
  static ThemeData light([ColorScheme? dynamicScheme]) => _build(Brightness.light, dynamicScheme);
  static ThemeData dark([ColorScheme? dynamicScheme]) => _build(Brightness.dark, dynamicScheme);

  static ThemeData _build(Brightness brightness, [ColorScheme? dynamicScheme]) {
    final isLight = brightness == Brightness.light;

    final scheme = dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: isLight ? YuanColors.seedLight : YuanColors.seedDark,
          brightness: brightness,
          surface: isLight ? YuanColors.surfaceThreadBodyLight : YuanColors.surfaceThreadBodyDark,
        );

    final semantic = isLight ? YuanSemanticColors.light : YuanSemanticColors.dark;
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[semantic],
      scaffoldBackgroundColor:
          isLight ? YuanColors.surfaceDimLight : YuanColors.surfaceDimDark,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        backgroundColor: isLight
            ? YuanColors.surfaceThreadBodyLight
            : YuanColors.surfaceThreadBodyDark,
        foregroundColor: isLight ? YuanColors.textPrimaryLight : YuanColors.textPrimaryDark,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isLight ? YuanColors.textPrimaryLight : YuanColors.textPrimaryDark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isLight
            ? YuanColors.surfaceThreadBodyLight
            : YuanColors.surfaceThreadBodyDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(YuanRadius.md)),
      ),
      dividerTheme: DividerThemeData(
        color: isLight ? YuanColors.outlineSubtleLight : YuanColors.outlineSubtleDark,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? YuanColors.surfaceReplyLight : YuanColors.surfaceReplyDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: YuanSpace.md,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(YuanRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(YuanRadius.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(YuanRadius.sm),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(YuanRadius.sm)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(YuanRadius.sm)),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: isLight ? YuanColors.textPrimaryLight : YuanColors.textPrimaryDark,
        displayColor: isLight ? YuanColors.textPrimaryLight : YuanColors.textPrimaryDark,
      ),
    );
  }
}
