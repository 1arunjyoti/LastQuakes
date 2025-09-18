import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Script to get backup certificate pins from certificate authorities
/// This helps create more resilient pinning that survives certificate renewals
void main() async {
  if (kDebugMode) {
    print('🔐 Backup Certificate Pin Extractor');
  }
  if (kDebugMode) {
    print('=' * 50);
  }

  final domains = [
    'earthquake.usgs.gov',
    'lastquakenotify.onrender.com',
  ];

  for (final domain in domains) {
    if (kDebugMode) {
      print('\n📍 Getting certificate chain for: $domain');
    }
    await getCertificateChain(domain);
  }

  if (kDebugMode) {
    print('\n✅ Backup pin extraction complete!');
  }
  if (kDebugMode) {
    print('\n💡 TIP: Use intermediate CA pins as backup pins for better stability');
  }
}

Future<void> getCertificateChain(String domain) async {
  try {
    final socket = await SecureSocket.connect(
      domain,
      443,
      onBadCertificate: (cert) => true, // Accept all for analysis
    );

    // Get the full certificate chain
    final peerCert = socket.peerCertificate;
    if (peerCert != null) {
      if (kDebugMode) {
        print('  📜 Server Certificate:');
      }
      _printCertificateInfo(peerCert, '    ');
      
      // Note: Getting the full chain requires more complex implementation
      // For now, we'll show how to manually get intermediate CA pins
      if (kDebugMode) {
        print('  \n  💡 To get intermediate CA pins:');
      }
      if (kDebugMode) {
        print('     1. Visit https://$domain in browser');
      }
      if (kDebugMode) {
        print('     2. Click lock icon → Certificate → Details');
      }
      if (kDebugMode) {
        print('     3. Export intermediate certificates');
      }
      if (kDebugMode) {
        print('     4. Calculate SHA-256 of public key');
      }
    }

    await socket.close();
  } catch (e) {
    if (kDebugMode) {
      print('  ❌ Error connecting to $domain: $e');
    }
  }
}

void _printCertificateInfo(X509Certificate cert, String indent) {
  final certBytes = cert.der;
  final certHash = sha256.convert(certBytes);
  final certPin = 'sha256/${base64.encode(certHash.bytes)}';
  
  if (kDebugMode) {
    print('${indent}Pin: $certPin');
  }
  if (kDebugMode) {
    print('${indent}Subject: ${cert.subject}');
  }
  if (kDebugMode) {
    print('${indent}Issuer: ${cert.issuer}');
  }
  if (kDebugMode) {
    print('${indent}Valid: ${cert.startValidity} → ${cert.endValidity}');
  }
}