// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Standalone script to extract certificate pins
void main() async {
  final domains = [
    'earthquake.usgs.gov',
    'lastquakenotify.onrender.com',
  ];

  print('🔐 Certificate Pin Extractor');
  print('=' * 50);

  for (final domain in domains) {
    print('\n📍 Getting certificate pins for: $domain');
    await getCertificatePins(domain);
  }

  print('\n✅ Certificate pin extraction complete!');
  print('\n⚠️  IMPORTANT: Update the pins in lib/services/secure_http_client.dart');
  print('   Replace the placeholder pins with the actual pins shown above.');
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
      
      print('  📜 Certificate Pin: $certPin');
      print('  📅 Valid from: ${cert.startValidity}');
      print('  📅 Valid until: ${cert.endValidity}');
      print('  🏢 Subject: ${cert.subject}');
      print('  🏢 Issuer: ${cert.issuer}');
      
      // Also get issuer certificate pin for backup
      print('\n  Getting issuer chain...');
    } else {
      print('  ❌ Could not retrieve certificate');
    }

    await socket.close();
  } catch (e) {
    print('  ❌ Error connecting to $domain: $e');
  }
}
