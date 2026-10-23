import 'package:flutter/material.dart';

import '../../data/previews.dart';
import '../../design/tokens.dart';
import '../../models/models.dart';
import 'common.dart';
import 'net_image.dart';

/// 信息流 / 版块列表的帖子卡片。
///
/// 参考主流论坛客户端的卡片结构：
///   作者行（头像 + 昵称 + 时间 + 版块标签）→ 标题 → 摘要 → 首图 → 数据行。
/// 首图与摘要来自 [preview]（移动端接口补全），没有时卡片自动收缩，
/// 不会留空白占位。
class ThreadTile extends StatelessWidget {
  const ThreadTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onAvatarTap,
    this.preview,
    this.showBoard = false,
  });

  final ThreadItem item;
  final VoidCallback onTap;
  final VoidCallback? onAvatarTap;
  final ThreadPreview? preview;
  final bool showBoard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = YuanSemanticColors.of(context);
    final muted = semantic.textTertiary;
    final hasImage = preview?.hasImage == true;
    final excerpt = preview?.excerpt;

    return Container(
      decoration: BoxDecoration(
        color: semantic.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(YuanRadius.md),
        border: Border.all(color: semantic.outlineSubtle, width: 0.9),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(YuanSpace.sm + 2, YuanSpace.sm, YuanSpace.sm + 2, YuanSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _authorRow(context, theme, muted),
                const SizedBox(height: 10),
                _title(context, theme),
                if (excerpt != null && excerpt.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: YuanType.bodySm.copyWith(height: 1.55, color: muted),
                  ),
                ],
                if (hasImage) ...[
                  const SizedBox(height: 10),
                  _thumbnail(context, theme),
                ],
                const SizedBox(height: 10),
                _stats(theme, muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _authorRow(BuildContext context, ThemeData theme, Color muted) {
    return Row(
      children: [
        Avatar(
          url: item.avatar,
          name: item.author,
          size: YuanSizes.avatarReply * 0.94,
          onTap: onAvatarTap,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.author ?? '匿名',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: YuanType.titleSm.copyWith(fontSize: 13.5, height: 1.2),
              ),
              const SizedBox(height: 3),
              Text(
                (item.timeText ?? '').isEmpty ? '—' : item.timeText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: YuanType.label.copyWith(color: muted, height: 1.2),
              ),
            ],
          ),
        ),
        if (showBoard && (item.typeName ?? '').isNotEmpty) ...[
          const SizedBox(width: 8),
          _boardChip(context, theme, item.typeName!),
        ],
      ],
    );
  }

  Widget _boardChip(BuildContext context, ThemeData theme, String label) {
    final semantic = YuanSemanticColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(YuanRadius.pill),
        border: Border.all(color: semantic.outlineSubtle),
      ),
      child: Text(
        label,
        style: YuanType.caption.copyWith(color: semantic.textSecondary, height: 1.25),
      ),
    );
  }

  Widget _title(BuildContext context, ThemeData theme) {
    final semantic = YuanSemanticColors.of(context);
    final chips = <Widget>[
      if (item.isSticky) const TagChip(label: '置顶', color: YuanColors.brandSecondaryLight),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chips.isNotEmpty) ...[
          Wrap(spacing: 6, runSpacing: 4, children: chips),
          const SizedBox(height: 6),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: YuanType.titleMd.copyWith(fontSize: 15.5, height: 1.4),
              ),
            ),
            if (item.hasAttachment) ...[
              const SizedBox(width: 6),
              Icon(Icons.attach_file_rounded, size: 15, color: semantic.textTertiary),
            ],
          ],
        ),
      ],
    );
  }

  Widget _thumbnail(BuildContext context, ThemeData theme) {
    final semantic = YuanSemanticColors.of(context);
    final count = preview?.imageCount ?? 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(YuanRadius.xs),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetImage(
              url: preview!.image!,
              fit: BoxFit.cover,
              showRetry: false,
              placeholderBuilder: (c) => Container(
                color: semantic.surfaceContainer,
              ),
              errorBuilder: (c) => Container(
                color: semantic.surfaceContainer,
                alignment: Alignment.center,
                child: Icon(Icons.image_outlined, size: 20, color: semantic.textTertiary),
              ),
            ),
            if (count > 1)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.collections_outlined, size: 11, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        '$count 图',
                        style: const TextStyle(fontSize: 10.5, color: Colors.white, height: 1.2, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stats(ThemeData theme, Color muted) {
    Widget stat(IconData icon, int value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: muted),
          const SizedBox(width: 3.5),
          Text(
            humanNumber(value),
            style: YuanType.label.copyWith(color: muted, height: 1.2),
          ),
        ],
      );
    }

    return Row(
      children: [
        stat(Icons.visibility_outlined, item.views),
        const SizedBox(width: YuanSpace.md),
        stat(Icons.mode_comment_outlined, item.replies),
        if ((preview?.likes ?? 0) > 0) ...[
          const SizedBox(width: YuanSpace.md),
          stat(Icons.thumb_up_outlined, preview!.likes),
        ],
      ],
    );
  }
}
