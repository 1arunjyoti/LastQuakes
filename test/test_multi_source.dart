// Simple test file to verify multi-source functionality
// This is not a unit test, just a verification script

// ignore_for_file: avoid_print

import 'package:flutter/widgets.dart';
import 'package:lastquake/services/multi_source_api_service.dart';
import 'package:lastquake/utils/enums.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('Testing Multi-Source API Service...');

  final service = await MultiSourceApiService.create();

  // Test 1: Single source (USGS only)
  print('\n--- Test 1: USGS Only ---');
  await service.setSelectedSources({DataSource.usgs});
  var sources = service.getSelectedSources();
  print('Selected sources: ${sources.map((s) => s.name).join(', ')}');
  

  try {
    var earthquakes = await service.fetchEarthquakes(
      minMagnitude: 4.0, // Lower magnitude for more results
      days: 7,
      forceRefresh: true,
    );
    print('Found ${earthquakes.length} earthquakes from USGS');
    if (earthquakes.isNotEmpty) {
      print(
        'Sample earthquake: ${earthquakes.first.place} (${earthquakes.first.source})',
      );
    }
  } catch (e) {
    print('Error fetching USGS data: $e');
  }

  // Test 2: Single source (EMSC only)
  print('\n--- Test 2: EMSC Only ---');
  await service.setSelectedSources({DataSource.emsc});
  sources = service.getSelectedSources();
  print('Selected sources: ${sources.map((s) => s.name).join(', ')}');

  try {
    var earthquakes = await service.fetchEarthquakes(
      minMagnitude: 4.0, // Lower magnitude for more results
      days: 7,
      forceRefresh: true,
    );
    print('Found ${earthquakes.length} earthquakes from EMSC');
    if (earthquakes.isNotEmpty) {
      print(
        'Sample earthquake: ${earthquakes.first.place} (${earthquakes.first.source})',
      );
      print(
        'Sample earthquake details: M${earthquakes.first.magnitude} at ${earthquakes.first.time}',
      );
    }
  } catch (e) {
    print('Error fetching EMSC data: $e');
  }

  // Test 3: Multiple sources
  print('\n--- Test 3: Both Sources ---');
  await service.setSelectedSources({DataSource.usgs, DataSource.emsc});
  sources = service.getSelectedSources();
  print('Selected sources: ${sources.map((s) => s.name).join(', ')}');

  try {
    var earthquakes = await service.fetchEarthquakes(
      minMagnitude: 4.0, // Lower magnitude for more results
      days: 7,
      forceRefresh: true,
    );
    print('Found ${earthquakes.length} earthquakes from both sources');

    // Count by source
    var usgsCount = earthquakes.where((e) => e.source == 'USGS').length;
    var emscCount = earthquakes.where((e) => e.source == 'EMSC').length;
    print('USGS: $usgsCount, EMSC: $emscCount');

    if (earthquakes.isNotEmpty) {
      print('Sample earthquakes:');
      for (var i = 0; i < 5 && i < earthquakes.length; i++) {
        var eq = earthquakes[i];
        print(
          '  ${eq.place} - M${eq.magnitude.toStringAsFixed(1)} (${eq.source})',
        );
      }
    }
  } catch (e) {
    print('Error fetching multi-source data: $e');
  }

  // Test 4: Check for duplicates
  print('\n--- Test 4: Duplicate Detection ---');
  var hasMultiple = service.hasMultipleSources();
  print('Has multiple sources: $hasMultiple');

  print('\nTesting complete!');
}
