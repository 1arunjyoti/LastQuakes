import 'package:flutter_test/flutter_test.dart';
import 'package:lastquakes/models/earthquake.dart';
import 'package:lastquakes/presentation/providers/earthquake_provider.dart';
import 'package:lastquakes/domain/usecases/get_earthquakes_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockGetEarthquakesUseCase extends Mock implements GetEarthquakesUseCase {}

void main() {
  late MockGetEarthquakesUseCase mockGetEarthquakesUseCase;
  late EarthquakeProvider provider;

  setUp(() {
    mockGetEarthquakesUseCase = MockGetEarthquakesUseCase();
    provider = EarthquakeProvider(
      getEarthquakesUseCase: mockGetEarthquakesUseCase,
    );
  });

  final testEarthquakes = [
    Earthquake(
      id: '1',
      place: 'Tokyo, Japan',
      time: DateTime.now(),
      magnitude: 5.5,
      latitude: 35.6,
      longitude: 139.6,
      depth: 10,
      url: 'url',
      source: 'USGS',
      rawData: {},
    ),
    Earthquake(
      id: '2',
      place: 'California, USA',
      time: DateTime.now().subtract(const Duration(hours: 2)),
      magnitude: 4.0,
      latitude: 34.0,
      longitude: -118.2,
      depth: 10,
      url: 'url',
      source: 'USGS',
      rawData: {},
    ),
  ];

  test('loadData fetches earthquakes and updates both list and map', () async {
    when(
      () => mockGetEarthquakesUseCase.call(
        minMagnitude: any(named: 'minMagnitude'),
        days: any(named: 'days'),
        forceRefresh: any(named: 'forceRefresh'),
      ),
    ).thenAnswer((_) async => testEarthquakes);

    await provider.loadData();

    expect(provider.listEarthquakes.length, 2);
    expect(provider.mapEarthquakes.length, 2);
    expect(provider.countryList, contains('Japan'));
    expect(provider.countryList, contains('USA'));
  });

  test('List filters only affect listEarthquakes', () async {
    when(
      () => mockGetEarthquakesUseCase.call(
        minMagnitude: any(named: 'minMagnitude'),
        days: any(named: 'days'),
        forceRefresh: any(named: 'forceRefresh'),
      ),
    ).thenAnswer((_) async => testEarthquakes);

    await provider.loadData();

    provider.setListCountryFilter('Japan');

    // Wait for isolate/async filter
    await Future.delayed(const Duration(milliseconds: 100));

    expect(provider.listEarthquakes.length, 1);
    expect(provider.listEarthquakes.first.place, contains('Japan'));

    // Map should be unaffected
    expect(provider.mapEarthquakes.length, 2);
  });

  test('Map filters only affect mapEarthquakes', () async {
    when(
      () => mockGetEarthquakesUseCase.call(
        minMagnitude: any(named: 'minMagnitude'),
        days: any(named: 'days'),
        forceRefresh: any(named: 'forceRefresh'),
      ),
    ).thenAnswer((_) async => testEarthquakes);

    await provider.loadData();

    provider.setMapFilters(minMagnitude: 5.0);

    // Wait for isolate/async filter
    await Future.delayed(const Duration(milliseconds: 100));

    expect(provider.mapEarthquakes.length, 1);
    expect(provider.mapEarthquakes.first.magnitude, 5.5);

    // List should be unaffected
    expect(provider.listEarthquakes.length, 2);
  });
}
