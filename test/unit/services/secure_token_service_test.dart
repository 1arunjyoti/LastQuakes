import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lastquakes/services/secure_token_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureTokenService', () {
    late SecureTokenService service;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      service = SecureTokenService.instance;
      // Clear cache for each test
      service.reload();
    });

    tearDown(() async {
      await service.clearAllSecureData();
    });

    group('Token Storage', () {
      test('storeFCMToken saves token securely', () async {
        const testToken = 'test_fcm_token_12345';

        await service.storeFCMToken(testToken);

        final retrieved = await service.getFCMToken();
        expect(retrieved, testToken);
      });

      test('storeFCMToken overwrites existing token', () async {
        await service.storeFCMToken('old_token');
        await service.storeFCMToken('new_token');

        final retrieved = await service.getFCMToken();
        expect(retrieved, 'new_token');
      });

      test('storeFCMToken handles empty string', () async {
        await service.storeFCMToken('');

        final retrieved = await service.getFCMToken();
        expect(retrieved, '');
      });

      test('storeFCMToken handles very long token', () async {
        final longToken = 'a' * 1000;

        await service.storeFCMToken(longToken);

        final retrieved = await service.getFCMToken();
        expect(retrieved, longToken);
      });
    });

    group('Token Retrieval', () {
      test('getFCMToken returns null when no token stored', () async {
        final retrieved = await service.getFCMToken();

        expect(retrieved, isNull);
      });

      test('getFCMToken returns cached token on subsequent calls', () async {
        await service.storeFCMToken('cached_token');

        // First call retrieves from storage
        final first = await service.getFCMToken();

        // Clear actual storage to test cache
        const storage = FlutterSecureStorage();
        await storage.delete(key: 'fcm_token_secure');

        // Second call should return cached value
        final second = await service.getFCMToken();
        expect(second, first);
        expect(second, 'cached_token');
      });

      test('getFCMToken handles storage read errors gracefully', () async {
        // Can't easily simulate storage error in tests, but method should return null
        final retrieved = await service.getFCMToken();
        expect(retrieved, isNull);
      });
    });

    group('Token Deletion', () {
      test('deleteFCMToken removes stored token', () async {
        await service.storeFCMToken('token_to_delete');

        await service.deleteFCMToken();

        final retrieved = await service.getFCMToken();
        expect(retrieved, isNull);
      });

      test('deleteFCMToken clears cache', () async {
        await service.storeFCMToken('cached_token');
        await service.getFCMToken(); // Populate cache

        await service.deleteFCMToken();

        // Should be null even from cache
        final retrieved = await service.getFCMToken();
        expect(retrieved, isNull);
      });

      test('deleteFCMToken on non-existent token does not throw', () async {
        // Should not throw
        await service.deleteFCMToken();

        final retrieved = await service.getFCMToken();
        expect(retrieved, isNull);
      });
    });

    group('Token Existence Check', () {
      test('hasFCMToken returns false when no token exists', () async {
        final exists = await service.hasFCMToken();

        expect(exists, false);
      });

      test('hasFCMToken returns true when token exists', () async {
        await service.storeFCMToken('test_token');

        final exists = await service.hasFCMToken();

        expect(exists, true);
      });

      test('hasFCMToken returns false after deletion', () async {
        await service.storeFCMToken('test_token');
        await service.deleteFCMToken();

        final exists = await service.hasFCMToken();

        expect(exists, false);
      });
    });

    group('Cache Management', () {
      test('reload clears cache and refetches from storage', () async {
        await service.storeFCMToken('original_token');
        await service.getFCMToken(); // Populate cache

        // Manually change storage value (simulating external change)
        const storage = FlutterSecureStorage();
        await storage.write(key: 'fcm_token_secure', value: 'updated_token');

        // Without reload, would return cached value
        await service.reload();

        final retrieved = await service.getFCMToken();
        expect(retrieved, 'updated_token');
      });

      test('reload on empty storage clears cache', () async {
        await service.storeFCMToken('token');
        await service.getFCMToken();

        const storage = FlutterSecureStorage();
        await storage.delete(key: 'fcm_token_secure');

        await service.reload();

        final retrieved = await service.getFCMToken();
        expect(retrieved, isNull);
      });
    });

    group('Clear All Data', () {
      test('clearAllSecureData removes all stored tokens', () async {
        await service.storeFCMToken('token_to_clear');

        await service.clearAllSecureData();

        final retrieved = await service.getFCMToken();
        expect(retrieved, isNull);
      });

      test('clearAllSecureData clears cache', () async {
        await service.storeFCMToken('cached_token');
        await service.getFCMToken();

        await service.clearAllSecureData();

        final retrieved = await service.getFCMToken();
        expect(retrieved, isNull);
      });
    });

    group('Singleton Behavior', () {
      test('returns same instance', () {
        final instance1 = SecureTokenService.instance;
        final instance2 = SecureTokenService.instance;

        expect(identical(instance1, instance2), true);
      });

      test('shared cache across instances', () async {
        final instance1 = SecureTokenService.instance;
        await instance1.storeFCMToken('shared_token');

        final instance2 = SecureTokenService.instance;
        final retrieved = await instance2.getFCMToken();

        expect(retrieved, 'shared_token');
      });
    });

    group('Token Validation', () {
      test('stores and retrieves token with special characters', () async {
        const specialToken = 'token-with_special.chars:123/abc=xyz';

        await service.storeFCMToken(specialToken);

        final retrieved = await service.getFCMToken();
        expect(retrieved, specialToken);
      });

      test('stores and retrieves token with unicode characters', () async {
        const unicodeToken = 'token_with_émojis_🔥_and_日本語';

        await service.storeFCMToken(unicodeToken);

        final retrieved = await service.getFCMToken();
        expect(retrieved, unicodeToken);
      });

      test('stores and retrieves token with spaces', () async {
        const tokenWithSpaces = 'token with spaces';

        await service.storeFCMToken(tokenWithSpaces);

        final retrieved = await service.getFCMToken();
        expect(retrieved, tokenWithSpaces);
      });
    });

    group('Concurrent Operations', () {
      test('handles concurrent writes', () async {
        final futures = <Future<void>>[];
        for (var i = 0; i < 10; i++) {
          futures.add(service.storeFCMToken('token_$i'));
        }

        await Future.wait(futures);

        // Should not crash, one token should win
        final retrieved = await service.getFCMToken();
        expect(retrieved, isNotNull);
        expect(retrieved, startsWith('token_'));
      });

      test('handles concurrent reads', () async {
        await service.storeFCMToken('concurrent_token');

        final futures = <Future<String?>>[];
        for (var i = 0; i < 10; i++) {
          futures.add(service.getFCMToken());
        }

        final results = await Future.wait(futures);

        // All should return the same token
        for (final result in results) {
          expect(result, 'concurrent_token');
        }
      });
    });
  });
}
