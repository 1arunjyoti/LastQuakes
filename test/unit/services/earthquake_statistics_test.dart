import 'package:flutter_test/flutter_test.dart';
import 'package:lastquakes/services/earthquake_statistics.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('EarthquakeStatistics', () {
    group('Basic Statistics', () {
      test('calculate returns correct total count', () {
        final earthquakes = TestHelpers.createMockEarthquakes(count: 25);

        final stats = EarthquakeStatistics.calculate(earthquakes);

        expect(stats.totalCount, 25);
      });

      test('calculate computes average magnitude correctly', () {
        final earthquakes = [
          TestHelpers.createMockEarthquake(magnitude: 3.0),
          TestHelpers.createMockEarthquake(magnitude: 5.0),
          TestHelpers.createMockEarthquake(magnitude: 7.0),
        ];

        final stats = EarthquakeStatistics.calculate(earthquakes);

        expect(stats.averageMagnitude, 5.0);
      });

      test('calculate finds correct min and max magnitude', () {
        final earthquakes = [
          TestHelpers.createMockEarthquake(magnitude: 4.2),
          TestHelpers.createMockEarthquake(magnitude: 6.8),
          TestHelpers.createMockEarthquake(magnitude: 3.1),
          TestHelpers.createMockEarthquake(magnitude: 5.5),
        ];

        final stats = EarthquakeStatistics.calculate(earthquakes);

        expect(stats.minMagnitude, 3.1);
        expect(stats.maxMagnitude, 6.8);
      });

      test('calculate handles single earthquake', () {
        final earthquakes = [TestHelpers.createMockEarthquake(magnitude: 5.5)];

        final stats = EarthquakeStatistics.calculate(earthquakes);

        expect(stats.totalCount, 1);
        expect(stats.averageMagnitude, 5.5);
        expect(stats.minMagnitude, 5.5);
        expect(stats.maxMagnitude, 5.5);
      });

      test('calculate handles empty list', () {
        final stats = EarthquakeStatistics.calculate([]);

        expect(stats.totalCount, 0);
        expect(stats.averageMagnitude, 0.0);
        expect(stats.minMagnitude, 0.0);
        expect(stats.maxMagnitude, 0.0);
      });
    });

    group('Top Regions', () {
      test('calculates top regions from earthquake locations', () {
        final earthquakes = [
          TestHelpers.createMockEarthquake(place: '10 km N of Tokyo, Japan'),
          TestHelpers.createMockEarthquake(place: '5 km S of Tokyo, Japan'),
          TestHelpers.createMockEarthquake(place: '20 km E of Tokyo, Japan'),
          TestHelpers.createMockEarthquake(place: '15 km W of California'),
          TestHelpers.createMockEarthquake(place: '30 km N of California'),
          TestHelpers.createMockEarthquake(place: '5 km S of Alaska'),
        ];

        final stats = EarthquakeStatistics.calculate(earthquakes);

        expect(stats.topRegions.length, lessThanOrEqualTo(5));
        // Top region should have highest count
        expect(stats.topRegions.first.count, 3);
      });

      test('limits results to top 5 regions', () {
        final earthquakes = List.generate(20, (i) {
          return TestHelpers.createMockEarthquake(place: '$i km N of Region$i');
        });

        final stats = EarthquakeStatistics.calculate(earthquakes);

        expect(stats.topRegions.length, lessThanOrEqualTo(5));
      });

      test('handles empty earthquake list', () {
        final stats = EarthquakeStatistics.calculate([]);

        expect(stats.topRegions, isEmpty);
        final earthquakes = [
          TestHelpers.createMockEarthquake(source: 'USGS'),
          TestHelpers.createMockEarthquake(source: 'USGS'),
          TestHelpers.createMockEarthquake(source: 'USGS'),
          TestHelpers.createMockEarthquake(source: 'EMSC'),
          TestHelpers.createMockEarthquake(source: 'EMSC'),
        ];

        final stats2 = EarthquakeStatistics.calculate(earthquakes);

        expect(stats2.sourceBreakdown['USGS'], 3);
        expect(stats2.sourceBreakdown['EMSC'], 2);
      });

      test('handles single source', () {
        final earthquakes = List.generate(5, (i) {
          return TestHelpers.createMockEarthquake(source: 'USGS');
        });

        final stats = EarthquakeStatistics.calculate(earthquakes);

        expect(stats.sourceBreakdown['USGS'], 5);
        expect(stats.sourceBreakdown['EMSC'], isNull);
      });
    });

    group('Temporal Analysis', () {
      test('calculates last 7 days trend', () {
        final now = DateTime(2024, 6, 15);
        final earthquakes = [
          TestHelpers.createMockEarthquake(
            time: now.subtract(const Duration(days: 0)),
          ),
          TestHelpers.createMockEarthquake(
            time: now.subtract(const Duration(days: 0)),
          ),
          TestHelpers.createMockEarthquake(
            time: now.subtract(const Duration(days: 1)),
          ),
          TestHelpers.createMockEarthquake(
            time: now.subtract(const Duration(days: 3)),
          ),
          TestHelpers.createMockEarthquake(
            time: now.subtract(const Duration(days: 6)),
          ),
          TestHelpers.createMockEarthquake(
            time: now.subtract(const Duration(days: 8)),
          ), // Outside range
        ];

        final stats = EarthquakeStatistics.calculate(earthquakes, now: now);

        expect(stats.last7DaysTrend.length, 7);
        // Should have data for last 7 days
        expect(stats.last7DaysTrend, isNotEmpty);
      });

      test('daily trend groups earthquakes by day', () {
        final baseDate = DateTime(2024, 6, 1);
        final earthquakes = [
          TestHelpers.createMockEarthquake(time: baseDate),
          TestHelpers.createMockEarthquake(
            time: baseDate.add(const Duration(hours: 6)),
          ),
          TestHelpers.createMockEarthquake(
            time: baseDate.add(const Duration(days: 1)),
          ),
          TestHelpers.createMockEarthquake(
            time: baseDate.add(const Duration(days: 1, hours: 12)),
          ),
          TestHelpers.createMockEarthquake(
            time: baseDate.add(const Duration(days: 2)),
          ),
        ];

        final stats = EarthquakeStatistics.calculate(earthquakes);

        expect(stats.dailyTrend.length, greaterThanOrEqualTo(3));
        expect(stats.dailyTrend, isNotEmpty);
      });

      test('weekly comparison calculates current vs previous week', () {
        final now = DateTime(2024, 6, 15);
        final earthquakes = [
          // Current week (last 7 days)
          TestHelpers.createMockEarthquake(
            time: now.subtract(const Duration(days: 1)),
          ),
          TestHelpers.createMockEarthquake(
            time: now.subtract(const Duration(days: 2)),
          ),
          TestHelpers.createMockEarthquake(
            time: now.subtract(const Duration(days: 3)),
          ),
          // Previous week (8-14 days ago)
          TestHelpers.createMockEarthquake(
            time: now.subtract(const Duration(days: 8)),
          ),
          TestHelpers.createMockEarthquake(
            time: now.subtract(const Duration(days: 9)),
          ),
          TestHelpers.createMockEarthquake(
            time: now.subtract(const Duration(days: 10)),
          ),
          TestHelpers.createMockEarthquake(
            time: now.subtract(const Duration(days: 11)),
          ),
        ];

        final stats = EarthquakeStatistics.calculate(earthquakes, now: now);

        expect(stats.weeklyComparison, isNotNull);
        expect(stats.weeklyComparison!.thisWeek, 3);
        expect(stats.weeklyComparison!.lastWeek, 4);
      });

      test('calculateMovingAverage smooths data correctly', () {
        final points = [
          DailyTrendPoint(
            date: DateTime(2024, 6, 1),
            count: 10,
            avgMagnitude: 5.0,
          ),
          DailyTrendPoint(
            date: DateTime(2024, 6, 2),
            count: 20,
            avgMagnitude: 5.0,
          ),
          DailyTrendPoint(
            date: DateTime(2024, 6, 3),
            count: 30,
            avgMagnitude: 5.0,
          ),
          DailyTrendPoint(
            date: DateTime(2024, 6, 4),
            count: 40,
            avgMagnitude: 5.0,
          ),
          DailyTrendPoint(
            date: DateTime(2024, 6, 5),
            count: 50,
            avgMagnitude: 5.0,
          ),
        ];

        final smoothed = EarthquakeStatistics.calculateMovingAverage(points, 3);

        expect(smoothed.length, 3);
        expect(smoothed[0], 20.0); // Average of 10, 20, 30
      });

      test('calculateMovingAverage handles window size of 1', () {
        final points = [
          DailyTrendPoint(
            date: DateTime(2024, 6, 1),
            count: 10,
            avgMagnitude: 5.0,
          ),
          DailyTrendPoint(
            date: DateTime(2024, 6, 2),
            count: 20,
            avgMagnitude: 5.0,
          ),
        ];

        final smoothed = EarthquakeStatistics.calculateMovingAverage(points, 1);

        expect(smoothed[0], 10.0);
        expect(smoothed[1], 20.0);
      });

      test('calculateMovingAverage handles empty list', () {
        final smoothed = EarthquakeStatistics.calculateMovingAverage([], 3);

        expect(smoothed, isEmpty);
      });
    });

    group('Edge Cases', () {
      test('handles earthquakes with same magnitude', () {
        final earthquakes = List.generate(10, (i) {
          return TestHelpers.createMockEarthquake(magnitude: 5.0);
        });

        final stats = EarthquakeStatistics.calculate(earthquakes);

        expect(stats.averageMagnitude, 5.0);
        expect(stats.minMagnitude, 5.0);
        expect(stats.maxMagnitude, 5.0);
      });

      test('handles earthquakes at same time', () {
        final sameTime = DateTime(2024, 6, 15, 10, 30);
        final earthquakes = List.generate(5, (i) {
          return TestHelpers.createMockEarthquake(time: sameTime);
        });

        final stats = EarthquakeStatistics.calculate(earthquakes);

        expect(stats.dailyTrend.isNotEmpty, isTrue);
      });

      test('handles very old earthquakes', () {
        final veryOld = DateTime(1900, 1, 1);
        final earthquakes = [
          TestHelpers.createMockEarthquake(time: veryOld),
          TestHelpers.createMockEarthquake(time: DateTime.now()),
        ];

        final stats = EarthquakeStatistics.calculate(earthquakes);

        expect(stats.totalCount, 2);
        expect(stats.dailyTrend.isNotEmpty, isTrue);
      });
    });
  });
}
