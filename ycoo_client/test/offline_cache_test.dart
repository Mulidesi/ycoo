import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ycoo_client/core/services/download_manager.dart';
import 'package:ycoo_client/core/services/offline_cache.dart';
import 'package:ycoo_client/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineThreadCache', () {
    late OfflineThreadCache cache;
    late Directory testDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      testDir = await Directory.systemTemp.createTemp('ycoo_offline_test');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationSupportDirectory') {
          return testDir.path;
        }
        return null;
      });
      cache = OfflineThreadCache.instance;
    });

    tearDown(() async {
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    test('list() returns empty when no cache', () async {
      final items = await cache.list();
      expect(items, isEmpty);
    });

    test('get() returns null for unknown tid', () async {
      final result = await cache.get(99999);
      expect(result, isNull);
    });

    test('save() creates cache entry and list() finds it', () async {
      final posts = <Post>[
        const Post(
          pid: 1,
          author: 'testuser',
          contentHtml: '<p>test content</p>',
          floor: '1',
        ),
      ];
      await cache.save(
        tid: 12345,
        title: 'Test Thread',
        boardName: 'test-board',
        author: 'testuser',
        time: '2026-01-01',
        views: 100,
        replies: 5,
        posts: posts,
      );
      final items = await cache.list();
      expect(items.length, 1);
      expect(items.first['title'], 'Test Thread');
      expect(items.first['boardName'], 'test-board');
      expect(items.first['tid'], 12345);
    });

    test('get() returns saved thread data', () async {
      final posts = <Post>[
        const Post(
          pid: 1,
          author: 'testuser',
          contentHtml: '<p>test</p>',
          floor: '1',
        ),
      ];
      await cache.save(
        tid: 55555,
        title: 'Another Thread',
        boardName: 'another',
        author: 'testuser',
        time: '2026-01-02',
        views: 50,
        replies: 3,
        posts: posts,
      );
      final result = await cache.get(55555);
      expect(result, isNotNull);
      expect(result!['title'], 'Another Thread');
      expect(result['posts'], isA<List>());
      expect((result['posts'] as List).length, 1);
    });

    test('delete() removes cache entry', () async {
      final posts = <Post>[
        const Post(pid: 1, author: 'u', contentHtml: '<p>x</p>', floor: '1'),
      ];
      await cache.save(
        tid: 77777,
        title: 'To Delete',
        boardName: 'b',
        author: 'u',
        time: '2026-01-03',
        views: 1,
        replies: 0,
        posts: posts,
      );
      await cache.delete(77777);
      final items = await cache.list();
      expect(items.whereType<Map>().any((m) => m['tid'] == 77777), isFalse);
    });

    test('estimateBytes() returns positive number', () {
      final item = <String, dynamic>{
        'tid': 1,
        'title': 'Test',
        'boardName': 'Board',
        'author': 'Author',
        'time': '2026-01-01',
        'views': 100,
        'replies': 5,
        'cachedAt': DateTime.now().toIso8601String(),
        'posts': [],
        'imageMap': {},
      };
      final bytes = cache.estimateBytes(item);
      expect(bytes, greaterThan(0));
    });
  });

  group('DownloadManager', () {
    late DownloadManager manager;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ycoo_download_history_v1');
      manager = DownloadManager.instance;
      manager.records.clear();
      manager.initialized = false;
    });

    test('load() initializes with empty records', () async {
      await manager.load();
      expect(manager.records, isEmpty);
      expect(manager.initialized, isTrue);
    });

    test('load() restores interrupted downloads', () async {
      final prefs = await SharedPreferences.getInstance();
      final interruptedRecord = <String, dynamic>{
        'url': 'https://example.com/file.zip',
        'path': '/tmp/downloads/file.zip',
        'name': 'file.zip',
        'time': DateTime.now().toIso8601String(),
        'status': 'downloading',
        'receivedBytes': 500,
        'totalBytes': 1000,
        'error': '',
      };
      await prefs.setStringList(
        'ycoo_download_history_v1',
        [jsonEncode(interruptedRecord)],
      );
      manager.records.clear();
      manager.initialized = false;
      await manager.load();
      expect(manager.records.length, 1);
      expect(manager.records.first.status, 'interrupted');
      expect(manager.records.first.error, isNotEmpty);
    });

    test('remove() persists and removes records', () async {
      const record = DownloadRecord(
        url: 'https://example.com/test.pdf',
        path: '/tmp/test.pdf',
        name: 'test.pdf',
        time: '2026-01-01T00:00:00',
        status: 'completed',
        receivedBytes: 100,
        totalBytes: 100,
      );
      manager.records.add(record);
      await manager.remove(record);
      expect(manager.records, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final values = prefs.getStringList('ycoo_download_history_v1') ?? [];
      expect(values, isEmpty);
    });

    test('DownloadRecord copyWith updates fields', () {
      const record = DownloadRecord(
        url: 'https://example.com/file.zip',
        path: '/tmp/file.zip',
        name: 'file.zip',
        time: '2026-01-01T00:00:00',
        status: 'downloading',
        receivedBytes: 500,
        totalBytes: 1000,
      );
      final updated = record.copyWith(
        status: 'completed',
        receivedBytes: 1000,
        error: '',
      );
      expect(updated.status, 'completed');
      expect(updated.receivedBytes, 1000);
      expect(updated.error, '');
      expect(updated.url, record.url);
      expect(updated.path, record.path);
      expect(updated.name, record.name);
    });

    test('DownloadRecord toJson/fromJson roundtrip', () {
      const record = DownloadRecord(
        url: 'https://example.com/file.zip',
        path: '/tmp/file.zip',
        name: 'file.zip',
        time: '2026-01-01T00:00:00',
        status: 'completed',
        receivedBytes: 1000,
        totalBytes: 1000,
        error: '',
      );
      final json = record.toJson();
      final restored = DownloadRecord.fromJson(json);
      expect(restored.url, record.url);
      expect(restored.path, record.path);
      expect(restored.name, record.name);
      expect(restored.status, record.status);
      expect(restored.receivedBytes, record.receivedBytes);
      expect(restored.totalBytes, record.totalBytes);
    });
  });
}
