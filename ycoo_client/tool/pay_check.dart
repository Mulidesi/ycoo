// ignore_for_file: avoid_print

/// 离线验证：付费贴解析（payUrl / payPriceText / payBuyers / 已购判定）。
/// 用法：dart run tool/pay_check.dart ../recon
library;

import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:ycoo_client/data/parsers.dart';

/// 期望值：样本不存在时自动跳过，存在则必须与期望一致。
const Map<String, ({bool locked, bool needsPurchase})> _expect = {
  't_152621.html': (locked: true, needsPurchase: true), // 付费贴（5 星币）
  't153650_login.html': (locked: true, needsPurchase: true), // 购买前（登录态）
  't153650_after.html': (locked: false, needsPurchase: false), // 购买后（信息栏）
  't_153569_login.html': (locked: true, needsPurchase: false), // 回复可见
  't_152545.html': (locked: false, needsPurchase: false), // 普通贴
  't_152948.html': (locked: false, needsPurchase: false), // 普通贴
};

void main(List<String> args) {
  final dir = Directory(args.isNotEmpty ? args[0] : '../recon');
  var fail = 0;
  var checked = 0;

  for (final entry in _expect.entries) {
    final name = entry.key;
    final f = File('${dir.path}/$name');
    if (!f.existsSync()) {
      print('SKIP $name（样本不存在）');
      continue;
    }
    final doc = html_parser.parse(f.readAsStringSync());
    final tid = int.tryParse(RegExp(r'(\d{3,})').firstMatch(name)?.group(1) ?? '') ?? 0;
    final d = parseThread(doc.documentElement!.outerHtml, tid: tid, page: 1);
    checked++;

    final ok = d.isLocked == entry.value.locked && d.needsPurchase == entry.value.needsPurchase;
    if (!ok) fail++;

    print(
      '${ok ? 'PASS' : 'FAIL'} $name  '
      'locked=${d.isLocked}(期望${entry.value.locked}) '
      'needsPurchase=${d.needsPurchase}(期望${entry.value.needsPurchase}) '
      'price=${d.payPriceText ?? '-'} buyers=${d.payBuyers} '
      'payUrl=${d.payUrl ?? '-'} posts=${d.posts.length}',
    );
  }

  print('\n$checked 个样本，$fail 个不符合预期');
  if (fail > 0) exit(1);
}
