// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Extract issuer certificate pins
void main() async {
  final domains = [
    ('earthquake.usgs.gov', 'DigiCert Global G2 TLS RSA SHA256 2020 CA1'),
    ('lastquakenotify.onrender.com', 'Google Trust Services WE1'),
  ];

  print('🔐 Issuer Certificate Pin Extractor');
  print('=' * 50);

  for (final (domain, issuerName) in domains) {
    print('\n📍 Getting issuer pin for: $domain ($issuerName)');
    await getIssuerPin(domain);
  }

  print('\n✅ Issuer pin extraction complete!');
}

Future<void> getIssuerPin(String domain) async {
  try {
    final socket = await SecureSocket.connect(
      domain,
      443,
      onBadCertificate: (cert) => true,
    );

    // Get peer certificates - there should be multiple in the chain
    final peerCert = socket.peerCertificate;
    if (peerCert != null) {
      // Try to get the certificate chain
      final certs = await fetchCertificateChain(domain);
      
      if (certs.length > 1) {
        // Get the issuer certificate (second in chain)
        final issuerCert = certs[1];
        final issuerBytes = issuerCert.der;
        final issuerHash = sha256.convert(issuerBytes);
        final issuerPin = 'sha256/${base64.encode(issuerHash.bytes)}';
        
        print('  📜 Issuer Certificate Pin: $issuerPin');
        print('  🏢 Issuer: ${issuerCert.issuer}');
      } else {
        print('  ⚠️  Only single certificate in chain, using issuer subject as fallback');
        print('  📜 Certificate Issuer Subject: ${peerCert.issuer}');
      }
    }

    await socket.close();
  } catch (e) {
    print('  ❌ Error: $e');
  }
}

Future<List<X509Certificate>> fetchCertificateChain(String domain) async {
  try {
    final socket = await SecureSocket.connect(
      domain,
      443,
      onBadCertificate: (cert) => true,
    );
    
    // Get the peer certificate
    final peerCert = socket.peerCertificate;
    await socket.close();
    
    if (peerCert != null) {
      return [peerCert];
    }
    return [];
  } catch (e) {
    print('  Error fetching certificate chain: $e');
    return [];
  }
}
