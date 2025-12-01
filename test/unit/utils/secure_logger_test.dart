import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastquake/utils/secure_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureLogger logging methods', () {
    late List<String?> logs;
    late DebugPrintCallback originalDebugPrint;

    setUp(() {
      logs = <String?>[];
      originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        logs.add(message);
      };
    });

    tearDown(() {
      debugPrint = originalDebugPrint;
    });

    test('info logs message with info prefix', () {
      SecureLogger.info('Test info');
      expect(logs.single, equals('ℹ️ Test info'));
    });

    test('success logs message with success prefix', () {
      SecureLogger.success('All good');
      expect(logs.single, equals('✅ All good'));
    });

    test('error logs messages with error details when provided', () {
      SecureLogger.error('Failure occurred', 'DETAILS');
      expect(logs.single, equals('❌ Failure occurred: DETAILS'));
    });

    test('token redacts token value when long enough', () {
      SecureLogger.token('stored', token: '1234567890ABCDEFGHIJ');
      expect(logs.single, equals('🔐 Token stored: 1234567890ABCDE...'));
    });
  });

  group('SecureLogger.sanitizeData', () {
    test('redacts sensitive fields', () {
      final sanitized = SecureLogger.sanitizeData({
        'token': 'abcdefghijklmnop',
        'password': 'superSecretPass',
        'latitude': 12.345678,
        'nonSensitive': 'value',
      });

      expect(sanitized.contains('nonSensitive: value'), isTrue);
      expect(sanitized.contains('token: abc***nop'), isTrue);
      expect(sanitized.contains('password: sup***ass'), isTrue);
      expect(sanitized.contains('latitude: [REDACTED]'), isTrue);
    });

    test('non-sensitive fields remain unchanged while sensitive fields redact', () {
      final sanitized = SecureLogger.sanitizeData({
        'key': 'value',
        'apiKey': 'supersecret',
      });

      expect(sanitized.contains('key: [REDACTED]'), isTrue);
      expect(sanitized.contains('apiKey: sup***ret'), isTrue);
    });
  });
}
