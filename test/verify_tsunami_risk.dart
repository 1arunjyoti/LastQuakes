// Test file to verify tsunami risk assessment logic
// Run with: dart run test/verify_tsunami_risk.dart

import 'package:flutter/foundation.dart';
import 'package:lastquakes/models/earthquake.dart';

void main() {
  if (kDebugMode) {
    print('=== Tsunami Risk Assessment Logic Verification ===\n');
  }

  // Test Case 1: M7.6 Japan earthquake with tsunami flag (should be HIGH)
  testCase(
    name: 'M7.6 Japan (tsunami=1)',
    magnitude: 7.6,
    depth: 53.0,
    place: '73 km ENE of Misawa, Japan',
    tsunami: 1,
    expectedRisk: TsunamiRisk.high,
  );

  // Test Case 2: M7.0 ocean without flag (should be HIGH - mag + shallow + oceanic)
  testCase(
    name: 'M7.0 Pacific Ocean shallow',
    magnitude: 7.0,
    depth: 15.0,
    place: 'South Pacific Ocean',
    tsunami: null,
    expectedRisk: TsunamiRisk.high,
  );

  // Test Case 3: M5.8 inland China (should be LOW or NONE)
  testCase(
    name: 'M5.8 China inland',
    magnitude: 5.8,
    depth: 10.0,
    place: '138 km NNW of Tumxuk, China',
    tsunami: 0,
    expectedRisk: TsunamiRisk.low,
  );

  // Test Case 4: M6.8 Mid-Atlantic Ridge (should be MODERATE)
  testCase(
    name: 'M6.8 Mid-Atlantic Ridge',
    magnitude: 6.8,
    depth: 25.0,
    place: 'Mid-Atlantic Ridge',
    tsunami: null,
    expectedRisk: TsunamiRisk.moderate,
  );

  // Test Case 5: M4.5 Nevada (should be NONE - landlocked + small mag)
  testCase(
    name: 'M4.5 Nevada',
    magnitude: 4.5,
    depth: 8.0,
    place: 'Southern Nevada',
    tsunami: null,
    expectedRisk: TsunamiRisk.none,
  );

  // Test Case 6: M7.5 deep earthquake (should be LOW - deep >100km strongly reduces risk)
  testCase(
    name: 'M7.5 Deep (150km)',
    magnitude: 7.5,
    depth: 150.0,
    place: 'Fiji Islands Region',
    tsunami: null,
    expectedRisk:
        TsunamiRisk.low, // Deep quakes rarely generate tsunamis per NOAA
  );

  // Test Case 7: M6.5 coastal shallow (should be MODERATE)
  testCase(
    name: 'M6.5 Coastal shallow',
    magnitude: 6.5,
    depth: 20.0,
    place: 'Near coast of Peru',
    tsunami: null,
    expectedRisk: TsunamiRisk.moderate,
  );

  // Test Case 8: M8.0 Trench (should be HIGH)
  testCase(
    name: 'M8.0 Trench shallow',
    magnitude: 8.0,
    depth: 20.0,
    place: 'Mariana Trench region',
    tsunami: null,
    expectedRisk: TsunamiRisk.high,
  );

  if (kDebugMode) {
    print('\n=== Summary ===');
  }
  if (kDebugMode) {
    print('All test cases completed. Review results above.');
  }
}

void testCase({
  required String name,
  required double magnitude,
  required double depth,
  required String place,
  required int? tsunami,
  required TsunamiRisk expectedRisk,
}) {
  final eq = Earthquake(
    id: 'test',
    magnitude: magnitude,
    place: place,
    time: DateTime.now(),
    latitude: 0.0,
    longitude: 0.0,
    depth: depth,
    tsunami: tsunami,
    source: 'USGS',
    rawData: {},
  );

  final actualRisk = eq.tsunamiRisk;
  final passed = actualRisk == expectedRisk;
  final status = passed ? '✅ PASS' : '❌ FAIL';

  if (kDebugMode) {
    print('$status: $name');
  }
  if (kDebugMode) {
    print(
      '   Expected: ${expectedRisk.name.toUpperCase()}, Got: ${actualRisk.name.toUpperCase()}',
    );
  }
  if (kDebugMode) {
    print('   Factors: ${eq.tsunamiRiskFactors.join(", ")}');
  }
  if (kDebugMode) {
    print('');
  }
}
