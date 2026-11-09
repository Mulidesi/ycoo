import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycoo_client/data/previews.dart';
import 'package:ycoo_client/models/models.dart';
import 'package:ycoo_client/ui/theme.dart';
import 'package:ycoo_client/ui/widgets/html_content.dart';
import 'package:ycoo_client/ui/widgets/thread_tile.dart';

const _item = ThreadItem(
  tid: 153502,
  title: '楼栋速通快找 小区找楼助手 附带水印相机 支持外卖跑腿骑手',
  url: 'https://ycoo.net/thread-153502-1-1.html',
  author: 'ysqzh',
  replies: 17,
  views: 250,
  timeText: '昨天 21:20',
  typeName: '综合交流',
  hasAttachment: true,
  fid: 39,
);

const _preview = ThreadPreview(
  image: 'https://ycoo.net/data/attachment/forum/202610/20/demo.webp',
  excerpt: '【软件介绍】这款是面向外卖、跑腿骑手打造的楼栋查询工具，能够标记小区楼号、商铺、停车点位，方便跑单时快速定位。',
  imageCount: 3,
  likes: 8,
);

Future<void> _pumpAt(WidgetTester tester, Widget child, {double width = 360}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SizedBox(width: width - 24, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('列表卡片：完整卡片（头像+标题+摘要+首图+数据行）', (tester) async {
    await _pumpAt(
      tester,
      ThreadTile(item: _item, preview: _preview, showBoard: true, onTap: () {}),
    );
    expect(find.text('楼栋速通快找 小区找楼助手 附带水印相机 支持外卖跑腿骑手'), findsOneWidget);
    expect(find.text('综合交流'), findsOneWidget);
    expect(find.textContaining('楼栋查询工具'), findsOneWidget);
    expect(find.text('3 图'), findsOneWidget);
    expect(find.text('250'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('列表卡片：无预览时收缩，不留空白', (tester) async {
    await _pumpAt(tester, ThreadTile(item: _item, onTap: () {}));
    expect(find.textContaining('楼栋查询工具'), findsNothing);
    expect(find.text('3 图'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('列表卡片：窄屏不溢出', (tester) async {
    await _pumpAt(
      tester,
      ThreadTile(item: _item, preview: _preview, showBoard: true, onTap: () {}),
      width: 300,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('列表卡片：悬赏芯片，不显示售价', (tester) async {
    const reward = ThreadItem(
      tid: 164872,
      title: '求个资源',
      url: 'https://ycoo.net/thread-164872-1-1.html',
      author: '甲',
      price: 80,
      isReward: true,
    );
    await _pumpAt(tester, ThreadTile(item: reward, onTap: () {}));
    expect(find.text('悬赏 80 星币'), findsOneWidget);
    expect(find.textContaining('售价'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('列表卡片：预览 special=3 补悬赏芯片', (tester) async {
    const item = ThreadItem(
      tid: 164872,
      title: '求个资源',
      url: 'https://ycoo.net/thread-164872-1-1.html',
      author: '甲',
    );
    const preview = ThreadPreview(special: 3, price: 80);
    await _pumpAt(tester, ThreadTile(item: item, preview: preview, onTap: () {}));
    expect(find.text('悬赏 80 星币'), findsOneWidget);
    expect(find.textContaining('购买'), findsNothing);
  });

  testWidgets('列表卡片：付费芯片', (tester) async {
    const paid = ThreadItem(
      tid: 164903,
      title: '付费资源',
      url: 'https://ycoo.net/thread-164903-1-1.html',
      author: '乙',
      price: 5,
    );
    await _pumpAt(tester, ThreadTile(item: paid, onTap: () {}));
    expect(find.text('售价 5 星币'), findsOneWidget);
    expect(find.textContaining('悬赏'), findsNothing);
  });

  testWidgets('外链点击弹出复制/打开', (tester) async {
    await _pumpAt(
      tester,
      const PostContent(html: '<a href="https://example.com/path">外链示例</a>'),
    );
    await tester.tap(find.text('外链示例'));
    await tester.pumpAndSettle();
    expect(find.text('打开链接'), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('打开'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('正文：裸链接可点、图片渲染、长文本不溢出', (tester) async {
    const html = '''
<div>【下载地址】：</div>
<div>百度网盘：https://pan.baidu.com/s/19F8KzwRMgmUf6gXDiHKwJw?pwd=yhrj</div>
<div>夸克网盘：https://pan.quark.cn/s/2ecc0848b8b1</div>
<div><img src="https://ycoo.net/data/attachment/forum/demo.webp" /></div>
<div>长文本测试：这是一段用于检查换行与链接混排的中文，链接 https://example.com/a/very/long/path?with=query 后面继续中文。</div>
''';
    await _pumpAt(tester, const PostContent(html: html));
    expect(find.byType(PostContent), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
