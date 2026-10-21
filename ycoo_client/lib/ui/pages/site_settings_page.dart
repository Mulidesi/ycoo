import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/site_config.dart';
import '../../design/tokens.dart';
import '../../state/app_state.dart';

/// 站点与网络设置。
///
/// 论坛有两个域名（ycoo.net 主站 / pc.sysbbs.com 备用），
/// 这里提供：主域名切换（带确认，切换后需重新登录）与逐域名访问测试。
class SiteSettingsPage extends StatefulWidget {
  const SiteSettingsPage({super.key});

  @override
  State<SiteSettingsPage> createState() => _SiteSettingsPageState();
}

class _SiteSettingsPageState extends State<SiteSettingsPage> {
  /// 每个站点的测试结果：null=未测试，true/false=可用/不可用，附带延迟
  final Map<String, (bool, int)?> _probeResults = {};
  final Set<String> _probing = {};

  Future<void> _probe(ForumSite site) async {
    setState(() => _probing.add(site.id));
    final st = context.read<AppState>();
    final (ms, ok) = await st.probeSite(site);
    if (!mounted) return;
    setState(() {
      _probing.remove(site.id);
      _probeResults[site.id] = (ok, ms);
    });
  }

  Future<void> _switchTo(ForumSite site) async {
    final st = context.read<AppState>();
    if (st.settings.siteId == site.id) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('切换主域名'),
        content: Text(
          '将主域名切换为 ${site.origin}\n\n'
          '两个域名的登录状态相互独立，切换后需要重新登录。',
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('切换')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await st.switchSite(site.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('主域名已切换为 ${site.origin}，请重新登录')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = context.watch<AppState>();
    final clipboardOn = st.settings.clipboardDetect;

    return Scaffold(
      appBar: AppBar(title: const Text('站点与网络')),
      body: ListView(
        padding: const EdgeInsets.all(YuanSpace.md),
        children: [
          Text('主域名', style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.outline)),
          const SizedBox(height: 8),
          for (final site in ForumSite.all) _siteTile(theme, st, site),
          const SizedBox(height: 16),
          Text('通用', style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.outline)),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              value: clipboardOn,
              onChanged: (v) => st.updateSettings((s) => s.clipboardDetect = v),
              title: const Text('剪贴板链接识别', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: const Text('复制了论坛帖子 / 版块链接后回到 APP 时，询问是否直接打开', style: TextStyle(fontSize: 11.5)),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(YuanRadius.sm),
            ),
            child: Text(
              '说明：ycoo.net 与 pc.sysbbs.com 数据互通，但登录状态按域名独立保存。'
              '当主域名访问异常时，可先「测试」确认哪个域名可用，再切换。',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _siteTile(ThemeData theme, AppState st, ForumSite site) {
    final isCurrent = st.settings.siteId == site.id;
    final probing = _probing.contains(site.id);
    final result = _probeResults[site.id];
    final semantic = YuanSemanticColors.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: RadioListTile<String>(
        value: site.id,
        groupValue: st.settings.siteId,
        onChanged: (_) => _switchTo(site),
        title: Text(
          '${site.name}${isCurrent ? '（当前）' : ''}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(site.origin, style: const TextStyle(fontSize: 12)),
            if (result != null) ...[
              const SizedBox(height: 4),
              Text(
                result.$1 ? '可用 · ${result.$2} ms' : '不可用（请求失败或超时）',
                style: TextStyle(
                  fontSize: 11.5,
                  color: result.$1 ? Colors.green.shade600 : semantic.danger,
                ),
              ),
            ],
          ],
        ),
        isThreeLine: true,
        secondary: OutlinedButton(
          onPressed: probing ? null : () => _probe(site),
          child: probing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('测试', style: TextStyle(fontSize: 12.5)),
        ),
      ),
    );
  }
}
