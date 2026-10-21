// ignore_for_file: avoid_print
import 'dart:io';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as hp;
import 'package:ycoo_client/data/content.dart';

/// 统计「图片被包在块级标签里」的数量：旧渲染器只处理顶层 img，这些都会被丢掉。
int nestedImages(dom.Element pm) {
  const blocks = {
    'div', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li',
    'table', 'tbody', 'thead', 'tr', 'td', 'th', 'section', 'article',
    'center', 'fieldset', 'dl', 'dt', 'dd', 'blockquote', 'pre',
  };
  var n = 0;
  for (final img in pm.querySelectorAll('img')) {
    dom.Node? p = img.parent;
    var found = false;
    while (p != null && p != pm) {
      if (p is dom.Element && blocks.contains(p.localName)) {
        found = true;
        break;
      }
      p = p.parent;
    }
    if (found) n++;
  }
  return n;
}

void main(List<String> args) {
  final dir = Directory(args.isNotEmpty ? args[0] : '../recon');
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.html'));

  var checked = 0;
  var fail = 0;
  for (final f in files) {
    final doc = hp.parse(f.readAsStringSync());
    final pm = doc.querySelector('[id^="postmessage_"]');
    if (pm == null) continue;
    checked++;

    // 与渲染器一致：去掉编辑痕迹 / 注册提示，保留 locked 提示
    pm.querySelectorAll('.pstatus, .attach_nopermission').forEach((e) => e.remove());
    // 渲染器会剔除 script/style（正文里常有 replyreload 等 JS），基准文本同样剔除
    pm.querySelectorAll('script, style').forEach((e) => e.remove());
    final src = pm.innerHtml;
    final raw = pm.text.replaceAll(RegExp(r'\s+'), '');

    final blocks = parsePostContent(src, showLockedHint: true);
    final got = contentPlainText(blocks).replaceAll(RegExp(r'\s+'), '');

    final imgInPm = pm.querySelectorAll('img').where((i) {
      final s = (i.attributes['src'] ?? '') + (i.attributes['file'] ?? '');
      return !s.contains('smiley') && !s.contains('none.gif') && !s.contains('attachimg.gif');
    }).length;
    final imgInBlocks = blocks.where((b) => b.kind == BlockKind.image).length;
    final nested = nestedImages(pm);

    final ok = got == raw;
    if (!ok) fail++;
    print('${ok ? "OK  " : "FAIL"} ${f.path.split(RegExp(r"[\\/]")).last.padRight(22)} '
        'text ${got.length}/${raw.length}  img $imgInBlocks/$imgInPm  '
        'nestedImg(旧版会丢)=$nested  blocks=${blocks.length}');
    if (!ok) {
      var i = 0;
      while (i < got.length && i < raw.length && got[i] == raw[i]) {
        i++;
      }
      print('      首个差异 @$i');
      print('      raw: ${raw.substring(i > 30 ? i - 30 : 0, (i + 60).clamp(0, raw.length))}');
      print('      got: ${got.substring(i > 30 ? i - 30 : 0, (i + 60).clamp(0, got.length))}');
    }
  }
  print('\n共检查 $checked 个页面，文本不一致 $fail 个');
}
