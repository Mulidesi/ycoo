import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/update_service.dart';
import '../../data/update_manifest.dart';
import '../../design/tokens.dart';
import '../../platform/apk_installer.dart';
import '../widgets/common.dart';

enum _Stage { checking, latest, available, downloading, ready, error }

/// 应用内更新：从 GitHub Release 获取最新 APK，
/// 下载优先走国内加速线路，完成后调起系统安装器。
class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  final _service = UpdateService();
  final _installer = ApkInstaller();

  String? _current;
  ReleaseInfo? _release;
  File? _apk;
  _Stage _stage = _Stage.checking;
  String? _error;
  int _received = 0;
  int? _total;
  bool _cancelRequested = false;
  int _lastTick = 0;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _cancelRequested = true;
    _service.close();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _stage = _Stage.checking;
      _error = null;
    });
    try {
      final current = normalizeVersion(await _installer.currentVersion());
      if (current.isEmpty || current == '—') {
        throw UpdateException('当前平台不支持应用内更新，请在 Android 设备上使用');
      }
      final release = await _service.fetchLatest();
      if (!mounted) return;
      setState(() {
        _current = current;
        _release = release;
        _stage = isNewerVersion(release.version, current)
            ? _Stage.available
            : _Stage.latest;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _downloadAndInstall() async {
    final release = _release;
    if (release == null) return;
    setState(() {
      _stage = _Stage.downloading;
      _error = null;
      _received = 0;
      _total = release.size;
      _cancelRequested = false;
      _lastTick = 0;
    });
    try {
      final file = await _service.download(
        release,
        onProgress: (received, total) {
          if (!mounted) return;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (received != total && now - _lastTick < 150) return;
          _lastTick = now;
          setState(() {
            _received = received;
            if (total != null) _total = total;
          });
        },
        isCancelled: () => _cancelRequested,
      );
      if (!mounted) return;
      setState(() {
        _apk = file;
        _stage = _Stage.ready;
        if (_total != null) _received = _total!;
      });
      await _install();
    } on UpdateCancelled {
      if (!mounted) return;
      setState(() => _stage = _Stage.available);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _install() async {
    final apk = _apk;
    if (apk == null) return;
    try {
      final allowed = await _installer.canInstallPackages();
      if (!mounted) return;
      if (!allowed) {
        await _askInstallPermission();
        return;
      }
      await _installer.install(apk);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法调起安装器：$e')),
      );
    }
  }

  Future<void> _askInstallPermission() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('需要安装权限'),
        content: const Text(
          '系统要求先允许「源坛」安装未知来源应用。\n\n'
          '安装包已下载完成，开启权限后回到本页点击「安装更新」即可。',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('去设置'),
          ),
        ],
      ),
    );
    if (go != true) return;
    try {
      await _installer.openInstallSettings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开系统设置：$e')),
      );
    }
  }

  Future<void> _openReleasePage() async {
    await launchUrl(
      Uri.parse(proxiedUrl(updateReleasePageUrl)),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final release = _release;

    return Scaffold(
      appBar: AppBar(title: const Text('检查更新')),
      body: ListView(
        padding: const EdgeInsets.all(YuanSpace.md),
        children: [
          _statusCard(theme),
          if (_stage == _Stage.latest || _stage == _Stage.error) ...[
            const SizedBox(height: YuanSpace.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _check,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(_stage == _Stage.latest ? '重新检查' : '重试'),
                  ),
                ),
                if (_stage == _Stage.error) ...[
                  const SizedBox(width: YuanSpace.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openReleasePage,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('浏览器打开'),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (release != null &&
              (_stage == _Stage.available ||
                  _stage == _Stage.downloading ||
                  _stage == _Stage.ready)) ...[
            const SizedBox(height: YuanSpace.sm),
            _releaseCard(theme, release),
            const SizedBox(height: YuanSpace.sm),
            _actionArea(theme),
          ],
          const SizedBox(height: YuanSpace.lg),
          Text(
            '安装包来自 GitHub Release，下载优先使用国内加速线路，'
            '失败时自动切换 GitHub 直连。安装前系统可能要求允许「安装未知应用」。',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11.5,
              height: 1.7,
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(ThemeData theme) {
    final semantic = YuanSemanticColors.of(context);
    final (icon, color, title, subtitle) = switch (_stage) {
      _Stage.checking => (
          Icons.sync_rounded,
          theme.colorScheme.primary,
          '正在检查更新',
          '当前版本 v${_current ?? '—'}',
        ),
      _Stage.latest => (
          Icons.check_circle_rounded,
          semantic.success,
          '已是最新版本',
          '当前版本 v${_current ?? '—'}',
        ),
      _Stage.available => (
          Icons.system_update_rounded,
          theme.colorScheme.primary,
          '发现新版本 v${_release?.version ?? ''}',
          '当前版本 v${_current ?? '—'}',
        ),
      _Stage.downloading => (
          Icons.downloading_rounded,
          theme.colorScheme.primary,
          '正在下载安装包',
          '请保持网络畅通，可随时取消',
        ),
      _Stage.ready => (
          Icons.install_mobile_rounded,
          semantic.success,
          '安装包已就绪',
          '点击「安装更新」调起系统安装器',
        ),
      _Stage.error => (
          Icons.error_outline_rounded,
          semantic.danger,
          '检查更新失败',
          _error ?? '请稍后重试',
        ),
    };

    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_stage == _Stage.checking)
            const SizedBox(
              width: 28,
              height: 28,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            Icon(icon, size: 30, color: color),
          const SizedBox(width: YuanSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    height: 1.5,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _releaseCard(ThemeData theme, ReleaseInfo release) {
    final size = release.size;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '版本 ${release.displayTag}',
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
                ),
              ),
              if (size != null && size > 0)
                Text(
                  formatBytes(size),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
          if (release.plainNotes.isNotEmpty) ...[
            const SizedBox(height: YuanSpace.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(YuanSpace.sm),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(YuanRadius.sm),
              ),
              child: SelectableText(
                release.plainNotes,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionArea(ThemeData theme) {
    if (_stage == _Stage.downloading) {
      final total = _total;
      final ratio = total != null && total > 0 ? _received / total : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(YuanRadius.pill),
            child: LinearProgressIndicator(value: ratio, minHeight: 8),
          ),
          const SizedBox(height: YuanSpace.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  total != null && total > 0
                      ? '${formatBytes(_received)} / ${formatBytes(total)} · '
                          '${(ratio! * 100).toStringAsFixed(0)}%'
                      : '已下载 ${formatBytes(_received)}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _cancelRequested = true),
                child: const Text('取消'),
              ),
            ],
          ),
        ],
      );
    }
    if (_stage == _Stage.ready) {
      return FilledButton.icon(
        onPressed: _install,
        icon: const Icon(Icons.install_mobile_rounded, size: 18),
        label: const Text('安装更新'),
      );
    }
    return FilledButton.icon(
      onPressed: _downloadAndInstall,
      icon: const Icon(Icons.download_rounded, size: 18),
      label: const Text('下载并安装'),
    );
  }
}
