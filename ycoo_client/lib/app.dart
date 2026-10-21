import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'ui/pages/home_shell.dart';
import 'ui/pages/login_page.dart';
import 'ui/theme.dart';

class YcooApp extends StatelessWidget {
  const YcooApp({super.key});

  /// 把设置里的外观字符串映射为 ThemeMode。
  static ThemeMode _modeOf(String mode) => switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  @override
  Widget build(BuildContext context) {
    final themeMode = _modeOf(context.select<AppState, String>((st) => st.settings.themeMode));
    final useDynamic = context.select<AppState, bool>((st) => st.settings.dynamicColor);
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: '源坛',
          debugShowCheckedModeBanner: false,
          // Android 12+ Material You：跟随壁纸取色；关闭或平台不支持时用品牌色
          theme: useDynamic && lightDynamic != null ? AppTheme.light(lightDynamic) : AppTheme.light(),
          darkTheme: useDynamic && darkDynamic != null ? AppTheme.dark(darkDynamic) : AppTheme.dark(),
          themeMode: themeMode,
          home: const RootGate(),
        );
      },
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: st.booting
          ? const _Splash()
          : st.loggedIn
              ? const HomeShell()
              : const LoginPage(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1B3A), Color(0xFF173C8F), Color(0xFF2563EB)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF60A5FA), Color(0xFF2563EB)]),
                  borderRadius: BorderRadius.circular(21),
                ),
                child: const Text(
                  '源',
                  style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '源坛',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 4),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
