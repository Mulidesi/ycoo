import 'package:flutter/material.dart';

import '../../data/parsers.dart' show kBaseUrl;
import '../../data/smilies.dart';
import '../../design/tokens.dart';
import 'net_image.dart';

/// 官方表情面板。
///
/// 三套表情通过 TabBar 切换，GridView 展示 8 列；
/// 图片走 `NetImage` 自动带登录态与防盗链降级，
/// 加载失败时回退为表情代码文本（站点未配置表情图时仍可插入代码）。
/// 点击表情时通过 [onSmileySelected] 回调插入 BBCode。
class EmojiPanel extends StatefulWidget {
  const EmojiPanel({super.key, required this.onSmileySelected});

  final ValueChanged<String> onSmileySelected;

  @override
  State<EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<EmojiPanel> {
  int _setIndex = 0;

  @override
  Widget build(BuildContext context) {
    final semantic = YuanSemanticColors.of(context);
    return Column(
      children: [
        TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          onTap: (index) => setState(() => _setIndex = index),
          tabs: List.generate(kSmileySets.length, (i) {
            return Tab(text: kSmileySets[i].name);
          }),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(YuanSpace.sm),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: YuanSpace.sm,
              crossAxisSpacing: YuanSpace.sm,
              childAspectRatio: 1.1,
            ),
            itemCount: kSmileySets[_setIndex].items.length,
            itemBuilder: (_, index) => _SmileyTile(
              smiley: kSmileySets[_setIndex].items[index],
              dir: kSmileySets[_setIndex].dir,
              onTap: widget.onSmileySelected,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(YuanSpace.sm),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${kSmileySets[_setIndex].items.length} 个表情',
              style: YuanType.caption.copyWith(color: semantic.textTertiary),
            ),
          ),
        ),
      ],
    );
  }
}

class _SmileyTile extends StatelessWidget {
  const _SmileyTile({
    required this.smiley,
    required this.dir,
    required this.onTap,
  });

  final ForumSmiley smiley;
  final String dir;
  final ValueChanged<String> onTap;

  String get _url => '$kBaseUrl/static/image/smiley/$dir/${smiley.file}';

  @override
  Widget build(BuildContext context) {
    final semantic = YuanSemanticColors.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      decoration: BoxDecoration(
        color: semantic.surfaceContainer,
        borderRadius: BorderRadius.circular(YuanRadius.xs),
        border: Border.all(color: semantic.outlineSubtle, width: 0.5),
      ),
      child: InkWell(
        onTap: () => onTap(smiley.code),
        borderRadius: BorderRadius.circular(YuanRadius.xs),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(YuanRadius.xs),
          child: NetImage(
            url: _url,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
            showRetry: false,
            errorBuilder: (_) => _SmileyError(smiley: smiley),
          ),
        ),
      ),
    );
  }
}

class _SmileyError extends StatelessWidget {
  const _SmileyError({required this.smiley});

  final ForumSmiley smiley;

  @override
  Widget build(BuildContext context) {
    final semantic = YuanSemanticColors.of(context);
    return Center(
      child: Text(
        smiley.code,
        style: TextStyle(
          fontSize: 10,
          color: semantic.textTertiary,
        ),
      ),
    );
  }
}
