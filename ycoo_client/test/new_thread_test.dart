import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/data/forum_api.dart';
import 'package:ycoo_client/data/parsers.dart';

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
  });
}
