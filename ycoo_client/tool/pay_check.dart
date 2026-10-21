// ignore_for_file: avoid_print

/// 离线验证：付费贴解析（payUrl / payPriceText / payBuyers）。
/// 用法：dart run tool/pay_check.dart ../recon
library;

import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:ycoo_client/data/parsers.dart';

void main(List<String> args) {
  final dir = Directory(args.isNotEmpty ? args[0] : '../recon');
  final files = [
    't_152621.html', // 付费贴（5 星币）
    't_153569_login.html', // 回复可见贴
    't_152545.html', // 普通贴
    't_152948.html', // 普通贴
  ];
  var fail = 0;
  for (final name in files) {
    final f = File('${dir.path}/$name');
    if (!f.existsSync()) {
      print('SKIP $name（样本不存在）');
      continue;
    }
    final doc = html_parser.parse(f.readAsStringSync());
    final tidRe = RegExp(r't_(\d+)');
    final tid = int.parse(tidRe.firstMatch(name)!.group(1)!);
    final d = parseThread(doc.documentElement!.outerHtml, tid: tid, page: 1);
    print(
      '$name  locked=${d.isLocked} pay=${d.needsPurchase} '
      'price=${d.payPriceText} buyers=${d.payBuyers} payUrl=${d.payUrl ?? '-'}',
    );
  }
  if (fail > 0) exit(1);
}
