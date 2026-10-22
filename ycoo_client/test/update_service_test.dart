import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ycoo_client/core/update_service.dart';
import 'package:ycoo_client/data/update_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ycoo_update_test');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getTemporaryDirectory') return tempDir.path;
      return null;
    });
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  final apkBytes = utf8.encode('fake apk content');
  final apkSha = sha256.convert(apkBytes).toString();
  final info = ReleaseInfo(
    version: '1.0.17',
    apkUrl:
        'https://github.com/Mulidesi/ycoo/releases/download/v1.0.17/ycoo-client-1.0.17.apk',
    size: apkBytes.length,
    sha256: apkSha,
  );

  test('加速线路失败后回退直连并校验文件', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add(request.url.toString());
      if (request.url.host == 'gproxy.mulides.cc.cd') {
        return http.Response('', 502);
      }
      return http.Response.bytes(apkBytes, 200, headers: {
        'content-type': 'application/vnd.android.package-archive',
      });
    });
    final service = UpdateService(client: client);
    final progress = <int>[];
    final file = await service.download(
      info,
      onProgress: (received, total) => progress.add(received),
    );

    expect(await file.readAsBytes(), apkBytes);
    expect(file.path, contains(tempDir.path));
    expect(calls.length, 2);
    expect(calls.first, startsWith(updateProxyPrefix));
    expect(progress.last, apkBytes.length);
    service.close();
  });

  test('SHA-256 不符时报错并清理文件', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'gproxy.mulides.cc.cd') {
        return http.Response('', 502);
      }
      return http.Response.bytes(
        utf8.encode('tampered'),
        200,
      );
    });
    final service = UpdateService(client: client);
    await expectLater(service.download(info), throwsA(isA<UpdateException>()));
    final dir = Directory('${tempDir.path}/updates');
    expect(dir.existsSync() && dir.listSync().isNotEmpty, isFalse);
    service.close();
  });

  test('取消下载时抛出 UpdateCancelled', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'gproxy.mulides.cc.cd') {
        return http.Response('', 502);
      }
      return http.Response.bytes(apkBytes, 200);
    });
    final service = UpdateService(client: client);
    var cancelled = false;
    await expectLater(
      service.download(
        info,
        isCancelled: () => cancelled = true,
      ),
      throwsA(isA<UpdateCancelled>()),
    );
    expect(cancelled, isTrue);
    service.close();
  });
}
