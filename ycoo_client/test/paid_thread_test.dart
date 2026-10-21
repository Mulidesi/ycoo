/// 付费主题购买回归测试。
///
/// 样本取自 2026-10-21 对 https://www.ycoo.net/thread-153650-1-1.html 的真实抓包：
/// 购买前 locked 块带 `action=pay` 入口，购买成功后站点**仍然保留** locked 块，
/// 只是内容退化成「记录 付费主题, 价格: 5 星币」（链接变成 action=viewpayments）。
/// 早期实现按「含星币即锁定」判断，导致购买成功也被报成失败。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/data/forum_api.dart';
import 'package:ycoo_client/data/parsers.dart';

/// 购买前：正文被 locked 顶掉，没有 #postmessage，locked 内有购买入口。
const String _htmlBeforeBuy = '''
<!DOCTYPE html><html><body>
<div id="post_2958465" class="comiis_vpost comiis_vone">
  <div class="pct"><div class="pcb">
    <div class="locked">
      <a href="forum.php?mod=misc&amp;action=pay&amp;tid=153650&amp;pid=2958465"
         class="y viewpay" title="购买主题" onclick="showWindow('pay', this.href)">购买主题</a>
      <em class="right">已有 6 人购买&nbsp; </em>
      本主题需向作者支付 <strong>5 星币</strong> 才能浏览
    </div>
  </div></div>
</div>
</body></html>
''';

/// 购买后：locked 退化成信息栏（action=viewpayments），正文回到 #postmessage。
const String _htmlAfterBuy = '''
<!DOCTYPE html><html><body>
<div id="post_2958465" class="comiis_vpost comiis_vone">
  <div class="pct"><div class="pcb">
    <div class="locked"><em class="y"><a href="forum.php?mod=misc&amp;action=viewpayments&amp;tid=153650"
      onclick="showWindow('pay', this.href)">记录</a></em>付费主题, 价格: <strong>5 星币 </strong></div>
    <div class="t_fsz"><table cellspacing="0" cellpadding="0"><tr>
      <td class="t_f" id="postmessage_2958465"> 小说网站</td></tr></table></div>
  </div></div>
</div>
</body></html>
''';

/// 购买弹窗（inajax 响应，真实抓包片段）。
const String _dialogXml = '''
<?xml version="1.0" encoding="utf-8"?>
<root><![CDATA[
<form id="payform" method="post" autocomplete="off" action="forum.php?mod=misc&amp;action=pay&amp;paysubmit=yes&amp;infloat=yes" onsubmit="ajaxpost('payform', 'return_pay', 'return_pay', 'onerror');return false;">
<input type="hidden" name="formhash" value="57bd2ae4" />
<input type="hidden" name="referer" value="https://www.ycoo.net/./" />
<input type="hidden" name="tid" value="153650" />
<input type="hidden" name="handlekey" value="pay" />
<button type="submit" name="paysubmit" class="pn pnc" value="true"><span>提交</span></button>
</form>
]]></root>
''';

/// 提交成功响应：注意回调名是 succeedhandle_（handlekey 为空）。
const String _submitOkXml = '''
<?xml version="1.0" encoding="utf-8"?>
<root><![CDATA[<script type="text/javascript" reload="1">if(typeof succeedhandle_=='function') {succeedhandle_('forum.php?mod=viewthread&tid=153650', '主题购买成功 ', {});}</script>]]></root>
''';

const String _submitNoCreditXml = '''
<?xml version="1.0" encoding="utf-8"?>
<root><![CDATA[<script type="text/javascript" reload="1">if(typeof errorhandle_pay=='function') {errorhandle_pay('抱歉，您的星币不足', {});}</script>]]></root>
''';

http.Response _xml(String body) => http.Response.bytes(utf8.encode(body), 200);

void main() {
  group('付费贴解析', () {
    test('购买前：识别购买入口 / 价格 / 已购人数', () {
      final d = parseThread(_htmlBeforeBuy, tid: 153650, page: 1);
      expect(d.isLocked, isTrue);
      expect(d.needsPurchase, isTrue);
      expect(d.canPurchase, isTrue);
      expect(d.payUrl, contains('action=pay'));
      expect(d.payUrl, contains('tid=153650'));
      expect(d.payPriceText, '5 星币');
      expect(d.payBuyers, 6);
    });

    test('购买后：locked 信息栏不应再判定为锁定', () {
      final d = parseThread(_htmlAfterBuy, tid: 153650, page: 1);
      expect(d.isLocked, isFalse, reason: '「付费主题, 价格: 5 星币」是已购信息栏，不是拦截');
      expect(d.needsPurchase, isFalse);
      expect(d.payUrl, isNull);
      expect(d.posts, isNotEmpty);
      expect(d.posts.first.contentHtml, contains('小说网站'));
    });
  });

  group('inajax 消息解析', () {
    test('succeedhandle_ 空 handlekey 能取到提示语', () {
      expect(parseAjaxMessage(_submitOkXml), '主题购买成功');
    });

    test('errorhandle_ 的失败文案也能透传', () {
      expect(parseAjaxMessage(_submitNoCreditXml), contains('星币不足'));
    });
  });

  group('buyThread 全流程（离线回放）', () {
    late List<String> calls;

    ForumApi apiWith({required String submitXml, required String threadAfter}) {
      calls = <String>[];
      final client = MockClient((req) async {
        final url = req.url.toString();
        calls.add('${req.method} $url');
        if (req.method == 'POST') return _xml(submitXml);
        if (url.contains('action=pay')) return _xml(_dialogXml);
        return _xml(threadAfter);
      });
      return ForumApi(DiscuzClient(client: client));
    }

    test('购买成功 → success，且提交参数与真实表单一致', () async {
      final api = apiWith(submitXml: _submitOkXml, threadAfter: _htmlAfterBuy);
      final before = parseThread(_htmlBeforeBuy, tid: 153650, page: 1);

      final res = await api.buyThread(before);

      expect(res.success, isTrue);
      expect(res.message, contains('购买成功'));
      // 弹窗 → 提交 → 校验拉帖
      expect(calls.length, 3);
      expect(calls[1], startsWith('POST'));
      expect(calls[1], contains('paysubmit=yes'));
      expect(calls[1], contains('tid=153650'));
      expect(calls.last, contains('thread-153650-1-1.html'));
    });

    test('星币不足 → 失败并透传站点文案', () async {
      final api = apiWith(submitXml: _submitNoCreditXml, threadAfter: _htmlBeforeBuy);
      final before = parseThread(_htmlBeforeBuy, tid: 153650, page: 1);

      final res = await api.buyThread(before);

      expect(res.success, isFalse);
      expect(res.message, contains('星币不足'));
    });
  });
}
