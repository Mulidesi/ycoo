import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/tokens.dart';
import '../../state/app_state.dart';

/// 帖子标题关键词过滤设置。
///
/// 默认过滤「打卡」类无效帖；关键词由用户增删，保存后立即作用于
/// 首页信息流、版块列表与搜索结果。
class PostFilterPage extends StatefulWidget {
  const PostFilterPage({super.key});

  @override
  State<PostFilterPage> createState() => _PostFilterPageState();
}

class _PostFilterPageState extends State<PostFilterPage> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _saveKeywords(AppState st, List<String> next) async {
    await st.updateSettings((s) {
      s.postFilterKeywords = AppSettings.sanitizePostFilterKeywords(next);
    });
  }

  Future<void> _add(AppState st) async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    if (text.length > 30) {
      _toast('单个关键词最多 30 个字');
      return;
    }
    final exists = st.settings.postFilterKeywords
        .any((k) => k.toLowerCase() == text.toLowerCase());
    if (exists) {
      _toast('这个关键词已经在列表里了');
      return;
    }
    if (st.settings.postFilterKeywords.length >= 50) {
      _toast('最多添加 50 个关键词');
      return;
    }
    await _saveKeywords(st, [...st.settings.postFilterKeywords, text]);
    if (!mounted) return;
    _ctrl.clear();
  }

  Future<void> _remove(AppState st, String keyword) async {
    await _saveKeywords(
      st,
      st.settings.postFilterKeywords.where((k) => k != keyword).toList(),
    );
  }

  Future<void> _reset(AppState st) async {
    await _saveKeywords(st, AppSettings.defaultPostFilterKeywords);
    if (!mounted) return;
    _toast('已恢复默认关键词');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = context.watch<AppState>();
    final semantic = YuanSemanticColors.of(context);
    final keywords = st.settings.postFilterKeywords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('帖子关键词过滤'),
        actions: [
          TextButton(
            onPressed: () => _reset(st),
            child: const Text('恢复默认'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(YuanSpace.md),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              value: st.settings.postFilterEnabled,
              onChanged: (v) => st.updateSettings((s) => s.postFilterEnabled = v),
              title: const Text(
                '启用关键词过滤',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                '标题命中关键词的帖子会在首页、版块和搜索结果中隐藏',
                style: TextStyle(fontSize: 11.5),
              ),
            ),
          ),
          const SizedBox(height: YuanSpace.lg),
          Text(
            '过滤关键词',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.outline,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: YuanSpace.xs),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textInputAction: TextInputAction.done,
                  maxLength: 30,
                  onSubmitted: (_) => _add(st),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: '例如：打卡',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(YuanRadius.sm),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: YuanSpace.xs),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: () => _add(st),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('添加'),
                ),
              ),
            ],
          ),
          const SizedBox(height: YuanSpace.md),
          if (keywords.isEmpty)
            Container(
              padding: const EdgeInsets.all(YuanSpace.sm),
              decoration: BoxDecoration(
                color: semantic.surfaceContainer,
                borderRadius: BorderRadius.circular(YuanRadius.sm),
              ),
              child: Text(
                '尚未添加关键词，当前不会隐藏任何帖子。',
                style: YuanType.bodySm.copyWith(color: semantic.textTertiary),
              ),
            )
          else
            Wrap(
              spacing: YuanSpace.xs,
              runSpacing: YuanSpace.xs,
              children: [
                for (final k in keywords)
                  InputChip(
                    label: Text(k),
                    onDeleted: () => _remove(st, k),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  ),
              ],
            ),
          const SizedBox(height: YuanSpace.lg),
          Container(
            padding: const EdgeInsets.all(YuanSpace.sm),
            decoration: BoxDecoration(
              color: semantic.surfaceContainerHigh.withOpacity(0.5),
              borderRadius: BorderRadius.circular(YuanRadius.sm),
            ),
            child: Text(
              '只匹配帖子标题，不检查正文；不区分大小写。'
              '关键词保存后立即生效，已过滤的帖子不会从服务器删除。',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                height: 1.7,
                color: semantic.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
