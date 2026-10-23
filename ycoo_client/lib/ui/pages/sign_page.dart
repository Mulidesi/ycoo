import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/tokens.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';

class SignPage extends StatefulWidget {
  const SignPage({super.key});

  @override
  State<SignPage> createState() => _SignPageState();
}

class _SignPageState extends State<SignPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadSignStatus();
    });
  }

  Future<void> _sign() async {
    final st = context.read<AppState>();
    final res = await st.signNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? YuanColors.successLight : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final st = context.watch<AppState>();
    final s = st.signStatus;

    return Scaffold(
      appBar: AppBar(title: const Text('每日签到')),
      body: RefreshIndicator(
        onRefresh: st.loadSignStatus,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(YuanSpace.md, YuanSpace.xs, YuanSpace.md, YuanSpace.xxl),
          children: [
            _hero(theme, st, s),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    theme,
                    icon: Icons.local_fire_department_rounded,
                    color: YuanColors.brandTertiaryLight,
                    label: '连续签到',
                    value: '${s?.streakDays ?? 0}',
                    unit: '天',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    theme,
                    icon: Icons.people_alt_rounded,
                    color: YuanColors.brandPrimaryLight,
                    label: '今日签到',
                    value: s == null ? '—' : humanNumber(s.todayCount),
                    unit: '人',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 17, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      const Text('自动签到', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Switch(
                        value: st.settings.autoSign,
                        onChanged: (v) async {
                          await st.updateSettings((x) => x.autoSign = v);
                          if (v) {
                            final r = await st.autoSignIfNeeded(force: true);
                            if (!context.mounted) return;
                            if (r != null) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(r.message)));
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '开启后，每次启动 App 或回到前台会自动完成签到（每天一次）。'
                    '${st.lastSignAt != null ? '\n上次签到：${_fmt(st.lastSignAt!)}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.6,
                      fontSize: 12,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('签到说明', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    '· 每天签到可获得随机星币奖励，连续签到天数越多奖励越高\n'
                    '· 签到数据来自源论坛 k_misign 插件，与网页端完全同步\n'
                    '· 若提示登录失效，请退出后重新登录',
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.8,
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.month}月${d.day}日 ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _hero(ThemeData theme, AppState st, SignStatus? s) {
    final signed = s?.signedToday ?? false;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: signed
              ? [YuanColors.successLight, YuanColors.brandSecondaryLight]
              : [YuanColors.brandDeepLight, YuanColors.brandPrimaryLight],
        ),
        borderRadius: BorderRadius.circular(YuanRadius.lg),
        boxShadow: [
          BoxShadow(
            color: (signed ? YuanColors.brandSecondaryLight : YuanColors.brandPrimaryLight).withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                signed ? Icons.verified_rounded : Icons.wb_sunny_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 7),
              Text(
                signed ? '今日已签到' : '今天还没有签到',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                st.user?.username ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${s?.streakDays ?? 0}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 46,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 6, bottom: 6),
                child: Text('天连续签到', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ],
          ),
          if (s?.rewardText != null) ...[
            const SizedBox(height: 8),
            Text(s!.rewardText!, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (signed || st.signing) ? null : _sign,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: signed ? Colors.grey : YuanColors.brandDeepLight,
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white70,
                minimumSize: const Size(0, 48),
              ),
              child: st.signing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(signed ? '今天已签到' : '立即签到'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(YuanRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: theme.colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1)),
              const SizedBox(width: 3),
              Text(unit, style: TextStyle(fontSize: 11.5, color: theme.colorScheme.outline)),
            ],
          ),
        ],
      ),
    );
  }
}
