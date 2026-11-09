/// 悬赏问答 vs 付费主题：列表徽章、详情标签、移动端预览占位。
///
/// 移动端 `forumdisplay` 对游客不可见的悬赏贴（special=3）也会返回
/// `**** 本内容购买后可见 ****`，不能当成「需购买」摘要。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ycoo_client/data/parsers.dart';
import 'package:ycoo_client/data/previews.dart';
import 'package:ycoo_client/models/models.dart';

const String _htmlList = '''
<!DOCTYPE html><html><body>
<ul>
<li id="normalthread_164872" class="kmlist">
  <a class="kmtit" href="thread-164872-1-1.html"><span class="km_subject">求个资源</span></a>
  <a href="space-uid-12.html">作者甲</a>
  <span class="kmbga kmico_xs">悬赏 <strong>80</strong> 星币</span>
  <span class="kmpl">3</span><span class="kmck">100</span>
  <a class="kmbg" href="forum-2-1.html">综合交流</a>
</li>
<li id="normalthread_164903" class="kmlist">
  <a class="kmtit" href="thread-164903-1-1.html"><span class="km_subject">付费资源</span></a>
  <span class="kmbga kmico_xs">售价 5 星币</span>
</li>
</ul>
</body></html>
''';

const String _htmlRewardDetail = '''
<!DOCTYPE html><html><body>
<h1 class="ts"><span id="thread_subject">求个资源</span></h1>
<span class="kmbga kmico_xs">悬赏 <strong>80</strong> 星币</span>
<div id="reward_thread"></div>
<form id="fastpostform" action="forum.php?mod=post&amp;action=reply&amp;fid=2&amp;tid=164872"></form>
<div id="post_1" class="comiis_vpost comiis_vone">
  <div class="pct"><div class="pcb">
    <div class="t_fsz"><table><tr>
      <td class="t_f" id="postmessage_1">问题描述</td>
    </tr></table></div>
  </div></div>
</div>
</body></html>
''';

const String _htmlRewardLoginLock = '''
<!DOCTYPE html><html><body>
<h1 class="ts">悬赏问答</h1>
<div class="rwdbst">悬赏金额: 80 星币</div>
<div id="post_1" class="comiis_vpost comiis_vone">
  <div class="pct"><div class="pcb">
    <div class="locked">您需要登录才可以下载或查看</div>
  </div></div>
</div>
</body></html>
''';

const String _forumDisplayJson = '''
{
  "Variables": {
    "forum_threadlist": [
      {
        "tid": "164872",
        "special": "3",
        "price": "80",
        "message": "**** 本内容购买后可见 ****",
        "recommend_add": "0"
      },
      {
        "tid": "164903",
        "special": "0",
        "price": "5",
        "message": "**** 本内容购买后可见 ****",
        "recommend_add": "1"
      },
      {
        "tid": "11",
        "special": "0",
        "price": "-1",
        "message": "**** 本内容购买后可见 ****"
      },
      {
        "tid": "22",
        "special": "0",
        "price": "0",
        "message": "一段正常摘要"
      }
    ]
  }
}
''';

void main() {
  group('ThreadItem 付费 / 悬赏', () {
    test('悬赏有赏金也不算付费', () {
      const t = ThreadItem(
        tid: 1,
        title: 'x',
        url: 'u',
        price: 80,
        isReward: true,
      );
      expect(t.isPaid, isFalse);
      expect(t.isReward, isTrue);
    });

    test('正数售价且非悬赏才是付费', () {
      const t = ThreadItem(tid: 1, title: 'x', url: 'u', price: 5);
      expect(t.isPaid, isTrue);
      expect(t.copyWith(fid: 2).price, 5);
      expect(t.copyWith(fid: 2).isReward, isFalse);
    });
  });

  group('列表 HTML', () {
    test('kmbga 悬赏 / 售价徽章', () {
      final page = parseThreadList(_htmlList);
      expect(page.items, hasLength(2));
      final reward = page.items[0];
      expect(reward.tid, 164872);
      expect(reward.isReward, isTrue);
      expect(reward.price, 80);
      expect(reward.isPaid, isFalse);
      final paid = page.items[1];
      expect(paid.tid, 164903);
      expect(paid.isReward, isFalse);
      expect(paid.price, 5);
      expect(paid.isPaid, isTrue);
    });
  });

  group('详情 HTML', () {
    test('识别悬赏标签与金额', () {
      final d = parseThread(_htmlRewardDetail, tid: 164872, page: 1);
      expect(d.isReward, isTrue);
      expect(d.rewardPriceText, '80 星币');
      expect(d.needsPurchase, isFalse);
      expect(d.fid, 2);
    });

    test('游客登录墙不算购买', () {
      final d = parseThread(_htmlRewardLoginLock, tid: 164872, page: 1);
      expect(d.isReward, isTrue);
      expect(d.rewardPriceText, '80 星币');
      expect(d.isLocked, isTrue);
      expect(d.needsLogin, isTrue);
      expect(d.needsPurchase, isFalse);
    });
  });

  group('移动端预览', () {
    test('悬赏占位摘要丢弃，付费占位保留', () {
      final map = parseForumDisplayPreviews(_forumDisplayJson);
      final reward = map[164872]!;
      expect(reward.isReward, isTrue);
      expect(reward.price, 80);
      expect(reward.isPaid, isFalse);
      expect(reward.excerpt, isNull);

      final paid = map[164903]!;
      expect(paid.isPaid, isTrue);
      expect(paid.price, 5);
      expect(paid.excerpt, contains('购买后可见'));

      final neg = map[11]!;
      expect(neg.price, 0);
      expect(neg.isPaid, isFalse);
      expect(neg.excerpt, isNull);

      expect(map[22]!.excerpt, '一段正常摘要');
    });

    test('previewText 直接过滤购买占位', () {
      expect(
        previewText('**** 本内容购买后可见 ****', special: 3, price: 80),
        isNull,
      );
      expect(
        previewText('当前主题内容需要付费购买', special: 0, price: 0),
        isNull,
      );
      expect(
        previewText('**** 本内容购买后可见 ****', special: 0, price: 5),
        contains('购买后可见'),
      );
    });
  });
}
