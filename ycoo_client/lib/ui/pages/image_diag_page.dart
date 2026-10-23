import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/image_loader.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/net_image.dart';

/// 图片加载诊断：逐个探测站内头像、附件图、SVG 头像、外链图床，
/// 把 HTTP 状态 / 字节数 / 解码尺寸 / 耗时都摊开，便于定位是哪一层出的问题。
class ImageDiagPage extends StatefulWidget {
  const ImageDiagPage({super.key});

  @override
  State<ImageDiagPage> createState() => _ImageDiagPageState();
}

class _DiagItem {
  final String label;
  final String url;
  _DiagItem(this.label, this.url);

  String? status;
  String? detail;
  bool ok = false;
  bool running = false;
}

class _ImageDiagPageState extends State<ImageDiagPage> {
  late final List<_DiagItem> _items = [
    _DiagItem('站内头像', 'https://ycoo.net/data/avatar/000/00/00/01_avatar_middle.jpg'),
    _DiagItem('站内附件图', 'https://ycoo.net/data/attachment/common/template/boardimg_20241216d6f4lsl6.png'),
    _DiagItem('默认头像(SVG)', 'https://ycoo.net/data/avatar/noavatar.svg'),
    _DiagItem('外链图床', 'https://s1.imagehub.cc/images/2026/10/19/6540aa703c836608a8b8e737ff34f2a2.jpg'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAll());
  }

  Future<void> _runAll() async {
    for (final item in _items) {
      if (!mounted) return;
      setState(() {
        item.running = true;
        item.status = null;
        item.detail = null;
        item.ok = false;
      });
      final sw = Stopwatch()..start();
      try {
        final bytes = await DiscuzImageProvider(item.url).fetchBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final w = frame.image.width;
        final h = frame.image.height;
        frame.image.dispose();
        codec.dispose();
        if (!mounted) return;
        setState(() {
          item.ok = true;
          item.status = '正常';
          item.detail = '${_size(bytes.length)} · ${w}x$h · ${sw.elapsedMilliseconds}ms';
          item.running = false;
        });
      } on ImageFetchException catch (e) {
        if (!mounted) return;
        setState(() {
          item.status = e.status == null ? '失败' : 'HTTP ${e.status}';
          item.detail = '${e.message} · ${sw.elapsedMilliseconds}ms';
          item.running = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          item.status = '失败';
          item.detail = '$e · ${sw.elapsedMilliseconds}ms';
          item.running = false;
        });
      }
    }
  }

  String _size(int bytes) =>
      bytes > 1024 ? '${(bytes / 1024).toStringAsFixed(1)} KB' : '$bytes B';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = context.watch<AppState>();
    final hasCookie = st.client.cookieHeader.isNotEmpty;
    final okCount = _items.where((e) => e.ok).length;
    final done = _items.where((e) => !e.running).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('图片加载诊断'),
        actions: [
          IconButton(
            tooltip: '重新检测',
            onPressed: _runAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('检测结果 $okCount / ${_items.length}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  '已检测 $done 项。若「站内头像」正常但「外链图床」失败，'
                  '说明是图床域名在当前网络下不可达（需要代理）；'
                  '若全部 HTTP 403/404，多为防盗链或附件权限问题。',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      hasCookie ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                      size: 14,
                      color: hasCookie ? theme.colorScheme.primary : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasCookie ? '已带登录态 Cookie 请求' : '未登录，按游客身份请求',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final item in _items) ...[
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.label,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              item.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (item.running)
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        TagChip(
                          label: item.status ?? '待检测',
                          color: item.ok
                              ? const Color(0xFF16A34A)
                              : (item.status == null ? theme.colorScheme.outline : const Color(0xFFDC2626)),
                        ),
                    ],
                  ),
                  if (item.detail != null) ...[
                    const SizedBox(height: 6),
                    Text(item.detail!, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5)),
                  ],
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 90,
                      width: double.infinity,
                      child: NetImage(
                        url: item.url,
                        fit: BoxFit.contain,
                        errorBuilder: (c) => Container(
                          alignment: Alignment.center,
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          child: Text('这张图渲染失败', style: theme.textTheme.bodySmall),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
