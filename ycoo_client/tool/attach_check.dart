// ignore_for_file: avoid_print

/// 离线验证附件解析：图片附件并入正文、文件附件成卡片。
library;

import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:ycoo_client/data/parsers.dart';

void main(List<String> args) {
  final dir = Directory(args.isNotEmpty ? args[0] : '../recon');
  for (final name in ['t_152545.html', 't_152948.html', 't_5767.html']) {
    final f = File('${dir.path}/$name');
    if (!f.existsSync()) continue;
    final doc = html_parser.parse(f.readAsStringSync());
    final d = parseThread(doc.documentElement!.outerHtml, tid: 1, page: 1);
    for (final p in d.posts) {
      print('$name pid=${p.pid} atts=${p.attachments.length} '
          '${p.attachments.map((a) => "${a.name}(${a.sizeText})").join(", ")}');
    }
  }
}
