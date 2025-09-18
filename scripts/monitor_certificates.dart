import 'dart:io';

import 'package:flutter/foundation.dart';

/// Certificate expiration monitoring script
/// Run this periodically to check when certificates need updating
void main() async {
  if (kDebugMode) {
    print('📅 Certificate Expiration Monitor');
  }
  if (kDebugMode) {
    print('=' * 40);
  }

  final domains = [
    'earthquake.usgs.gov',
    'lastquakenotify.onrender.com',
  ];

  for (final domain in domains) {
    await checkCertificateExpiration(domain);
  }

  if (kDebugMode) {
    print('\n💡 Set up automated monitoring:');
  }
  if (kDebugMode) {
    print('   - Add this script to your CI/CD pipeline');
  }
  if (kDebugMode) {
    print('   - Run monthly to check expiration dates');
  }
  if (kDebugMode) {
    print('   - Set alerts for certificates expiring in 30 days');
  }
}

Future<void> checkCertificateExpiration(String domain) async {
  try {
    if (kDebugMode) {
      print('\n🔍 Checking: $domain');
    }
    
    final socket = await SecureSocket.connect(
      domain,
      443,
      timeout: Duration(seconds: 10),
      onBadCertificate: (cert) => true,
    );

    final cert = socket.peerCertificate;
    if (cert != null) {
      final now = DateTime.now();
      final expiry = cert.endValidity;
      final daysUntilExpiry = expiry.difference(now).inDays;
      
      String status;
      String emoji;
      
      if (daysUntilExpiry < 0) {
        status = 'EXPIRED';
        emoji = '🚨';
      } else if (daysUntilExpiry < 30) {
        status = 'EXPIRES SOON';
        emoji = '⚠️';
      } else if (daysUntilExpiry < 90) {
        status = 'MONITOR';
        emoji = '📅';
      } else {
        status = 'OK';
        emoji = '✅';
      }
      
      if (kDebugMode) {
        print('  $emoji Status: $status');
      }
      if (kDebugMode) {
        print('  📅 Expires: $expiry');
      }
      if (kDebugMode) {
        print('  ⏰ Days remaining: $daysUntilExpiry');
      }
      
      if (daysUntilExpiry < 30) {
        if (kDebugMode) {
          print('  🚨 ACTION REQUIRED: Update certificate pins soon!');
        }
        if (kDebugMode) {
          print('  📝 Run: dart run scripts/get_certificate_pins.dart');
        }
      }
    }

    await socket.close();
  } catch (e) {
    if (kDebugMode) {
      print('  ❌ Error checking $domain: $e');
    }
  }
}