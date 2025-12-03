import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lastquakes/data/repositories/earthquake_repository_impl.dart';
import 'package:lastquakes/services/multi_source_api_service.dart';
import '../../helpers/test_helpers.dart';

class MockMultiSourceApiService extends Mock implements MultiSourceApiService {}

void main() {
  group('EarthquakeRepositoryImpl', () {
    late MockMultiSourceApiService mockApiService;
    late EarthquakeRepositoryImpl repository;

    setUp(() {
      mockApiService = MockMultiSourceApiService();
      repository = EarthquakeRepositoryImpl(mockApiService);
    });

    group('getEarthquakes', () {
      test('forwards call to API service with correct parameters', () async {
        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 5);
        when(
          () => mockApiService.fetchEarthquakes(
            minMagnitude: any(named: 'minMagnitude'),
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => mockEarthquakes);

        await repository.getEarthquakes(
          minMagnitude: 4.0,
          days: 30,
          forceRefresh: true,
        );

        verify(
          () => mockApiService.fetchEarthquakes(
            minMagnitude: 4.0,
            days: 30,
            forceRefresh: true,
          ),
        ).called(1);
      });

      test('returns earthquakes from API service', () async {
        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 10);
        when(
          () => mockApiService.fetchEarthquakes(
            minMagnitude: any(named: 'minMagnitude'),
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => mockEarthquakes);

        final result = await repository.getEarthquakes();

        expect(result.length, 10);
        expect(result, equals(mockEarthquakes));
      });

      test('uses default parameters when not provided', () async {
        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 3);
        when(
          () => mockApiService.fetchEarthquakes(
            minMagnitude: any(named: 'minMagnitude'),
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => mockEarthquakes);

        await repository.getEarthquakes();

        verify(
          () => mockApiService.fetchEarthquakes(
            minMagnitude: 3.0,
            days: 45,
            forceRefresh: false,
          ),
        ).called(1);
      });

      test('propagates errors from API service', () async {
        when(
          () => mockApiService.fetchEarthquakes(
            minMagnitude: any(named: 'minMagnitude'),
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenThrow(Exception('Network error'));

        expect(() => repository.getEarthquakes(), throwsA(isA<Exception>()));
      });

      test('returns empty list when API returns empty', () async {
        when(
          () => mockApiService.fetchEarthquakes(
            minMagnitude: any(named: 'minMagnitude'),
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => []);

        final result = await repository.getEarthquakes();

        expect(result, isEmpty);
      });

      test('handles different magnitude filters', () async {
        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 5);
        when(
          () => mockApiService.fetchEarthquakes(
            minMagnitude: any(named: 'minMagnitude'),
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => mockEarthquakes);

        await repository.getEarthquakes(minMagnitude: 5.5);

        verify(
          () => mockApiService.fetchEarthquakes(
            minMagnitude: 5.5,
            days: 45,
            forceRefresh: false,
          ),
        ).called(1);
      });

      test('handles different day ranges', () async {
        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 5);
        when(
          () => mockApiService.fetchEarthquakes(
            minMagnitude: any(named: 'minMagnitude'),
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => mockEarthquakes);

        await repository.getEarthquakes(days: 7);

        verify(
          () => mockApiService.fetchEarthquakes(
            minMagnitude: 3.0,
            days: 7,
            forceRefresh: false,
          ),
        ).called(1);
      });
    });
  });
}
