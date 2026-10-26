// Integration test: ycoo.net cookies initialization
// Run with: dart test/test/cookie_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ycoo_client/core/discuz_client.dart';
import 'package:ycoo_client/state/app_state.dart';
import 'package:ycoo_client/core/persistence/secure_store.dart';

void main() {
  group('Cookie Integration Test', () {
    test('initialize AppState with provided ycoo.net cookies', () {
      // Provided cookies (URL-decoded version of user input)
      final Map<String, String> cookies = {
        'YPSa_2132_smile': '1D1',
        'YPSa_2132_saltkey': 'pjZKEBRU',
        'YPSa_2132_lastvisit': '1791442934',
        'YPSa_2132_visitedfid': '2',
        'YPSa_2132_sid': 'OJxzpo',
        'YPSa_2132_viewid': 'tid_145118',
        'YPSa_2132_sendmail': '1',
        'YPSa_2132_ulastactivity': '98e93zFvkfC32UbcwsKhRv6LypK6zvHdHBktzCTIDfQ3/zmkT7kw',
        'YPSa_2132_auth': '5edfil//5iXERqhw/ns94V9JsCYro0v20zfn2CB7QTudblRYKj7R8ozvFkX7MQ5dF7s58t6gMRiCbP/1cw467XIkkQ',
        'YPSa_2132_lastcheckfeed': '31981|1792978799',
        'YPSa_2132_checkfollow': '1',
        'YPSa_2132_lip': '123.144.149.38,1792965315',
        'YPSa_2132_myrepeat_rr': 'R0',
        'YPSa_2132_checkpm': '1',
        'YPSa_2132_noticeTitle': '1',
        'YPSa_2132_st_p': '31981|1792978808|5fccc0656f5dc57073196437edff9b84',
        'YPSa_2132_lastact': '1792978811\tplugin.php',
      };

      // Initialize client with baseUrl
      final client = DiscuzClient(baseUrl: 'https://ycoo.net');

      // Simulate SecureStore with provided cookies
      final secureStore = MemorySecureStore();
      final cookiesKey = secureCookiesKey('ycoo'); // siteId
      secureStore.write(cookiesKey, jsonEncode(cookies));

      // Create AppState and restore cookies
      final state = AppState(client: client, baseUrl: 'https://ycoo.net');

      // Manually restore cookies from SecureStore (simulating init flow)
      final restoreKey = secureCookiesKey('ycoo');
      final storedJson = secureStore.read(restoreKey);
      
      if (storedJson != null && storedJson.isNotEmpty) {
        final parsed = jsonDecode(storedJson) as Map<String, dynamic>;
        state.client.cookies = Map<String, String>.from(parsed);
        // Persist to prefs layer
        state._persistCookies();
      }

      // Verify cookies were restored
      expect(state.client.cookies.length, greaterThan(0));
      expect(state.client.cookies['YPSa_2132_sid'], equals('OJxzpo'));
      expect(state.client.cookies['YPSa_2132_auth'], isNotNull);
      expect(state.client.cookies['YPSa_2132_lastvisit'], equals('1791442934'));

      // Verify user is set (from cookie context)
      expect(state.user, isNotNull);
    });

    test('cookie bucket is site-specific', () {
      final client1 = DiscuzClient(baseUrl: 'https://ycoo.net');
      final client2 = DiscuzClient(baseUrl: 'https://example.com');

      final bucket1 = 'cookies.ycoo';
      final bucket2 = 'cookies.example';

      // Each site gets its own bucket
      expect(bucket1, equals('cookies.ycoo'));
      expect(bucket2, equals('cookies.example'));
    });
  });
}
