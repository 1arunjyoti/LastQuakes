import 'package:flutter_test/flutter_test.dart';
import 'package:lastquake/services/secure_http_client.dart';

void main() {
  group('Certificate Pinning Tests', () {
    test('should have certificate pins configured', () {
      // Test that pins are configured for required domains
      final usgsPins = SecureHttpClient.getPinsForHost('earthquake.usgs.gov');
      final backendPins = SecureHttpClient.getPinsForHost('lastquakenotify.onrender.com');
      
      expect(usgsPins, isNotNull);
      expect(usgsPins!.isNotEmpty, true);
      expect(backendPins, isNotNull);
      expect(backendPins!.isNotEmpty, true);
      
      // Verify pins are not placeholder values
      expect(usgsPins.first, isNot(contains('AAAAAAA')));
      expect(backendPins.first, isNot(contains('CCCCCCC')));
    });

    test('should return null for unconfigured domains', () {
      final pins = SecureHttpClient.getPinsForHost('unknown-domain.com');
      expect(pins, isNull);
    });

    test('certificate pins should be valid SHA-256 format', () {
      final usgsPins = SecureHttpClient.getPinsForHost('earthquake.usgs.gov');
      final backendPins = SecureHttpClient.getPinsForHost('lastquakenotify.onrender.com');
      
      for (final pin in usgsPins!) {
        expect(pin, startsWith('sha256/'));
        expect(pin.length, greaterThan(10)); // SHA-256 base64 should be longer
      }
      
      for (final pin in backendPins!) {
        expect(pin, startsWith('sha256/'));
        expect(pin.length, greaterThan(10)); // SHA-256 base64 should be longer
      }
    });
  });
}