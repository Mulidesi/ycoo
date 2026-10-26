// Minimal integration test: just verify DiscuzClient with baseUrl
// Run with: dart test/test/cookie_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ycoo_client/core/discuz_client.dart';

void main() {
  test('DiscuzClient accepts baseUrl parameter', () {
    // This should compile and pass - just verifying the constructor works
    final client = DiscuzClient(baseUrl: 'https://ycoo.net');
    expect(client.baseUrl, equals('https://ycoo.net'));
  });
}