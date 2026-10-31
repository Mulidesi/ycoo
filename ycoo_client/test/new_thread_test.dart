import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/data/forum_api.dart';
import 'package:ycoo_client/data/parsers.dart';
import 'package:ycoo_client/models/models.dart';

const _formHtml = '''
<html><body>
<div id="um"><a href="home.php?mod=space&uid=31981">木里得斯</a>
<a href="member.php?mod=logging&action=logout">退出</a></div>
<form method="post" autocomplete="off" id="postform"
action="forum.php?mod=post&amp;action=newthread&amp;fid=2&amp;extra=&amp;topicsubmit=yes"
onsubmit="return validate(this)">
<input type="hidden" name="mod" value="forum" />
<input type="hidden" name="formhash" id="formhash" value="b2f4bfe0" />
<input type="hidden" name="posttime" id="posttime" value="1792675886" />
<input type="hidden" name="wysiwyg" id="e_mode" value="1" />
<select name="typeid" id="typeid">
<option value="0">选择主题分类</option><option value="18">综合</option>
<option value="20">音源</option><option value="186">影视</option>
</select>
<input type="text" name="subject" id="subject" value="" />
<textarea name="message" id="e_textarea" rows="15"></textarea>
</form>
</body></html>
''';

const _noPermissionHtml = '''
<html><body>
<div class="alert_error">抱歉，您没有权限在该版块发帖</div>
</body></html>
''';

String _successBody({String message = '帖子发布成功', int tid = 123456}) => '''
<?xml version="1.0" encoding="utf-8"?>
<root><![CDATA[<script type="text/javascript" reload="1">
succeedhandle_newthread('forum.php?mod=viewthread&tid=$tid', '$message', {'tid':'$tid'});
</script>]]></root>
''';

const _friendsHtml = '''
<!DOCTYPE html><html><body>
<div class="comiis_userlist01">
  <ul>
    <li>
      <a class="list01_limg" href="space.php?uid=101"><img src="avatar/101.jpg" alt="用户甲"></a>
      <p class="tit"><a href="space.php?uid=101">用户甲</a></p>
      <p class="txt">备注：测试用户</p>
    </li>
    <li>
      <a class="list01_limg" href="space.php?uid=202">
        <img comiis_loadimages="//static/avatar/202.gif" alt="">
      </a>
      <p class="tit"><a href="space.php?uid=202">用户乙</a></p>
    </li>
    <li>
      <a href="home.php?mod=space&do=friend&ac=friend&op=add&uid=303"><img src="static/noavatar.gif"></a>
      <p class="tit"><a href="space.php?uid=303">推荐用户</a></p>
    </li>
  </ul>
</div>
</body></html>
''';

void main() {
  group('parsePostForm', () {
    test('取 action / formhash / posttime 与主题分类', () {
      final form = parsePostForm(_formHtml);
      expect(form.canPost, isTrue);
      expect(form.action, isNot(contains('&amp;')));
      expect(form.action, contains('topicsubmit=yes'));
      expect(form.formhash, 'b2f4bfe0');
      expect(form.posttime, '1792675886');
      expect(form.categories.map((c) => c.id), [18, 20, 186]);
      expect(form.categories.first.name, '综合');
    });

    test('没有 postform 时带出版块提示', () {
      final form = parsePostForm(_noPermissionHtml);
      expect(form.canPost, isFalse);
      expect(form.notice, contains('没有权限'));
    });
  });

  group('parseNewThreadResult', () {
    test('成功回调里解析 tid', () {
      final res = parseNewThreadResult(_successBody());
      expect(res.success, isTrue);
      expect(res.tid, 123456);
      expect(res.pending, isFalse);
      expect(res.message, '发布成功');
    });

    test('需要审核时标记 pending', () {
      final res = parseNewThreadResult(_successBody(message: '主题发布成功，审核后显示'));
      expect(res.success, isTrue);
      expect(res.pending, isTrue);
      expect(res.message, contains('审核'));
    });

    test('comiis 模板：空后缀回调 + Rewrite 地址 + 已发布文案', () {
      const body = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
          '<root><![CDATA[<script type="text/javascript" reload="1">'
          "if(typeof succeedhandle_=='function') {succeedhandle_("
          "'thread-160385-1-1.html', '非常感谢，您的主题已发布，现在将转入主题页，"
          "请稍候……[ 点击这里转入主题列表 ]', {'fid':'2','tid':'160385',"
          "'pid':'3027956'});}</script>]]></root>";
      final res = parseNewThreadResult(body);
      expect(res.success, isTrue);
      expect(res.tid, 160385);
      expect(res.pending, isFalse);
    });

    test('验证码 / 登录失效透传', () {
      final captcha = parseNewThreadResult(
        "<root><![CDATA[<script>errorhandle_newthread('抱歉，请输入验证码');</script>]]></root>",
      );
      expect(captcha.success, isFalse);
      expect(captcha.needCaptcha, isTrue);

      final guest = parseNewThreadResult(
        "<root><![CDATA[<script>errorhandle_newthread('请先登录后再发帖');</script>]]></root>",
      );
      expect(guest.success, isFalse);
      expect(guest.message, contains('登录'));
    });
  });

  group('ForumApi.postNewThread', () {
    test('复用发帖页 action 并提交完整字段', () async {
      late Map<String, String> posted;
      late Uri postUrl;
      final api = ForumApi(
        DiscuzClient(
          client: MockClient((req) async {
            if (req.method == 'GET') {
              expect(req.url.queryParameters['action'], 'newthread');
              expect(req.url.queryParameters['fid'], '2');
              return http.Response.bytes(
                utf8.encode(_formHtml),
                200,
                headers: {'content-type': 'text/html; charset=utf-8'},
              );
            }
            postUrl = req.url;
            posted = Uri.splitQueryString(req.body);
            return http.Response.bytes(
              utf8.encode(_successBody()),
              200,
              headers: {'content-type': 'text/xml; charset=utf-8'},
            );
          }),
        ),
      );

      final res = await api.postNewThread(
        fid: 2,
        subject: '测试主题标题',
        message: '正文内容',
        typeId: 18,
      );

      expect(res.success, isTrue);
      expect(res.tid, 123456);
      expect(postUrl.queryParameters['action'], 'newthread');
      expect(postUrl.queryParameters['topicsubmit'], 'yes');
      expect(postUrl.queryParameters['inajax'], '1');
      expect(posted['formhash'], 'b2f4bfe0');
      expect(posted['posttime'], '1792675886');
      expect(posted['subject'], '测试主题标题');
      expect(posted['message'], '正文内容');
      expect(posted['typeid'], '18');
      expect(posted['wysiwyg'], '0');
    });

    test('无发帖权限时不 POST，直接返回站点提示', () async {
      var postCount = 0;
      final api = ForumApi(
        DiscuzClient(
          client: MockClient((req) async {
            if (req.method == 'POST') postCount++;
            return http.Response.bytes(
              utf8.encode(_noPermissionHtml),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }),
        ),
      );

      final res = await api.postNewThread(
        fid: 51,
        subject: '测试主题标题',
        message: '正文',
      );
      expect(res.success, isFalse);
      expect(res.message, contains('没有权限'));
      expect(postCount, 0);
    });

    test('默认高级选项：usesig=1，无 replyonly/ordertype/emailnotify', () async {
      late Map<String, String> posted;
      final api = ForumApi(
        DiscuzClient(
          client: MockClient((req) async {
            if (req.method == 'GET') {
              return http.Response.bytes(
                utf8.encode(_formHtml),
                200,
                headers: {'content-type': 'text/html; charset=utf-8'},
              );
            }
            posted = Uri.splitQueryString(req.body);
            return http.Response.bytes(
              utf8.encode(_successBody()),
              200,
              headers: {'content-type': 'text/xml; charset=utf-8'},
            );
          }),
        ),
      );
      await api.postNewThread(fid: 2, subject: '标题', message: '正文');
      expect(posted['usesig'], '1');
      expect(posted.containsKey('replyonly'), isFalse);
      expect(posted.containsKey('ordertype'), isFalse);
      expect(posted.containsKey('emailnotify'), isFalse);
      expect(posted.containsKey('readperm'), isFalse);
      expect(posted.containsKey('price'), isFalse);
    });

    test('高级选项：replyonly/ordertype/emailnotify/usesig=0 全部拼入', () async {
      late Map<String, String> posted;
      final api = ForumApi(
        DiscuzClient(
          client: MockClient((req) async {
            if (req.method == 'GET') {
              return http.Response.bytes(
                utf8.encode(_formHtml),
                200,
                headers: {'content-type': 'text/html; charset=utf-8'},
              );
            }
            posted = Uri.splitQueryString(req.body);
            return http.Response.bytes(
              utf8.encode(_successBody()),
              200,
              headers: {'content-type': 'text/xml; charset=utf-8'},
            );
          }),
        ),
      );
      await api.postNewThread(
        fid: 2,
        subject: '标题',
        message: '正文',
        replyOnly: true,
        orderDesc: true,
        notify: true,
        useSignature: false,
      );
      expect(posted['usesig'], '0');
      expect(posted['replyonly'], '1');
      expect(posted['ordertype'], '1');
      expect(posted['emailnotify'], '1');
    });

    test('阅读权限与售价：非空非零时拼入，0 或空时不拼', () async {
      late Map<String, String> posted1;
      late Map<String, String> posted2;
      var callCount = 0;
      final api = ForumApi(
        DiscuzClient(
          client: MockClient((req) async {
            if (req.method == 'GET') {
              return http.Response.bytes(
                utf8.encode(_formHtml),
                200,
                headers: {'content-type': 'text/html; charset=utf-8'},
              );
            }
            if (callCount++ == 0) {
              posted1 = Uri.splitQueryString(req.body);
            } else {
              posted2 = Uri.splitQueryString(req.body);
            }
            return http.Response.bytes(
              utf8.encode(_successBody()),
              200,
              headers: {'content-type': 'text/xml; charset=utf-8'},
            );
          }),
        ),
      );
      await api.postNewThread(
        fid: 2,
        subject: '标题',
        message: '正文',
        readPerm: '5',
        price: '10',
      );
      expect(posted1['readperm'], '5');
      expect(posted1['price'], '10');

      await api.postNewThread(
        fid: 2,
        subject: '标题',
        message: '正文',
        readPerm: '0',
        price: '',
      );
      expect(posted2.containsKey('readperm'), isFalse);
      expect(posted2.containsKey('price'), isFalse);
    });
  });

  group('parseFriends', () {
    test('解析 comiis 模板好友列表', () {
      final friends = parseFriends(_friendsHtml);
      expect(friends.length, 2);
      expect(friends[0].uid, 101);
      expect(friends[0].username, '用户甲');
      expect(friends[0].avatar, contains('101.jpg'));
      expect(friends[0].note, '备注：测试用户');
      expect(friends[1].uid, 202);
      expect(friends[1].username, '用户乙');
      expect(friends[1].avatar, contains('202.gif'));
    });

    test('跳过带加好友按钮的推荐用户', () {
      final friends = parseFriends(_friendsHtml);
      expect(friends.where((f) => f.uid == 303), isEmpty);
    });

    test('空 HTML 返回空列表', () {
      expect(parseFriends(''), isEmpty);
      expect(parseFriends('<html><body></body></html>'), isEmpty);
    });

    test('桌面模板 ul.buddy 回落解析', () {
      const html = '''
<html><body>
<ul class="buddy">
  <li>
    <dd class="avt"><img src="//static/avatar/999.png"></dd>
    <h4><a href="space.php?uid=999">桌面用户</a></h4>
    <p class="txt">桌面备注</p>
  </li>
</ul>
</body></html>
''';
      final friends = parseFriends(html);
      expect(friends.length, 1);
      expect(friends[0].uid, 999);
      expect(friends[0].username, '桌面用户');
      expect(friends[0].note, '桌面备注');
    });

    test('去重：同一 uid 只出现一次', () {
      const html = '''
<html><body>
<div class="comiis_userlist01"><ul>
  <li><p class="tit"><a href="space.php?uid=555">重复用户</a></p></li>
  <li><p class="tit"><a href="space.php?uid=555">重复用户</a></p></li>
</ul></div>
</body></html>
''';
      final friends = parseFriends(html);
      expect(friends.length, 1);
    });
  });

  group('ForumApi.fetchFriends', () {
    test('GET home.php 并解析好友列表', () async {
      var getUrl = '';
      late List<FriendItem> friends;
      final api = ForumApi(
        DiscuzClient(
          client: MockClient((req) async {
            getUrl = req.url.toString();
            return http.Response.bytes(
              utf8.encode(_friendsHtml),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }),
        ),
      );
      friends = await api.fetchFriends();
      expect(getUrl, contains('mod=space'));
      expect(getUrl, contains('do=friend'));
      expect(friends.length, 2);
    });
  });
}
