// ignore_for_file: avoid_print

/// 合成 pattl 结构验证纯文件附件提取。
library;

import 'package:html/parser.dart' as html_parser;
import 'package:ycoo_client/data/parsers.dart';

void main() {
  const pattl = '''
<div class="pattl"><ignore_js_op><dl class="tattl attm"><dt></dt><dd>
<p class="mbn"><a href="forum.php?mod=attachment&amp;aid=MTkxOTMxfDE3OTI0NTA3ODZ8MzE5ODF8MTUyNTQ1&amp;nothumb=yes" class="xw1" target="_blank">源码包 v1.2.zip</a>
<em class="xg1">(3.42 MB, 下载次数: 12)</em></p>
</dd><dd>
<p class="mbn"><a href="forum.php?mod=attachment&amp;aid=MTkxOTMyfDE3OTI0NTA3ODZ8MzE5ODF8MTUyNTQ1&amp;nothumb=yes" class="xw1" target="_blank">说明文档.pdf</a>
<em class="xg1">(220.5 KB, 下载次数: 3)</em></p>
</dd></dl></ignore_js_op></div>''';
  final doc = html_parser.parse('<html><body><div id="post_2949591"><div class="pct"><div id="postmessage_2949591">正文</div></div>$pattl</div></body></html>');
  final d = parseThread(doc.documentElement!.outerHtml, tid: 1, page: 1);
  final p = d.posts.first;
  print('atts=${p.attachments.length}');
  for (final a in p.attachments) {
    print('${a.name} | ${a.sizeText} | ${a.url}');
  }
  assert(p.attachments.length == 2);
  assert(p.attachments.first.name == '源码包 v1.2.zip');
  assert(p.attachments.first.sizeText == '3.42 MB');
  assert(p.attachments.first.url.contains('aid=MTkxOTMx'));
  print('ATTACH_OK');
}
