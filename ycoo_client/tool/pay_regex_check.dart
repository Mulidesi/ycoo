// ignore_for_file: avoid_print

/// 验证 buyThread 的表单解析正则（离线）。
library;

import 'package:ycoo_client/data/parsers.dart';

void main() {
  // 模拟 Discuz forum/pay.htm 弹窗（inajax root 包裹）
  const body = '<root><![CDATA['
      '<form id="payform" method="post" autocomplete="off" '
      'action="forum.php?mod=misc&amp;action=pay&amp;paysubmit=yes&amp;infloat=yes">'
      '<input type="hidden" name="formhash" value="972fbe6b" />'
      '<input type="hidden" name="tid" value="152621" />'
      '<button type="submit" name="paysubmit" value="true">确认</button></form>'
      ']]></root>';

  final formRe = RegExp(r'''<form[^>]+action=["']([^"']+)["'][^>]*>''');
  final m = formRe.firstMatch(body);
  final action = m!.group(1)!.replaceAll('&amp;', '&');
  print('action = $action');
  print('formhash = ${parseFormhash(body)}');
  assert(action == 'forum.php?mod=misc&action=pay&paysubmit=yes&infloat=yes');
  assert(!action.contains('tid='), '真实模板 action 不含 tid —— 证明必须补');
  assert(parseFormhash(body) == '972fbe6b');
  print('PAY_REGEX_OK');
}
