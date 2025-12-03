import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastquakes/utils/secure_logger.dart';

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
      expect(logs.single, equals('🔐 Token stored: 12345678...[REDACTED]'));
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

    test('sanitizes email addresses in data values', () {
      final sanitized = SecureLogger.sanitizeData({
        'message': 'Contact user@example.com for details',
      });

      expect(sanitized.contains('user@example.com'), isFalse);
      expect(sanitized.contains('[EMAIL]'), isTrue);
    });

    test('sanitizes coordinate patterns in data values', () {
      final sanitized = SecureLogger.sanitizeData({
        'location': 'Position at 37.7749295, -122.4194155',
      });

      expect(sanitized.contains('37.7749295'), isFalse);
      expect(sanitized.contains('[COORD]'), isTrue);
    });
  });

  group('SecureLogger PII sanitization in messages', () {
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

    test('info sanitizes coordinates in message', () {
      SecureLogger.info('User location: 37.7749295, -122.4194155');
      expect(logs.single?.contains('37.7749295'), isFalse);
      expect(logs.single?.contains('[COORD]'), isTrue);
    });

    test('error sanitizes email addresses', () {
      SecureLogger.error('Failed for user@example.com');
      expect(logs.single?.contains('user@example.com'), isFalse);
      expect(logs.single?.contains('[EMAIL]'), isTrue);
    });

    test('warning sanitizes IP addresses', () {
      SecureLogger.warning('Connection from 192.168.1.100');
      expect(logs.single?.contains('192.168.1.100'), isFalse);
      expect(logs.single?.contains('[IP]'), isTrue);
    });

    test('location sanitizes accidentally included coordinates', () {
      SecureLogger.location('At 37.7749295 latitude');
      expect(logs.single?.contains('37.7749295'), isFalse);
      expect(logs.single?.contains('[COORD]'), isTrue);
    });
  });

  group('SecureLogger additional sensitive fields', () {
    test('sanitizes device_id field', () {
      final sanitized = SecureLogger.sanitizeData({
        'device_id': 'abc123def456ghi789',
      });
      expect(sanitized.contains('abc***789'), isTrue);
    });

    test('sanitizes email field', () {
      final sanitized = SecureLogger.sanitizeData({
        'email': 'longemailtestvalue',
      });
      expect(sanitized.contains('lon***lue'), isTrue);
    });

    test('sanitizes session field', () {
      final sanitized = SecureLogger.sanitizeData({
        'session_token': 'sessionvalue123',
      });
      expect(sanitized.contains('ses***123'), isTrue);
    });
  });
}
