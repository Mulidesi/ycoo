import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ycoo_client/core/update_service.dart';
import 'package:ycoo_client/data/update_manifest.dart';

void main() {
  group('版本比较', () {
    test('归一化去掉 v 前缀与 build 号', () {
      expect(normalizeVersion('v1.0.17'), '1.0.17');
      expect(normalizeVersion('1.0.17+18'), '1.0.17');
      expect(normalizeVersion(' V2.3.4 '), '2.3.4');
    });

    test('按数字段比较，而不是字符串比较', () {
      expect(isNewerVersion('1.0.10', '1.0.9'), isTrue);
      expect(isNewerVersion('1.0.17', '1.0.16'), isTrue);
      expect(isNewerVersion('1.1', '1.0.99'), isTrue);
      expect(isNewerVersion('1.0.16', '1.0.16'), isFalse);
      expect(isNewerVersion('v1.0.15', '1.0.16'), isFalse);
    });

    test('段数不一致时缺失段按 0 处理', () {
      expect(compareVersions('1.0', '1.0.0'), 0);
      expect(compareVersions('1.0.1', '1.0'), 1);
    });
  });

  group('加速链接', () {
    test('给原始 GitHub 地址加前缀', () {
      const url =
          'https://github.com/Mulidesi/ycoo/releases/download/v1.0.17/a.apk';
      expect(proxiedUrl(url), '$updateProxyPrefix$url');
    });

    test('已带前缀时不重复拼接', () {
      final url = proxiedUrl('https://github.com/a/b.apk');
      expect(proxiedUrl(url), url);
    });
  });

  group('latest.json 解析', () {
    Map<String, Object?> manifest({
      String version = '1.0.17',
      String apkUrl =
          'https://github.com/Mulidesi/ycoo/releases/download/v1.0.17/ycoo-client-1.0.17.apk',
    }) =>
        {
          'version': version,
          'tag': 'v1.0.17',
          'apk_url': apkUrl,
          'size': 12345678,
          'sha256': 'ABC123',
          'notes': '## 更新内容\n- 修复若干问题',
          'published_at': '2026-10-22T00:00:00Z',
        };

    test('读取完整字段', () {
      final info = parseLatestManifest(jsonEncode(manifest()));
      expect(info, isNotNull);
      expect(info!.version, '1.0.17');
      expect(info.size, 12345678);
      expect(info.sha256, 'ABC123');
      expect(info.notes, contains('修复'));
      expect(info.apkFileName, 'ycoo-client-1.0.17.apk');
    });

    test('说明文本去掉 Markdown 标题与列表符号', () {
      final info = parseLatestManifest(jsonEncode(manifest()));
      expect(info!.plainNotes, '更新内容\n• 修复若干问题');
    });

    test('兼容 camelCase 字段', () {
      final info = parseLatestManifest(jsonEncode({
        'version': 'v1.0.18',
        'apkUrl': 'https://github.com/a/b.apk',
        'apkSha256': 'def',
      }));
      expect(info?.version, '1.0.18');
      expect(info?.sha256, 'def');
    });

    test('拒绝非 https 或非 GitHub 域名的安装包', () {
      expect(
        parseLatestManifest(
            jsonEncode(manifest(apkUrl: 'http://github.com/a.apk'))),
        isNull,
      );
      expect(
        parseLatestManifest(
          jsonEncode(manifest(apkUrl: 'https://evil.example.com/a.apk')),
        ),
        isNull,
      );
    });

    test('缺少版本或安装包地址时返回 null', () {
      expect(parseLatestManifest('not json'), isNull);
      expect(parseLatestManifest('{}'), isNull);
    });

    test('apks 数组按 ABI 匹配', () {
      final body = jsonEncode({
        'version': '1.1.3',
        'tag': 'v1.1.3',
        'apks': [
          {
            'abi': 'arm64-v8a',
            'url': 'https://github.com/a/arm64.apk',
            'size': 111,
            'sha256': 'aaa',
          },
          {
            'abi': 'armeabi-v7a',
            'url': 'https://github.com/a/arm.apk',
            'size': 222,
            'sha256': 'bbb',
          },
          {
            'abi': 'x86_64',
            'url': 'https://github.com/a/x64.apk',
            'size': 333,
            'sha256': 'ccc',
          },
        ],
        'notes': '## 更新\n- 修复搜索',
      });
      final info = parseLatestManifest(body, targetAbi: 'armeabi-v7a');
      expect(info, isNotNull);
      expect(info!.version, '1.1.3');
      expect(info.abi, 'armeabi-v7a');
      expect(info.size, 222);
      expect(info.sha256, 'bbb');
      expect(info.apkUrl, 'https://github.com/a/arm.apk');
    });

    test('apks 数组未匹配时回退到 arm64-v8a', () {
      final body = jsonEncode({
        'version': '1.1.3',
        'apks': [
          {'abi': 'arm64-v8a', 'url': 'https://github.com/a/arm64.apk', 'size': 111},
          {'abi': 'x86_64', 'url': 'https://github.com/a/x64.apk', 'size': 333},
        ],
      });
      final info = parseLatestManifest(body, targetAbi: 'armeabi-v7a');
      expect(info, isNotNull);
      expect(info!.abi, 'arm64-v8a');
      expect(info.size, 111);
    });

    test('apks 数组回退到第一项', () {
      final body = jsonEncode({
        'version': '1.1.3',
        'apks': [
          {'abi': 'x86_64', 'url': 'https://github.com/a/x64.apk', 'size': 333},
        ],
      });
      final info = parseLatestManifest(body, targetAbi: 'arm64-v8a');
      expect(info, isNotNull);
      expect(info!.abi, 'x86_64');
      expect(info.size, 333);
    });

    test('兼容旧版单 APK 格式', () {
      final info = parseLatestManifest(jsonEncode(manifest()));
      expect(info, isNotNull);
      expect(info!.abi, isNull);
    });
  });

  group('GitHub API 解析', () {
    final body = jsonEncode({
      'tag_name': 'v1.0.17',
      'body': 'release notes',
      'published_at': '2026-10-22T00:00:00Z',
      'assets': [
        {
          'name': 'checksums.txt',
          'size': 10,
          'browser_download_url': 'https://github.com/a/b.txt'
        },
        {
          'name': 'ycoo-client-1.0.17.apk',
          'size': 25817736,
          'browser_download_url':
              'https://github.com/Mulidesi/ycoo/releases/download/v1.0.17/ycoo-client-1.0.17.apk',
        },
      ],
    });

    test('挑选 APK 资源并带上体积与说明', () {
      final info = parseGitHubRelease(body);
      expect(info, isNotNull);
      expect(info!.version, '1.0.17');
      expect(info.apkFileName, 'ycoo-client-1.0.17.apk');
      expect(info.size, 25817736);
      expect(info.notes, 'release notes');
    });

    test('没有 APK 资源时返回 null', () {
      final info = parseGitHubRelease(jsonEncode({
        'tag_name': 'v1.0.17',
        'assets': [
          {'name': 'a.zip', 'browser_download_url': 'https://github.com/a.zip'},
        ],
      }));
      expect(info, isNull);
    });

    test('GitHub API 按 ABI 过滤 APK 资源', () {
      final body = jsonEncode({
        'tag_name': 'v1.1.3',
        'assets': [
          {
            'name': 'ycoo-client-1.1.3-arm64-v8a.apk',
            'size': 111,
            'browser_download_url': 'https://github.com/a/arm64.apk',
          },
          {
            'name': 'ycoo-client-1.1.3-armeabi-v7a.apk',
            'size': 222,
            'browser_download_url': 'https://github.com/a/arm.apk',
          },
        ],
      });
      final info = parseGitHubRelease(body, targetAbi: 'armeabi-v7a');
      expect(info, isNotNull);
      expect(info!.abi, 'armeabi-v7a');
      expect(info.size, 222);
    });

    test('GitHub API 未匹配 ABI 时回退到第一个 APK', () {
      final body = jsonEncode({
        'tag_name': 'v1.1.3',
        'assets': [
          {
            'name': 'ycoo-client-1.1.3-arm64-v8a.apk',
            'size': 111,
            'browser_download_url': 'https://github.com/a/arm64.apk',
          },
        ],
      });
      final info = parseGitHubRelease(body, targetAbi: 'x86_64');
      expect(info, isNotNull);
      expect(info!.size, 111);
    });
  });

  test('字节数格式化', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2 KB');
    expect(formatBytes(25817736), '24.6 MB');
  });

  group('更新检查线路', () {
    test('latest.json 未声明 charset 时中文说明不乱码', () async {
      final body = jsonEncode({
        'version': '1.0.18',
        'apk_url':
            'https://github.com/Mulidesi/ycoo/releases/download/v1.0.18/ycoo-client-1.0.18.apk',
        'size': 100,
        'notes': '## 修复\n- 隐藏贴标识与自动回复',
      });
      final client = MockClient((_) async => http.Response.bytes(
            utf8.encode(body),
            200,
            headers: const {'content-type': 'application/json'},
          ));
      final service = UpdateService(client: client);
      final info = await service.fetchLatest();
      expect(info.notes, contains('隐藏贴标识与自动回复'));
      expect(info.plainNotes, contains('• 隐藏贴标识与自动回复'));
      service.close();
    });

    test('加速线路失败时回退直连', () async {
      final calls = <String>[];
      final client = MockClient((request) async {
        calls.add(request.url.toString());
        if (request.url.host == 'gproxy.mulides.cc.cd') {
          return http.Response('', 502);
        }
        return http.Response(
          jsonEncode({
            'version': '1.0.17',
            'apk_url':
                'https://github.com/Mulidesi/ycoo/releases/download/v1.0.17/ycoo-client-1.0.17.apk',
            'size': 100,
          }),
          200,
        );
      });
      final service = UpdateService(client: client);
      final info = await service.fetchLatest();
      expect(info.version, '1.0.17');
      expect(calls.first, startsWith(updateProxyPrefix));
      expect(calls.length, greaterThan(1));
      service.close();
    });

    test('全部线路失败时抛出 UpdateException', () async {
      final client = MockClient((_) async => http.Response('not json', 200));
      final service = UpdateService(client: client);
      await expectLater(service.fetchLatest(), throwsA(isA<UpdateException>()));
      service.close();
    });
  });
}
