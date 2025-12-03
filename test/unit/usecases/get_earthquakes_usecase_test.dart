import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lastquakes/domain/repositories/earthquake_repository.dart';
import 'package:lastquakes/domain/usecases/get_earthquakes_usecase.dart';
import '../../helpers/test_helpers.dart';

class MockEarthquakeRepository extends Mock implements EarthquakeRepository {}

void main() {
  group('GetEarthquakesUseCase', () {
    late MockEarthquakeRepository mockRepository;
    late GetEarthquakesUseCase useCase;

    setUp(() {
      mockRepository = MockEarthquakeRepository();
      useCase = GetEarthquakesUseCase(mockRepository);
    });

    group('call', () {
      test('forwards call to repository with correct parameters', () async {
        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 5);
        when(
          () => mockRepository.getEarthquakes(
            minMagnitude: any(named: 'minMagnitude'),
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => mockEarthquakes);

        await useCase(minMagnitude: 4.5, days: 30, forceRefresh: true);

        verify(
          () => mockRepository.getEarthquakes(
            minMagnitude: 4.5,
            days: 30,
            forceRefresh: true,
          ),
        ).called(1);
      });

      test('returns earthquakes from repository', () async {
        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 10);
        when(
          () => mockRepository.getEarthquakes(
            minMagnitude: any(named: 'minMagnitude'),
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => mockEarthquakes);

        final result = await useCase();

        expect(result.length, 10);
        expect(result, equals(mockEarthquakes));
      });

      test('uses default parameters when not provided', () async {
        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 3);
        when(
          () => mockRepository.getEarthquakes(
            minMagnitude: any(named: 'minMagnitude'),
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => mockEarthquakes);

        await useCase();

        verify(
          () => mockRepository.getEarthquakes(
            minMagnitude: 3.0,
            days: 45,
            forceRefresh: false,
          ),
        ).called(1);
      });

      test('propagates errors from repository', () async {
        when(
          () => mockRepository.getEarthquakes(
            minMagnitude: any(named: 'minMagnitude'),
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenThrow(Exception('Repository error'));

        expect(() => useCase(), throwsA(isA<Exception>()));
      });

      test('returns empty list when repository returns empty', () async {
        when(
          () => mockRepository.getEarthquakes(
            minMagnitude: any(named: 'minMagnitude'),
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => []);

        final result = await useCase();

        expect(result, isEmpty);
      });

      test('handles specific magnitude filter', () async {
        final mockEarthquakes = TestHelpers.createMockEarthquakes(
          count: 5,
          minMagnitude: 6.0,
          maxMagnitude: 8.0,
        );
        when(
          () => mockRepository.getEarthquakes(
            minMagnitude: any(named: 'minMagnitude'),
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => mockEarthquakes);

        final result = await useCase(minMagnitude: 6.0);

        expect(result.length, 5);
        // All returned earthquakes should have magnitude >= 6.0
        for (final eq in result) {
          expect(eq.magnitude, greaterThanOrEqualTo(6.0));
        }
      });

      test('handles specific time range', () async {
        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 10);
        when(
          () => mockRepository.getEarthquakes(
            minMagnitude: any(named: 'minMagnitude'),
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => mockEarthquakes);

        await useCase(days: 7);

        verify(
          () => mockRepository.getEarthquakes(
            minMagnitude: 3.0,
            days: 7,
            forceRefresh: false,
          ),
        ).called(1);
      });

      test('handles force refresh correctly', () async {
        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 5);
        when(
          () => mockRepository.getEarthquakes(
            minMagnitude: any(named: 'minMagnitude'),
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => mockEarthquakes);

        await useCase(forceRefresh: true);

        verify(
          () => mockRepository.getEarthquakes(
            minMagnitude: 3.0,
            days: 45,
            forceRefresh: true,
          ),
        ).called(1);
      });

      test('multiple calls do not interfere with each other', () async {
        final earthquakes1 = TestHelpers.createMockEarthquakes(count: 5);
        final earthquakes2 = TestHelpers.createMockEarthquakes(count: 10);

        when(
          () => mockRepository.getEarthquakes(
            minMagnitude: 3.0,
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => earthquakes1);

        when(
          () => mockRepository.getEarthquakes(
            minMagnitude: 5.0,
            days: any(named: 'days'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => earthquakes2);

        final result1 = await useCase(minMagnitude: 3.0);
        final result2 = await useCase(minMagnitude: 5.0);

        expect(result1.length, 5);
        expect(result2.length, 10);
      });
    });
  });
}
