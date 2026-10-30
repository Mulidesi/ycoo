import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/tokens.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/emoji_panel.dart';
import '../widgets/net_image.dart';
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

/// 发帖页草稿存储键名。
class _DraftKeys {
  static const subject = 'ycoo_compose_draft_subject';
  static const message = 'ycoo_compose_draft_message';
  static const fid = 'ycoo_compose_draft_fid';
  static const at = 'ycoo_compose_draft_at';
}

/// 发帖页附件：本地读取的字节 + 上传状态 + 成功后返回的 aid。
class _DraftAttachment {
  _DraftAttachment({
    required this.name,
    required this.bytes,
    required this.isImage,
  }) : aid = null,
       uploading = false,
       error = null;

  final String name;
  final Uint8List bytes;
  final bool isImage;
  int? aid;
  bool uploading;
  String? error;
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
  final _readPermCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _mentionCtrl = TextEditingController();

  bool _replyOnly = false;
  bool _orderDesc = false;
  bool _notify = true;
  bool _useSignature = true;
  bool _showAdvanced = false;

  List<FriendItem> _mentionFriends = const <FriendItem>[];
  bool _mentionLoading = false;
  String? _mentionError;

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
  final List<_DraftAttachment> _attachments = <_DraftAttachment>[];
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _fid = widget.fid;
    _boardName = widget.boardName ?? '';
    _loadBoards();
    if (_fid != null) _loadForm(_fid!);
    _restoreDraft();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _readPermCtrl.dispose();
    _priceCtrl.dispose();
    _mentionCtrl.dispose();
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
            replyOnly: _replyOnly,
            orderDesc: _orderDesc,
            notify: _notify,
            useSignature: _useSignature,
            readPerm: _readPermCtrl.text.trim(),
            price: _priceCtrl.text.trim(),
          );
      if (!mounted) return;
      if (res.success) {
        await _clearDraft();
        if (!mounted) return;
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

  void _insertAtCursor(String text) {
    final pos = _bodyCtrl.selection;
    final base = _bodyCtrl.text;
    final newText = '${base.substring(0, pos.start)}$text${base.substring(pos.end)}';
    _bodyCtrl.value = _bodyCtrl.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: pos.start + text.length,
      ),
    );
  }

  Future<void> _showEmojiSheet() async {
    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.6,
      builder: (_) => EmojiPanel(
        onSmileySelected: _insertAtCursor,
      ),
    );
  }

  Future<void> _showMentionSheet() async {
    await GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.6,
      builder: (_) => _MentionPanel(
        friends: _mentionFriends,
        loading: _mentionLoading,
        error: _mentionError,
        controller: _mentionCtrl,
        onRefresh: _loadMentionFriends,
        onInsert: _insertMention,
      ),
    );
    if (mounted) _mentionCtrl.clear();
  }

  Future<void> _loadMentionFriends([bool force = false]) async {
    if (_mentionLoading) return;
    if (!force && _mentionFriends.isNotEmpty) return;
    setState(() {
      _mentionLoading = true;
      _mentionError = null;
    });
    try {
      final friends = await context.read<AppState>().api.fetchFriends();
      if (!mounted) return;
      setState(() {
        _mentionFriends = friends;
        _mentionLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mentionLoading = false;
        _mentionError = e.toString();
      });
    }
  }

  void _insertMention([String? selectedUsername]) {
    final name = (selectedUsername ?? _mentionCtrl.text).trim();
    if (name.isEmpty) {
      _toast('请输入要 @ 的用户名');
      return;
    }
    _insertAtCursor('@$name ');
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final subject = prefs.getString(_DraftKeys.subject) ?? '';
    final message = prefs.getString(_DraftKeys.message) ?? '';
    if (subject.trim().isEmpty && message.trim().isEmpty) return;
    final savedAt = prefs.getInt(_DraftKeys.at) ?? 0;
    if (savedAt > 0 &&
        DateTime.now().millisecondsSinceEpoch - savedAt > 7 * 24 * 3600 * 1000) {
      return;
    }
    _titleCtrl.text = subject;
    _bodyCtrl.text = message;
    final draftFid = prefs.getInt(_DraftKeys.fid);
    if (draftFid != null && _fid == null) _fid = draftFid;
    if (mounted) _toast('已恢复上次保存的草稿');
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_DraftKeys.subject, _titleCtrl.text);
    await prefs.setString(_DraftKeys.message, _bodyCtrl.text);
    await prefs.setInt(_DraftKeys.at, DateTime.now().millisecondsSinceEpoch);
    if (_fid != null) await prefs.setInt(_DraftKeys.fid, _fid!);
    _toast('草稿已保存，下次进入发帖页会自动恢复');
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_DraftKeys.subject);
    await prefs.remove(_DraftKeys.message);
    await prefs.remove(_DraftKeys.fid);
    await prefs.remove(_DraftKeys.at);
  }

  Future<void> _pickImages() async {
    final form = _form;
    if (form?.uploadhash == null || form?.uid == null) {
      _toast('上传凭证未就绪，请刷新发帖页后重试');
      return;
    }
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      imageQuality: 78,
    );
    if (picked.isEmpty) return;
    for (final file in picked) {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final attachment =
          _DraftAttachment(name: file.name, bytes: bytes, isImage: true);
      setState(() => _attachments.add(attachment));
      await _upload(attachment);
    }
  }

  Future<void> _pickFiles() async {
    final form = _form;
    if (form?.uploadhash == null || form?.uid == null) {
      _toast('上传凭证未就绪，请刷新发帖页后重试');
      return;
    }
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) _toast('${file.name} 读取失败');
        continue;
      }
      if (!mounted) return;
      final attachment =
          _DraftAttachment(name: file.name, bytes: bytes, isImage: false);
      setState(() => _attachments.add(attachment));
      await _upload(attachment);
    }
  }

  Future<void> _upload(_DraftAttachment attachment) async {
    final form = _form;
    final fid = _fid;
    if (form == null || form.uploadhash == null || form.uid == null || fid == null) return;
    final uploadHash = form.uploadhash!;
    final uid = form.uid!;
    setState(() {
      attachment.uploading = true;
      attachment.error = null;
      _uploading = true;
    });
    try {
      final aid = await context.read<AppState>().api.uploadAttachment(
        bytes: attachment.bytes,
        filename: attachment.name,
        uploadHash: uploadHash,
        uid: uid,
        fid: fid,
        image: attachment.isImage,
      );
      if (!mounted) return;
      attachment.aid = aid;
      _insertAtCursor(
        attachment.isImage
            ? '\n[attachimg]$aid[/attachimg]\n'
            : '\n[attach]$aid[/attach]\n',
      );
      setState(() => attachment.uploading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        attachment.uploading = false;
        attachment.error = e.toString();
      });
      _toast('${attachment.name} 上传失败');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
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
            decoration: InputDecoration(
              hintText: '支持 Discuz BBCode，例如 [b]加粗[/b]、[img]图片地址[/img]',
              alignLabelWithHint: true,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.alternate_email_rounded),
                    onPressed: _showMentionSheet,
                    tooltip: '@好友',
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.sentiment_satisfied_outlined),
                    onPressed: _showEmojiSheet,
                    tooltip: '表情',
                  ),
                ],
              ),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(YuanRadius.sm)),
              ),
            ),
          ),
          const SizedBox(height: YuanSpace.sm),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _uploading || _sending ? null : _pickImages,
                icon: const Icon(Icons.image_outlined),
                tooltip: '添加图片',
              ),
              IconButton.filledTonal(
                onPressed: _uploading || _sending ? null : _pickFiles,
                icon: const Icon(Icons.attach_file_outlined),
                tooltip: '添加附件',
              ),
            ],
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: YuanSpace.sm),
            ...List.generate(_attachments.length, (i) {
              return _AttachmentTile(
                attachment: _attachments[i],
                onRemove: () => _removeAttachment(i),
              );
            }),
          ],
          const SizedBox(height: YuanSpace.sm),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune_rounded, size: 22),
            title: const Text('高级选项'),
            trailing: Icon(
              _showAdvanced ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            ),
            onTap: _sending
                ? null
                : () => setState(() => _showAdvanced = !_showAdvanced),
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: YuanSpace.xs),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('回帖仅作者可见'),
              value: _replyOnly,
              onChanged: _sending
                  ? null
                  : (v) => setState(() => _replyOnly = v),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('回帖倒序排列'),
              value: _orderDesc,
              onChanged: _sending
                  ? null
                  : (v) => setState(() => _orderDesc = v),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('接收回复通知'),
              value: _notify,
              onChanged: _sending
                  ? null
                  : (v) => setState(() => _notify = v),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('使用个人签名'),
              value: _useSignature,
              onChanged: _sending
                  ? null
                  : (v) => setState(() => _useSignature = v),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: YuanSpace.xs,
                horizontal: YuanSpace.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _readPermCtrl,
                      enabled: !_sending,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '阅读权限',
                        hintText: '0 为不限制',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(YuanRadius.xs),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: YuanSpace.sm),
                  Expanded(
                    child: TextField(
                      controller: _priceCtrl,
                      enabled: !_sending,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '售价（金币）',
                        hintText: '0 为免费',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(YuanRadius.xs),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: YuanSpace.md),
          Text(
            '发布前请确认已阅读版规。支持 BBCode：[b]加粗[/b]、[img]图片[/img]。',
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
          child: Row(
            children: [
              TextButton(
                onPressed: _sending ? null : _saveDraft,
                child: const Text('保存草稿'),
              ),
              const SizedBox(width: YuanSpace.sm),
              Expanded(
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
            ],
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

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment, required this.onRemove});

  final _DraftAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final semantic = YuanSemanticColors.of(context);
    final statusText = attachment.uploading
        ? '上传中…'
        : attachment.error != null
            ? attachment.error!
            : attachment.aid != null
                ? '已上传（ID: ${attachment.aid}）'
                : '待上传';
    final statusColor = attachment.uploading
        ? semantic.brandPrimary
        : attachment.error != null
            ? semantic.danger
            : semantic.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: YuanSpace.sm,
        vertical: YuanSpace.xs,
      ),
      decoration: BoxDecoration(
        color: semantic.surfaceContainer,
        borderRadius: BorderRadius.circular(YuanRadius.xs),
        border: Border.all(color: semantic.outlineSubtle, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            attachment.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
            size: 18,
            color: semantic.textSecondary,
          ),
          const SizedBox(width: YuanSpace.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: YuanType.bodySm,
                ),
                Text(
                  statusText,
                  style: YuanType.caption.copyWith(color: statusColor),
                ),
              ],
            ),
          ),
          if (attachment.uploading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
              tooltip: '移除',
            ),
        ],
      ),
    );
  }
}

class _MentionPanel extends StatefulWidget {
  const _MentionPanel({
    required this.friends,
    required this.loading,
    required this.error,
    required this.controller,
    required this.onRefresh,
    required this.onInsert,
  });

  final List<FriendItem> friends;
  final bool loading;
  final String? error;
  final TextEditingController controller;
  final Future<void> Function([bool]) onRefresh;
  final void Function([String?]) onInsert;

  @override
  State<_MentionPanel> createState() => _MentionPanelState();
}

class _MentionPanelState extends State<_MentionPanel> {
  @override
  Widget build(BuildContext context) {
    final semantic = YuanSemanticColors.of(context);
    final keyword = widget.controller.text.trim().toLowerCase();
    final visible = widget.friends
        .where((f) => keyword.isEmpty ||
            f.username.toLowerCase().contains(keyword))
        .take(12)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        YuanSpace.pageHorizontal,
        YuanSpace.sm,
        YuanSpace.pageHorizontal,
        YuanSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => widget.onInsert(),
                  decoration: const InputDecoration(
                    hintText: '搜索好友或输入用户名',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(YuanRadius.xs),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: YuanSpace.xs),
              FilledButton(
                onPressed: widget.onInsert,
                child: const Text('@添加'),
              ),
            ],
          ),
          const SizedBox(height: YuanSpace.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  '选择好友可快速插入 @用户名；也可以手动输入。',
                  style: YuanType.caption.copyWith(color: semantic.textTertiary),
                ),
              ),
              IconButton(
                tooltip: '刷新好友',
                visualDensity: VisualDensity.compact,
                onPressed: widget.loading
                    ? null
                    : () => widget.onRefresh(true),
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          if (widget.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: YuanSpace.sm),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (widget.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: YuanSpace.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.error!,
                      style: YuanType.caption.copyWith(color: semantic.danger),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onRefresh(true),
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: YuanSpace.sm),
              child: Text(
                widget.friends.isEmpty
                    ? '暂未读取到好友；可直接输入用户名后点击「@添加」。'
                    : '没有匹配的好友；仍可直接 @ 添加。',
                style: YuanType.caption.copyWith(color: semantic.textTertiary),
              ),
            )
          else
            ...visible.map((friend) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 17,
                  backgroundColor: semantic.surfaceContainer,
                  child: friend.avatar.isEmpty
                      ? Icon(Icons.person_outline,
                          size: 18, color: semantic.textTertiary)
                      : ClipOval(
                          child: NetImage(
                            url: friend.avatar,
                            width: 34,
                            height: 34,
                            errorBuilder: (_) => Icon(
                              Icons.person_outline,
                              size: 18,
                              color: semantic.textTertiary,
                            ),
                          ),
                        ),
                ),
                title: Text(
                  friend.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: YuanType.bodySm,
                ),
                subtitle: friend.note.isEmpty
                    ? null
                    : Text(
                        friend.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: YuanType.caption,
                      ),
                trailing: const Icon(Icons.alternate_email, size: 18),
                onTap: () => widget.onInsert(friend.username),
              );
            }),
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
