// ignore_for_file: avoid_print
import 'dart:io';

import 'package:ycoo_client/data/content.dart';
import 'package:ycoo_client/data/parsers.dart';

void main(List<String> args) {
  final dir = Directory(args.isNotEmpty ? args[0] : '../recon');
  for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.html'))) {
    final html = f.readAsStringSync();
    if (!html.contains('id="post_')) continue;
    final d = parseThread(html, page: 1);
    final name = f.path.split(RegExp(r'[\\/]')).last;
    print('${name.padRight(22)} posts=${d.posts.length} fid=${d.fid} '
        'locked=${d.isLocked}/${d.needsReply ? "reply" : ""}${d.needsPurchase ? "/pay" : ""} '
        'op=${d.posts.isNotEmpty && d.posts.first.isOp} total=${d.totalPages}');
    for (final p in d.posts.take(3)) {
      final blocks = parsePostContent(p.contentHtml);
      final txt = contentPlainText(blocks).replaceAll(RegExp(r'\s+'), ' ');
      final imgs = blocks.where((b) => b.kind == BlockKind.image).length;
      print('   pid=${p.pid} op=${p.isOp} floor=${p.floor} blocks=${blocks.length} '
          'imgs=$imgs text=${txt.length} :: ${txt.substring(0, txt.length > 60 ? 60 : txt.length)}');
    }
  }
}
