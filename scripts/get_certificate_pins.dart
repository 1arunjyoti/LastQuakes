import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Script to get certificate pins for your domains
/// Run this script to get the actual SHA-256 pins for your certificate pinning implementation
void main() async {
  final domains = [
    'earthquake.usgs.gov',
    'lastquakenotify.onrender.com',
  ];

  if (kDebugMode) {
    print('🔐 Certificate Pin Extractor');
  }
  if (kDebugMode) {
    print('=' * 50);
  }

  for (final domain in domains) {
    if (kDebugMode) {
      print('\n📍 Getting certificate pins for: $domain');
    }
    await getCertificatePins(domain);
  }

  if (kDebugMode) {
    print('\n✅ Certificate pin extraction complete!');
  }
  if (kDebugMode) {
    print('\n⚠️  IMPORTANT: Update the pins in lib/services/secure_http_client.dart');
  }
  if (kDebugMode) {
    print('   Replace the placeholder pins with the actual pins shown above.');
  }
}

Future<void> getCertificatePins(String domain) async {
  try {
    final socket = await SecureSocket.connect(
      domain,
      443,
      onBadCertificate: (cert) => true, // Accept all certificates for pin extraction
    );

    final cert = socket.peerCertificate;
    if (cert != null) {
      // Get the certificate's DER-encoded bytes
      final certBytes = cert.der;
      
      // Calculate SHA-256 hash of the certificate
      final certHash = sha256.convert(certBytes);
      final certPin = 'sha256/${base64.encode(certHash.bytes)}';
      
      if (kDebugMode) {
        print('  📜 Certificate Pin: $certPin');
      }
      if (kDebugMode) {
        print('  📅 Valid from: ${cert.startValidity}');
      }
      if (kDebugMode) {
        print('  📅 Valid until: ${cert.endValidity}');
      }
      if (kDebugMode) {
        print('  🏢 Subject: ${cert.subject}');
      }
      if (kDebugMode) {
        print('  🏢 Issuer: ${cert.issuer}');
      }
      
      // Also try to get the public key pin (more stable)
      try {
        // This is a simplified approach - in production you'd want to extract the actual public key
        if (kDebugMode) {
          print('  ℹ️  Note: This is the certificate pin. For production, consider using public key pins.');
        }
      } catch (e) {
        if (kDebugMode) {
          print('  ⚠️  Could not extract public key pin: $e');
        }
      }
    } else {
      if (kDebugMode) {
        print('  ❌ Could not retrieve certificate');
      }
    }

    await socket.close();
  } catch (e) {
    if (kDebugMode) {
      print('  ❌ Error connecting to $domain: $e');
    }
  }
}