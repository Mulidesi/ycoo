import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/tokens.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import 'thread_detail_page.dart';

/// 发帖页返回给入口页面的结果。
class NewThreadOutcome {
  final NewThreadResult result;
  final String subject;
  final int? fid;
  final String? boardName;

  const NewThreadOutcome({
    required this.result,
    required this.subject,
    this.fid,
    this.boardName,
  });
}

/// 发表新主题：选版块 → 选分类 → 填标题/正文。
///
/// 表单令牌与 action 全部来自站点发帖页，正文按 Discuz BBCode 提交。
class NewThreadPage extends StatefulWidget {
  const NewThreadPage({super.key, this.fid, this.boardName});

  final int? fid;
  final String? boardName;

  @override
  State<NewThreadPage> createState() => _NewThreadPageState();
}

class _NewThreadPageState extends State<NewThreadPage> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  List<BoardGroup>? _groups;
  String? _groupsError;
  bool _loadingBoards = true;

  int? _fid;
  String _boardName = '';
  PostForm? _form;
  bool _loadingForm = false;
  String? _formError;
  int _formSeq = 0;

  int? _typeId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _fid = widget.fid;
    _boardName = widget.boardName ?? '';
    _loadBoards();
    if (_fid != null) _loadForm(_fid!);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBoards() async {
    setState(() {
      _loadingBoards = true;
      _groupsError = null;
    });
    try {
      final groups = await context.read<AppState>().api.boards();
      if (!mounted) return;
      var fid = _fid;
      var name = _boardName;
      if (fid == null) {
        final first = _flatten(groups).firstOrNull;
        fid = first?.fid;
        name = first?.name ?? '';
      }
      setState(() {
        _groups = groups;
        _loadingBoards = false;
        _fid = fid;
        if (name.isNotEmpty) _boardName = name;
      });
      if (fid != null && _form == null && !_loadingForm) _loadForm(fid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _groupsError = e.toString();
        _loadingBoards = false;
      });
    }
  }

  List<Board> _flatten(List<BoardGroup> groups) => [
        for (final g in groups) ...g.boards,
      ];

  Future<void> _loadForm(int fid) async {
    final seq = ++_formSeq;
    setState(() {
      _loadingForm = true;
      _formError = null;
      _form = null;
    });
    try {
      final form = await context.read<AppState>().api.newThreadForm(fid);
      if (!mounted || seq != _formSeq || _fid != fid) return;
      setState(() {
        _form = form;
        _loadingForm = false;
      });
    } catch (e) {
      if (!mounted || seq != _formSeq || _fid != fid) return;
      setState(() {
        _formError = e.toString();
        _loadingForm = false;
      });
    }
  }

  void _selectBoard(int? fid) {
    if (fid == null || fid == _fid) return;
    final board = _groups == null
        ? null
        : _flatten(_groups!).where((b) => b.fid == fid).firstOrNull;
    setState(() {
      _fid = fid;
      _boardName = board?.name ?? '';
      _typeId = null;
      _form = null;
      _formError = null;
    });
    _loadForm(fid);
  }

  Future<void> _submit() async {
    if (_sending) return;
    final form = _form;
    if (form == null || !form.canPost) {
      _toast(form?.notice ?? '发帖表单尚未加载完成，请稍后重试');
      return;
    }
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    final titleLen = title.runes.length;
    if (titleLen < 3) {
      _toast('标题至少需要 3 个字');
      return;
    }
    if (titleLen > 100) {
      _toast('标题不能超过 100 个字');
      return;
    }
    if (body.isEmpty) {
      _toast('请填写正文');
      return;
    }

    setState(() => _sending = true);
    try {
      final res = await context.read<AppState>().api.postNewThread(
            fid: _fid!,
            subject: title,
            message: body,
            typeId: _typeId,
          );
      if (!mounted) return;
      if (res.success) {
        Navigator.of(context).pop(
          NewThreadOutcome(
            result: res,
            subject: title,
            fid: _fid,
            boardName: _boardName,
          ),
        );
        return;
      }
      _toast(res.message);
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final semantic = YuanSemanticColors.of(context);
    final theme = Theme.of(context);
    final boards = _groups == null ? const <Board>[] : _flatten(_groups!);
    final form = _form;

    return Scaffold(
      appBar: AppBar(
        title: Text(_boardName.isEmpty ? '发帖' : '发帖 · $_boardName'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          YuanSpace.pageHorizontal,
          YuanSpace.md,
          YuanSpace.pageHorizontal,
          YuanSpace.xl,
        ),
        children: [
          const _SectionLabel('版块'),
          if (_loadingBoards)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: YuanSpace.sm),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (boards.isNotEmpty)
            DropdownButtonFormField<int>(
              initialValue: _fid,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.all(Radius.circular(YuanRadius.sm)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: YuanSpace.sm,
                  vertical: YuanSpace.sm,
                ),
              ),
              items: [
                for (final g in _groups!)
                  for (final b in g.boards)
                    DropdownMenuItem(
                      value: b.fid,
                      child: Text(
                        '${g.name} · ${b.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              ],
              onChanged: _sending ? null : _selectBoard,
            )
          else
            _NoticeCard(
              text: _groupsError ?? '版块列表加载失败，请重试',
              color: semantic.danger,
              action: _loadBoards,
            ),
          if (_loadingForm)
            const Padding(
              padding: EdgeInsets.only(top: YuanSpace.md),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_formError != null)
            Padding(
              padding: const EdgeInsets.only(top: YuanSpace.md),
              child: _NoticeCard(
                text: '发帖页加载失败：$_formError',
                color: semantic.danger,
                action: () {
                  if (_fid != null) _loadForm(_fid!);
                },
              ),
            ),
          if (form != null && !form.canPost)
            Padding(
              padding: const EdgeInsets.only(top: YuanSpace.md),
              child: _NoticeCard(
                text: form.notice ?? '当前账号在该版块没有发帖权限',
                color: semantic.warning,
              ),
            ),
          if (form != null && form.categories.isNotEmpty) ...[
            const SizedBox(height: YuanSpace.lg),
            const _SectionLabel('主题分类'),
            Wrap(
              spacing: YuanSpace.xs,
              runSpacing: YuanSpace.xs,
              children: [
                ChoiceChip(
                  label: const Text('不分类'),
                  selected: _typeId == null,
                  onSelected:
                      _sending ? null : (_) => setState(() => _typeId = null),
                ),
                for (final c in form.categories)
                  ChoiceChip(
                    label: Text(c.name),
                    selected: _typeId == c.id,
                    onSelected:
                        _sending ? null : (_) => setState(() => _typeId = c.id),
                  ),
              ],
            ),
          ],
          const SizedBox(height: YuanSpace.lg),
          const _SectionLabel('标题'),
          TextField(
            controller: _titleCtrl,
            enabled: !_sending && form?.canPost == true,
            maxLength: 100,
            textInputAction: TextInputAction.next,
            style: YuanType.bodyLg,
            decoration: const InputDecoration(
              hintText: '一句话说清主题（3–100 字）',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(YuanRadius.sm)),
              ),
            ),
          ),
          const SizedBox(height: YuanSpace.sm),
          const _SectionLabel('正文'),
          TextField(
            controller: _bodyCtrl,
            enabled: !_sending && form?.canPost == true,
            minLines: 8,
            maxLines: 20,
            keyboardType: TextInputType.multiline,
            style: YuanType.bodyMd,
            decoration: const InputDecoration(
              hintText: '支持 Discuz BBCode，例如 [b]加粗[/b]、[img]图片地址[/img]',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(YuanRadius.sm)),
              ),
            ),
          ),
          const SizedBox(height: YuanSpace.md),
          Text(
            '发布前请确认已阅读版规。图片与附件请先在网页端上传，'
            '或使用 [img] 插入外链图片。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: semantic.textTertiary),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          YuanSpace.pageHorizontal,
          YuanSpace.xs,
          YuanSpace.pageHorizontal,
          YuanSpace.sm,
        ),
        child: SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _sending || form?.canPost != true ? null : _submit,
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('发布主题'),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: YuanSpace.xs),
      child: Text(text, style: YuanType.label),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text, required this.color, this.action});

  final String text;
  final Color color;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: YuanSpace.xs),
      padding: const EdgeInsets.all(YuanSpace.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(YuanRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: YuanSpace.xs),
          Expanded(
            child: Text(
              text,
              style: YuanType.bodySm.copyWith(color: color),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: action,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: YuanSpace.xs),
              ),
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }
}

/// 打开「发帖 → 查看新主题」完整流程；返回是否成功发布。
Future<bool> openNewThreadFlow(
  BuildContext context, {
  int? fid,
  String? boardName,
}) async {
  final outcome = await Navigator.of(context).push<NewThreadOutcome>(
    MaterialPageRoute<NewThreadOutcome>(
      builder: (_) => NewThreadPage(fid: fid, boardName: boardName),
    ),
  );
  if (!context.mounted || outcome == null) return false;

  final result = outcome.result;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result.message)),
  );
  final tid = result.tid;
  if (!result.pending && tid != null) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ThreadDetailPage(
          tid: tid,
          title: outcome.subject,
          fid: outcome.fid,
          boardName: outcome.boardName,
        ),
      ),
    );
  }
  return true;
}
