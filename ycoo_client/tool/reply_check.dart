// ignore_for_file: avoid_print
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/data/forum_api.dart';
import 'package:ycoo_client/data/parsers.dart';

// 抓到的真实响应样本，用于验证提示语提取（之前这里被误判成失败）
const _loginSample = '<?xml version="1.0" encoding="utf-8"?>\n'
    '<root><![CDATA[<script type="text/javascript" reload="1">if(typeof succeedhandle_login==\'function\') '
    '{succeedhandle_login(\'https://ycoo.net/\', \'欢迎您回来，大会员 木里得斯，现在将转入登录前页面\', '
    '{\'username\':\'木里得斯\',\'usergroup\':\'<font color="#4B3E2A">大会员</font>\',\'uid\':\'31981\'});}</script>]]></root>';

const _replySample = '<?xml version="1.0" encoding="utf-8"?>\n'
    '<root><![CDATA[<script type="text/javascript" reload="1">if(typeof succeedhandle_fastpost==\'function\') '
    '{succeedhandle_fastpost(\'forum.php?mod=viewthread&tid=152951&pid=2954047&page=1&extra=page%3D1#pid2954047\', '
    '\'非常感谢，回复发布成功，现在将转入主题页，请稍候……[ 点击这里转入主题列表 ]\', '
    '{\'fid\':\'39\',\'tid\':\'152951\',\'pid\':\'2954047\'});}</script>]]></root>';

const _errorSample = '<?xml version="1.0" encoding="utf-8"?>\n'
    '<root><![CDATA[抱歉，指定的主题不存在或已被删除或正在被审核<script type="text/javascript" reload="1">'
    'setTimeout("window.location.href=\'forum.php\'", 3000);</script>]]></root>';

Future<void> main(List<String> args) async {
  print('== 1. 提示语提取（离线样本） ==');
  print('login : ${parseAjaxMessage(_loginSample)}');
  print('reply : ${parseAjaxMessage(_replySample)}');
  print('error : ${parseAjaxMessage(_errorSample)}');

  final client = DiscuzClient();
  final api = ForumApi(client);
  final login = await api.login('木里得斯', '123456asd');
  print('\n== 2. 登录 ==  success=${login.success} msg=${login.message}');

  print('\n== 3. 不存在的主题（错误提示是否透传） ==');
  final bad = await api.reply(tid: 999999999, fid: 39, message: 'test');
  print('success=${bad.success} message=${bad.message}');

  if (args.contains('--live')) {
    final tid = int.parse(args[args.indexOf('--live') + 1]);
    print('\n== 4. 真实回帖 tid=$tid ==');
    final res = await api.reply(tid: tid, fid: 39, message: '感谢分享，感谢楼主！');
    print('success=${res.success} message=${res.message}');
    final d = await api.thread(tid);
    final mine = d.posts.where((p) => p.author == '木里得斯').toList();
    print('回帖后楼层数=${d.posts.length}，本人楼层=${mine.length} '
        '最新=${mine.isEmpty ? "-" : mine.last.floor}');
  }
  client.close();
}
