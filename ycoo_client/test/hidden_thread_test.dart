/// 隐藏贴解析回归：回复可见的 `div.locked` 嵌在 `#postmessage` 内。
///
/// 站点实际输出为「游客，如果您要查看本帖隐藏内容请回复」，
/// 旧逻辑因为存在 `#postmessage` 把它误判成已购信息栏。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ycoo_client/data/parsers.dart';

const String _htmlReplyGate = '''
<!DOCTYPE html><html><body>
<form id="fastpostform" action="forum.php?mod=post&amp;action=reply&amp;fid=49&amp;tid=147227&amp;replysubmit=yes"></form>
<div id="post_2899607" class="comiis_vpost comiis_vone">
  <div class="pct"><div class="pcb"><div class="t_fsz"><table><tr>
    <td class="t_f" id="postmessage_2899607">
      md3主题，含原图，其他版本可自设<br />
      素源:纪豫，跑路素
      <div class="locked">游客，如果您要查看本帖隐藏内容请
        <a href="forum.php?mod=post&amp;action=reply&amp;fid=49&amp;tid=147227"
           onclick="replyfloor_reply(this.href)">回复</a>
      </div>
    </td>
  </tr></table></div></div></div>
</div>
</body></html>
''';

void main() {
  test('回复可见：识别隐藏贴、回复要求和版块', () {
    final d = parseThread(_htmlReplyGate, tid: 147227, page: 1);
    expect(d.isLocked, isTrue);
    expect(d.needsReply, isTrue);
    expect(d.needsPurchase, isFalse);
    expect(d.fid, 49);
    expect(d.lockedText, contains('隐藏内容'));
  });
}
