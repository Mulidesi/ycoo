import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/parsers.dart';
import '../../design/tokens.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'image_diag_page.dart';
import 'sign_page.dart';
import 'site_settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final st = context.watch<AppState>();
    final u = st.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            tooltip: '刷新资料',
            onPressed: () async {
              await st.refreshUser();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('资料已刷新')));
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(YuanSpace.md, YuanSpace.xs, YuanSpace.md, YuanSpace.xxl),
        children: [
          _profileCard(theme, st, u),
          const SizedBox(height: 14),
          _sectionTitle(theme, '自动功能'),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const _TileIcon(Icons.event_available_rounded, YuanColors.successLight),
                  title: const Text('每日签到', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    st.signStatus?.signedToday == true
                        ? '今日已签到 · 连续 ${st.signStatus?.streakDays ?? 0} 天'
                        : '查看签到状态与连续天数',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignPage()),
                  ),
                ),
                const Divider(indent: 56),
                SwitchListTile(
                  value: st.settings.autoSign,
                  onChanged: (v) => st.updateSettings((s) => s.autoSign = v),
                  secondary: const _TileIcon(Icons.event_available_rounded, YuanColors.brandSecondaryLight),
                  title: const Text('自动签到', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: const Text('启动 / 回到前台时自动签到，每天一次', style: TextStyle(fontSize: 11.5)),
                ),
                const Divider(indent: 56),
                SwitchListTile(
                  value: st.settings.autoReply,
                  onChanged: (v) async {
                    if (v && st.settings.effectivePresets.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请先添加至少 1 条自动回复预设')),
                      );
                      return;
                    }
                    await st.updateSettings((s) => s.autoReply = v);
                    st.replyQueue.setEnabled(v);
                  },
                  secondary: const _TileIcon(Icons.reply_all_rounded, YuanColors.brandPrimaryLight),
                  title: const Text('隐藏贴自动回复', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    '打开「回复可见」的帖子时自动回复解锁 · 今日已回 ${st.todayReplyCount}/${st.settings.dailyReplyLimit}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const _TileIcon(Icons.edit_note_rounded, YuanColors.brandTertiaryLight),
                  title: const Text('自动回复预设', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    st.settings.effectivePresets.isEmpty
                        ? '尚未设置（最多 5 条，随机取一）'
                        : '${st.settings.effectivePresets.length} 条预设 · ${st.settings.effectivePresets.first.text}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _editReplyPresets(st),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const _TileIcon(Icons.receipt_long_rounded, YuanColors.textTertiaryLight),
                  title: const Text('自动化记录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    '自动回复 ${st.replyLogs.length} 条 · 签到 ${st.checkinLogs.length} 条',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _showAutomationLogs(context, st),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const _TileIcon(Icons.tune_rounded, YuanColors.brandTertiaryLight),
                  title: const Text('每日自动回复上限', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text('${st.settings.dailyReplyLimit} 条 / 天',
                      style: const TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _editLimit(st),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const _TileIcon(Icons.history_rounded, YuanColors.textTertiaryLight),
                  title: const Text('清除自动回复记录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: const Text('清空后，已回复过的帖子可能再次自动回复', style: TextStyle(fontSize: 11.5)),
                  onTap: () async {
                    await st.clearAutoReplyHistory();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清除')));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle(theme, '通用'),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const _TileIcon(Icons.dns_rounded, Color(0xFF0EA5E9)),
                  title: const Text('站点与网络', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    '主域名 ${st.site.origin} · 双域名访问测试 · 剪贴板识别${st.settings.clipboardDetect ? '已开' : '已关'}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SiteSettingsPage()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle(theme, '外观'),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: st.settings.dynamicColor,
                  onChanged: (v) => st.updateSettings((s) => s.dynamicColor = v),
                  secondary: const _TileIcon(Icons.palette_outlined, Color(0xFF8B5CF6)),
                  title: const Text('Material You 动态取色', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: const Text('跟随系统壁纸配色（Android 12+ 生效）', style: TextStyle(fontSize: 11.5)),
                ),
                for (final (mode, label, icon) in const [
                  ('system', '跟随系统', Icons.brightness_auto_rounded),
                  ('light', '浅色模式', Icons.light_mode_rounded),
                  ('dark', '深色模式', Icons.dark_mode_rounded),
                ])
                  RadioListTile<String>(
                    value: mode,
                    groupValue: st.settings.themeMode,
                    onChanged: (v) => st.setThemeMode(v ?? 'system'),
                    secondary: _TileIcon(icon, YuanColors.brandPrimaryLight),
                    title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle(theme, '账号'),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const _TileIcon(Icons.image_search_rounded, Color(0xFF8B5CF6)),
                  title: const Text('图片加载诊断', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: const Text('检测头像 / 附件图 / 外链图床的加载情况', style: TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ImageDiagPage()),
                  ),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const _TileIcon(Icons.open_in_new_rounded, Color(0xFF0EA5E9)),
                  title: const Text('在浏览器打开源论坛', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => launchUrl(Uri.parse(kBaseUrl), mode: LaunchMode.externalApplication),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const _TileIcon(Icons.logout_rounded, Color(0xFFEF4444)),
                  title: const Text('退出登录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFEF4444))),
                  onTap: () => _confirmLogout(st),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '源坛 v1.0.9 · 第三方客户端\n与源论坛官方无关，数据版权归源论坛及原作者所有',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                height: 1.7,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.outline,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _profileCard(ThemeData theme, AppState st, UserProfile? u) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: Avatar(url: u?.avatar, name: u?.username, size: 54),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u?.username ?? '未登录',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (u?.uid != null && u!.uid > 0)
                          _pill('UID ${u.uid}'),
                        if ((u?.group ?? '').isNotEmpty) _pill(u!.group!),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _metric('积分', u?.credits ?? '—'),
                _metric('主题', u?.threads?.toString() ?? '—'),
                _metric('回帖', u?.posts?.toString() ?? '—'),
                _metric('好友', u?.friends?.toString() ?? '—'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10.5)),
      );

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  /// 编辑自动回复预设（最多 5 条，每条 ≤200 字）。
  Future<void> _editReplyPresets(AppState st) async {
    final controllers = <TextEditingController>[
      for (final t in st.settings.effectivePresets) TextEditingController(text: t.text),
    ];
    while (controllers.length < 3) {
      controllers.add(TextEditingController());
    }

    final result = await showDialog<List<String>>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('自动回复预设'),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (c, setLocal) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < controllers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: YuanSpace.xs),
                      child: TextField(
                        controller: controllers[i],
                        maxLength: 200,
                        decoration: InputDecoration(
                          isDense: true,
                          counterText: '',
                          hintText: '预设 ${i + 1}（可用 {author} / {title}）',
                          suffixIcon: controllers.length > 1
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () {
                                    controllers.removeAt(i);
                                    setLocal(() {});
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  if (controllers.length < 5)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          controllers.add(TextEditingController());
                          setLocal(() {});
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('添加一条', style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '开启自动回复时随机取一条发送；空条不计入。',
                      style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(
              c,
              controllers.map((TextEditingController e) => e.text.trim()).toList(),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null) {
      await st.setReplyPresets(result);
    }
  }

  /// 查看自动回复 / 签到记录。
  void _showAutomationLogs(BuildContext context, AppState st) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (c, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(YuanSpace.md, 0, YuanSpace.md, YuanSpace.xxl),
          children: [
            const Text('自动回复记录', style: YuanType.titleMd),
            const SizedBox(height: YuanSpace.xs),
            if (st.replyLogs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: YuanSpace.lg),
                child: Text('暂无记录',
                    style: YuanType.bodySm.copyWith(color: YuanColors.textTertiaryLight)),
              )
            else
              for (final log in st.replyLogs.take(50))
                _logTile(
                  context,
                  ok: log.success,
                  title: '帖子 #${log.tid}',
                  body: log.sentText,
                  time: log.at,
                  error: log.error,
                ),
            const SizedBox(height: YuanSpace.lg),
            const Text('签到记录', style: YuanType.titleMd),
            const SizedBox(height: YuanSpace.xs),
            if (st.checkinLogs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: YuanSpace.lg),
                child: Text('暂无记录',
                    style: YuanType.bodySm.copyWith(color: YuanColors.textTertiaryLight)),
              )
            else
              for (final log in st.checkinLogs.take(50))
                _logTile(
                  context,
                  ok: log.success,
                  title: log.success ? '签到成功' : '签到失败',
                  body: log.message ?? '',
                  time: log.at,
                ),
          ],
        ),
      ),
    );
  }

  Widget _logTile(
    BuildContext context, {
    required bool ok,
    required String title,
    required String body,
    required DateTime time,
    String? error,
  }) {
    final Color color = ok ? YuanColors.successLight : YuanColors.dangerLight;
    return Container(
      margin: const EdgeInsets.only(bottom: YuanSpace.xs),
      padding: const EdgeInsets.all(YuanSpace.sm),
      decoration: BoxDecoration(
        color: YuanSemanticColors.of(context).surfaceContainer,
        borderRadius: BorderRadius.circular(YuanRadius.sm),
        border: Border(left: BorderSide(color: color, width: YuanSizes.replyRailWidth)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle_outline : Icons.error_outline, size: 15, color: color),
              const SizedBox(width: YuanSpace.xxs),
              Text(title, style: YuanType.titleSm.copyWith(fontSize: 13)),
              const Spacer(),
              Text(
                '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                style: YuanType.caption.copyWith(color: YuanColors.textTertiaryLight),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: YuanSpace.xxs),
            Text(body, style: YuanType.bodySm, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          if (error != null && error.isNotEmpty) ...[
            const SizedBox(height: YuanSpace.xxs),
            Text(error, style: YuanType.caption.copyWith(color: YuanColors.dangerLight)),
          ],
        ],
      ),
    );
  }


  Future<void> _editLimit(AppState st) async {
    var value = st.settings.dailyReplyLimit.toDouble();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('每日自动回复上限'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${value.round()} 条 / 天', style: const TextStyle(fontSize: 15)),
              Slider(
                value: value,
                min: 1,
                max: 50,
                divisions: 49,
                label: '${value.round()}',
                onChanged: (v) => setLocal(() => value = v),
              ),
              const Text(
                '上限用于避免账号因短时间大量回复被风控，建议不超过 20 条。',
                style: TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('保存')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await st.updateSettings((s) => s.dailyReplyLimit = value.round());
    }
  }

  Future<void> _confirmLogout(AppState st) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后将清除本机保存的登录状态，确定继续吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (ok == true) await st.logout();
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon, this.color);
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
