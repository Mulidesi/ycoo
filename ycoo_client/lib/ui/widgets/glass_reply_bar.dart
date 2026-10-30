/// 帖子详情页底部的悬浮液态玻璃回复栏。
///
/// 纯展示组件：文本、展开态、点赞/收藏状态均由详情页持有，
/// 组件只负责玻璃容器、输入框与按钮的排版和动效。
///
/// 收起态：单行输入胶囊 + 点赞 / 收藏 / 分享；
/// 展开态：多行输入 + 同一组操作 + 右下角「发布」；玻璃层始终只有 1 层。
library;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../design/tokens.dart';

class GlassReplyBar extends StatefulWidget {
  const GlassReplyBar({
    super.key,
    required this.controller,
    required this.expanded,
    required this.onExpandedChanged,
    required this.onSend,
    required this.onLike,
    required this.onFavorite,
    required this.onShare,
    this.liked = false,
    this.favorited = false,
    this.sending = false,
    this.busy = false,
    this.replyTargetPid,
    this.replyTargetAuthor,
    this.onReplyTargetCleared,
  });

  final TextEditingController controller;

  /// 是否展开为多行输入（由详情页持有，便于失焦/发送后统一收起）。
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  /// 点击「发布」。
  final VoidCallback onSend;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onShare;

  final bool liked;
  final bool favorited;
  final bool sending;

  /// 点赞 / 收藏 / 分享请求进行中：禁用对应按钮。
  final bool busy;

  /// 回复目标楼层信息（展开态显示提示条）。
  final int? replyTargetPid;
  final String? replyTargetAuthor;
  final VoidCallback? onReplyTargetCleared;

  @override
  State<GlassReplyBar> createState() => _GlassReplyBarState();
}

class _GlassReplyBarState extends State<GlassReplyBar> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant GlassReplyBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded && !oldWidget.expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.expanded) _focus.requestFocus();
      });
    }
    if (!widget.expanded && oldWidget.expanded) {
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  /// 键盘收起且没有草稿时自动回到收起态；有草稿则保留展开，避免丢内容。
  void _onFocusChanged() {
    if (_focus.hasFocus || !widget.expanded) return;
    if (widget.controller.text.trim().isNotEmpty) return;
    widget.onExpandedChanged(false);
  }

  void _expand() {
    widget.onExpandedChanged(true);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = YuanSemanticColors.of(context);
    final disableAnim = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          YuanGlass.replyBarMargin,
          0,
          YuanGlass.replyBarMargin,
          YuanGlass.replyBarMargin,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GlassContainer(
            shape: LiquidRoundedSuperellipse(
              borderRadius:
                  widget.expanded ? YuanRadius.lg : YuanRadius.pill,
            ),
            settings: LiquidGlassSettings(
              glassColor: semantic.glassFill,
              blur: YuanGlass.blur,
              thickness: YuanGlass.thickness,
            ),
            useOwnLayer: true,
            child: AnimatedSize(
              duration: disableAnim ? Duration.zero : YuanMotion.normal,
              curve: YuanMotion.standard,
              alignment: Alignment.bottomCenter,
              child: widget.expanded
                  ? _expanded(theme, semantic)
                  : _collapsed(theme, semantic),
            ),
          ),
        ),
      ),
    );
  }

  /// 收起态：假输入框（只负责触发展开），点击整条胶囊即可输入。
  Widget _collapsed(ThemeData theme, YuanSemanticColors semantic) {
    return SizedBox(
      height: YuanGlass.replyBarCollapsedHeight,
      child: Row(
        children: [
          const SizedBox(width: YuanSpace.xs),
          Expanded(
            child: Material(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.55),
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _expand,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: YuanSpace.sm,
                    vertical: YuanSpace.xs,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: semantic.textSecondary,
                      ),
                      const SizedBox(width: YuanSpace.xs),
                      Expanded(
                        child: Text(
                          '写评论…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: YuanType.bodyMd.copyWith(
                            color: semantic.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: YuanSpace.xxs),
          _actions(semantic, iconOnly: true),
          const SizedBox(width: YuanSpace.xs),
        ],
      ),
    );
  }

  /// 展开态：多行输入 + 操作区 + 右下角发布。
  Widget _expanded(ThemeData theme, YuanSemanticColors semantic) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: YuanGlass.replyBarExpandedMinHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          YuanSpace.md,
          YuanSpace.sm,
          YuanSpace.xs,
          YuanSpace.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.replyTargetPid != null && widget.replyTargetAuthor != null)
              Padding(
                padding: const EdgeInsets.only(bottom: YuanSpace.xxs),
                child: Row(
                  children: [
                    Icon(Icons.reply_rounded, size: 14, color: semantic.brandPrimary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '回复 @${widget.replyTargetAuthor} · ${widget.replyTargetPid}楼',
                        style: YuanType.caption.copyWith(color: semantic.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.onReplyTargetCleared != null)
                      InkWell(
                        onTap: widget.onReplyTargetCleared,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            '取消',
                            style: YuanType.caption.copyWith(color: semantic.textTertiary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            TextField(
              key: const ValueKey('glass-reply-input'),
              controller: widget.controller,
              focusNode: _focus,
              autofocus: false,
              minLines: 3,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: YuanType.bodyMd.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              cursorColor: semantic.brandPrimary,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '写评论…',
                hintStyle: YuanType.bodyMd.copyWith(
                  color: semantic.textSecondary,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: YuanSpace.xxs,
                  vertical: YuanSpace.xs,
                ),
              ),
            ),
            const SizedBox(height: YuanSpace.xxs),
            Row(
              children: [
                _actions(semantic, iconOnly: false),
                const Spacer(),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (context, value, _) {
                    final canSend = value.text.trim().isNotEmpty;
                    return FilledButton(
                      key: const ValueKey('glass-reply-send'),
                      onPressed:
                          canSend && !widget.sending ? widget.onSend : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(72, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: YuanSpace.md,
                        ),
                        visualDensity: VisualDensity.compact,
                        shape: const StadiumBorder(),
                      ),
                      child: widget.sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('发布'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 点赞 / 收藏 / 分享。`iconOnly` 时用圆形玻璃按钮（收起态）。
  Widget _actions(YuanSemanticColors semantic, {required bool iconOnly}) {
    final size = iconOnly ? 40.0 : 36.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassIconButton(
          key: const ValueKey('glass-reply-like'),
          icon: Icon(
            widget.liked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
            size: 18,
            color: widget.liked ? semantic.brandPrimary : semantic.textSecondary,
          ),
          semanticLabel: widget.liked ? '取消支持' : '支持本帖',
          size: size,
          onPressed: widget.busy ? null : widget.onLike,
          glowColor: semantic.brandPrimary,
        ),
        GlassIconButton(
          key: const ValueKey('glass-reply-favorite'),
          icon: Icon(
            widget.favorited ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            size: 19,
            color:
                widget.favorited ? semantic.brandPrimary : semantic.textSecondary,
          ),
          semanticLabel: widget.favorited ? '已收藏' : '收藏本帖',
          size: size,
          onPressed: widget.busy ? null : widget.onFavorite,
          glowColor: semantic.brandPrimary,
        ),
        GlassIconButton(
          key: const ValueKey('glass-reply-share'),
          icon: Icon(
            Icons.ios_share_rounded,
            size: 18,
            color: semantic.textSecondary,
          ),
          semanticLabel: '分享本帖',
          size: size,
          onPressed: widget.onShare,
        ),
      ],
    );
  }
}
