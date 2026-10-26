// ignore_for_file: avoid_print
import 'dart:io';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/data/parsers.dart';

Future<void> main(List<String> args) async {
  final tid = args.isNotEmpty ? args[0] : '152951';
  final page = args.length > 1 ? args[1] : '1';
  final out = args.length > 2 ? args[2] : '../recon/thread_login.html';
  final c = DiscuzClient(baseUrl: 'https://ycoo.net');
  final lp = await c.get('member.php?mod=logging&action=login');
  final fh0 = parseFormhash(lp.body) ?? '';
  final lh = parseLoginhash(lp.body) ?? '';
  await c.post(
    'member.php?mod=logging&action=login&loginsubmit=yes&handlekey=login'
    '${lh.isNotEmpty ? '&loginhash=$lh' : ''}&inajax=1',
    {
      'formhash': fh0, 'referer': 'https://ycoo.net/', 'loginfield': 'username',
      'username': '木里得斯', 'password': '123456asd', 'questionid': '0',
      'answer': '', 'cookietime': '2592000',
    },
    referer: 'https://ycoo.net/member.php?mod=logging&action=login',
  );
  final r = await c.get('thread-$tid-$page-1.html');
  File(out).writeAsStringSync(r.body);
  print('saved $out len=${r.body.length} loggedIn=${looksLoggedIn(r.body)}');
  c.close();
}
