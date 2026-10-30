import 'package:flutter_test/flutter_test.dart';

import 'package:ycoo_client/data/content.dart';

void main() {
  group('parsePostContent - 新块类型', () {
    test('解析表格', () {
      const html = '''
        <table>
          <tr><th>列1</th><th>列2</th></tr>
          <tr><td>值A</td><td>值B</td></tr>
        </table>
      ''';
      final blocks = parsePostContent(html);

      expect(blocks, hasLength(1));
      expect(blocks.first.kind, BlockKind.table);
      final rows = blocks.first.tableRows!;
      expect(rows, hasLength(2));
      expect(rows[0], hasLength(2));
      expect(rows[0][0].text, '列1');
      expect(rows[0][1].text, '列2');
      expect(rows[1][0].text, '值A');
      expect(rows[1][1].text, '值B');
    });

    test('解析 h1-h6', () {
      const html = '''
        <h1>一级标题</h1>
        <h2>二级标题</h2>
        <h3>三级标题</h3>
        <h4>四级标题</h4>
        <h5>五级标题</h5>
        <h6>六级标题</h6>
      ''';
      final blocks = parsePostContent(html);

      expect(blocks, hasLength(6));
      expect(blocks[0].kind, BlockKind.h1);
      expect(blocks[1].kind, BlockKind.h2);
      expect(blocks[2].kind, BlockKind.h3);
      expect(blocks[3].kind, BlockKind.h4);
      expect(blocks[4].kind, BlockKind.h5);
      expect(blocks[5].kind, BlockKind.h6);

      expect(blocks[0].plainText, '一级标题');
      expect(blocks[5].plainText, '六级标题');
    });

    test('解析 video 标签', () {
      const html = '<video src="https://ycoo.net/media/test.mp4" controls></video>';
      final blocks = parsePostContent(html);

      expect(blocks, hasLength(1));
      expect(blocks.first.kind, BlockKind.video);
      expect(blocks.first.videoUrl, 'https://ycoo.net/media/test.mp4');
      expect(blocks.first.plainText, 'https://ycoo.net/media/test.mp4');
    });

    test('解析 iframe 标签', () {
      const html = '<iframe src="https://ycoo.net/embed/123" width="400"></iframe>';
      final blocks = parsePostContent(html);

      expect(blocks, hasLength(1));
      expect(blocks.first.kind, BlockKind.iframe);
      expect(blocks.first.iframeUrl, 'https://ycoo.net/embed/123');
      expect(blocks.first.plainText, 'https://ycoo.net/embed/123');
    });

    test('表格 plainText 提取', () {
      const html = '''
        <table>
          <tr><th>姓名</th><th>年龄</th></tr>
          <tr><td>张三</td><td>25</td></tr>
        </table>
      ''';
      final blocks = parsePostContent(html);

      final text = blocks.first.plainText;
      expect(text, contains('姓名'));
      expect(text, contains('年龄'));
      expect(text, contains('张三'));
      expect(text, contains('25'));
    });

    test('表情图片过滤 - 不在正文中渲染', () {
      const html = '<img src="https://ycoo.net/static/image/smiley/default/happy.gif" />';
      final blocks = parsePostContent(html);

      // 表情图片应该被过滤掉
      final imageBlocks = blocks.where((b) => b.kind == BlockKind.image);
      expect(imageBlocks, isEmpty);
    });

    test('正常图片保留', () {
      const html = '<img src="https://ycoo.net/forum/attachment/123.jpg" />';
      final blocks = parsePostContent(html);

      final imageBlocks = blocks.where((b) => b.kind == BlockKind.image);
      expect(imageBlocks, hasLength(1));
      expect(imageBlocks.first.imageUrl, 'https://ycoo.net/forum/attachment/123.jpg');
    });

    test('裸链接保留', () {
      const html = '访问 https://ycoo.net/thread/12345 查看更多';
      final blocks = parsePostContent(html);

      expect(blocks, hasLength(1));
      expect(blocks.first.kind, BlockKind.text);
      final allText = blocks.first.runs.map((r) => r.text).join();
      expect(allText, contains('https://ycoo.net/thread/12345'));
    });

    test('嵌套表格解析', () {
      const html = '''
        <table>
          <tr>
            <td>
              <table>
                <tr><td>子A</td><td>子B</td></tr>
              </table>
            </td>
            <td>右列</td>
          </tr>
        </table>
      ''';
      final blocks = parsePostContent(html);

      expect(blocks, hasLength(1));
      expect(blocks.first.kind, BlockKind.table);
      final rows = blocks.first.tableRows!;
      expect(rows.isNotEmpty, isTrue);
    });

    test('混合内容 - 表格+标题+正文', () {
      const html = '''
        <h2>测试报告</h2>
        <table>
          <tr><th>项目</th><th>结果</th></tr>
          <tr><td>测试A</td><td>通过</td></tr>
        </table>
        <p>以上是测试结果。</p>
      ''';
      final blocks = parsePostContent(html);

      expect(blocks.length, greaterThanOrEqualTo(3));
      expect(blocks.any((b) => b.kind == BlockKind.h2), isTrue);
      expect(blocks.any((b) => b.kind == BlockKind.table), isTrue);
      expect(blocks.any((b) => b.kind == BlockKind.text), isTrue);
    });

    test('空表格不崩溃', () {
      const html = '<table></table>';
      final blocks = parsePostContent(html);

      // 空表格没有产生任何块
      expect(blocks, isEmpty);
    });

    test('视频无 src 不崩溃', () {
      const html = '<video controls></video>';
      final blocks = parsePostContent(html);

      // 无 src 的视频不产生块
      expect(blocks.any((b) => b.kind == BlockKind.video), isFalse);
    });

    test('iframe 无 src 不崩溃', () {
      const html = '<iframe width="400"></iframe>';
      final blocks = parsePostContent(html);

      // 无 src 的 iframe 不产生块
      expect(blocks.any((b) => b.kind == BlockKind.iframe), isFalse);
    });
  });
}
