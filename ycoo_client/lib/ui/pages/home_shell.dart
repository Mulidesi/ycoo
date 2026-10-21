import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/in_app_nav.dart';
import '../../core/utils/link_resolver.dart';
import '../../design/glass/liquid_glass_bar.dart';
import '../../state/app_state.dart';
import 'boards_page.dart';
import 'feed_page.dart';
import 'profile_page.dart';

/// 主框架：窄屏用**悬浮液态玻璃底栏**（首页 / 版块 / 我的），
/// 宽屏（≥900）切换为 `NavigationRail` 侧栏布局，签到入口并入「我的」。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  static const _pages = <Widget>[
    FeedPage(),
    BoardsPage(),
    ProfilePage(),
  ];

  static const _items = <BarDestination>[
    BarDestination(
      icon: Icons.article_outlined,
      selectedIcon: Icons.article_rounded,
      label: '首页',
    ),
    BarDestination(
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      label: '版块',
    ),
    BarDestination(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: '我的',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 冷启动后检查一次剪贴板（等首帧完成、路由稳定后再弹）
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().autoSignIfNeeded();
      // Android 10+ 只有回到前台才允许读剪贴板
      _checkClipboard();
    }
  }

  /// 剪贴板论坛链接识别：发现 ycoo.net / pc.sysbbs.com 的帖子 / 版块链接时
  /// 弹窗询问是否在应用内打开；同一内容只提示一次，可在设置里关闭。
  Future<void> _checkClipboard() async {
    if (!mounted) return;
    final navContext = context;
    final st = context.read<AppState>();
    if (!st.settings.clipboardDetect) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      final uri = LinkResolver.findForumUrlInText(text);
      if (uri == null || !st.shouldPromptClipboard(uri.toString())) return;
      if (!mounted) return;
      final match = LinkResolver.resolveInAnySite(uri);
      final desc = match == null
          ? '检测到论坛链接，是否在应用内打开？'
          : (match.target.kind == InAppTargetKind.thread
              ? '检测到论坛帖子链接，是否在应用内打开？'
              : '检测到论坛版块链接，是否在应用内打开？');
      await st.markClipboardPrompted(uri.toString());
      if (!mounted) return;
      final open = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('打开论坛链接'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(desc, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                uri.toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Theme.of(c).colorScheme.outline),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('忽略')),
            FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('打开')),
          ],
        ),
      );
      if (open == true && navContext.mounted) {
        final ok = openInAppIfInternal(navContext, uri.toString());
        if (!ok && navContext.mounted) {
          ScaffoldMessenger.of(navContext).showSnackBar(
            const SnackBar(content: Text('该链接暂不支持应用内打开，请在浏览器查看')),
          );
        }
      }
    } catch (_) {
      // 剪贴板读取失败（权限/平台限制）静默跳过
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final body = IndexedStack(index: _index, children: _pages);

        if (!wide) {
          return Scaffold(
            // 底栏悬浮，列表需要为它预留底部空间
            body: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: body,
            ),
            extendBody: true,
            bottomNavigationBar: LiquidGlassBar(
              destinations: _items,
              currentIndex: _index,
              onSelected: (i) => setState(() => _index = i),
              badgeCounts: const {},
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                extended: constraints.maxWidth >= 1240,
                minExtendedWidth: 168,
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: constraints.maxWidth >= 1240
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF60A5FA), Color(0xFF2563EB)]),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Text(
                      '源',
                      style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                destinations: [
                  for (final it in _items)
                    NavigationRailDestination(
                      icon: Icon(it.icon, size: 22),
                      selectedIcon: Icon(it.selectedIcon, size: 22),
                      label: Text(it.label),
                    ),
                ],
              ),
              VerticalDivider(width: 1, color: Theme.of(context).dividerTheme.color),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}
