import 'package:flutter_test/flutter_test.dart';
import 'package:ycoo_client/core/services/feed_cache.dart';
import 'package:ycoo_client/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeedCacheEntry', () {
    test('toJson / fromJson 往返', () {
      final entry = FeedCacheEntry(
        view: 'newthread',
        items: const [
          ThreadItem(tid: 1, title: '标题 1', url: 'https://ycoo.net/thread-1-1-1.html'),
          ThreadItem(tid: 2, title: '标题 2', url: 'https://ycoo.net/thread-2-1-1.html', author: '作者', replies: 10),
        ],
        page: 1,
        totalPages: 5,
        cachedAt: DateTime(2026, 1, 1, 12, 0, 0),
      );
      final json = entry.toJson();
      final restored = FeedCacheEntry.fromJson(json);
      expect(restored.view, 'newthread');
      expect(restored.items, hasLength(2));
      expect(restored.items[0].tid, 1);
      expect(restored.items[0].title, '标题 1');
      expect(restored.items[1].author, '作者');
      expect(restored.items[1].replies, 10);
      expect(restored.page, 1);
      expect(restored.totalPages, 5);
      expect(restored.cachedAt, entry.cachedAt);
    });

    test('fromJson 容错缺失字段', () {
      final restored = FeedCacheEntry.fromJson({
        'view': 'hot',
        'items': [
          {'tid': 1, 'title': 'x', 'url': 'u'},
        ],
      });
      expect(restored.view, 'hot');
      expect(restored.items, hasLength(1));
      expect(restored.page, 1);
      expect(restored.totalPages, 1);
    });
  });

  group('ThreadItem 序列化', () {
    test('toJson / fromJson 往返', () {
      const item = ThreadItem(
        tid: 123,
        title: '测试标题',
        url: 'https://ycoo.net/thread-123-1-1.html',
        author: '作者',
        authorId: 456,
        avatar: 'https://ycoo.net/avatar.png',
        replies: 10,
        views: 100,
        timeText: '昨天 21:20',
        typeName: '综合交流',
        hasAttachment: true,
        isSticky: false,
        fid: 2,
        price: 5,
        isReward: false,
      );
      final json = item.toJson();
      final restored = ThreadItem.fromJson(json);
      expect(restored.tid, 123);
      expect(restored.title, '测试标题');
      expect(restored.author, '作者');
      expect(restored.authorId, 456);
      expect(restored.avatar, 'https://ycoo.net/avatar.png');
      expect(restored.replies, 10);
      expect(restored.views, 100);
      expect(restored.timeText, '昨天 21:20');
      expect(restored.typeName, '综合交流');
      expect(restored.hasAttachment, isTrue);
      expect(restored.fid, 2);
      expect(restored.price, 5);
      expect(restored.isReward, isFalse);
    });

    test('fromJson 容错 null 字段', () {
      final restored = ThreadItem.fromJson({
        'tid': 1,
        'title': 'x',
        'url': 'u',
      });
      expect(restored.tid, 1);
      expect(restored.author, isNull);
      expect(restored.replies, 0);
      expect(restored.hasAttachment, isFalse);
      expect(restored.price, 0);
    });
  });
}
