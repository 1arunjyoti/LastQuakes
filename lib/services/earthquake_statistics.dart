import 'package:lastquake/models/earthquake.dart';

/// Statistics data models
class RegionStats {
  final String region;
  final int count;
  final double percentage;

  const RegionStats({
    required this.region,
    required this.count,
    required this.percentage,
  });
}

class MagnitudeDistribution {
  final String range;
  final int count;
  final double percentage;
  final String color; // Hex color for visualization

  const MagnitudeDistribution({
    required this.range,
    required this.count,
    required this.percentage,
    required this.color,
  });
}

class TemporalStats {
  final String period;
  final int count;

  const TemporalStats({required this.period, required this.count});
}

class DailyTrendPoint {
  final DateTime date;
  final int count;
  final double avgMagnitude;

  const DailyTrendPoint({
    required this.date,
    required this.count,
    required this.avgMagnitude,
  });
}

class WeeklyComparison {
  final int thisWeek;
  final int lastWeek;
  final int weekBeforeLast;
  final double percentageChange;
  final String mostActiveDay;
  final int mostActiveDayCount;

  const WeeklyComparison({
    required this.thisWeek,
    required this.lastWeek,
    required this.weekBeforeLast,
    required this.percentageChange,
    required this.mostActiveDay,
    required this.mostActiveDayCount,
  });
}

class EarthquakeStats {
  final int totalCount;
  final double averageMagnitude;
  final double maxMagnitude;
  final double minMagnitude;
  final DateTime? earliestTime;
  final DateTime? latestTime;
  final List<RegionStats> topRegions;
  final List<MagnitudeDistribution> magnitudeDistribution;
  final Map<String, int> sourceBreakdown;
  final List<TemporalStats> last7DaysTrend;
  final List<DailyTrendPoint> dailyTrend;
  final WeeklyComparison? weeklyComparison;

  const EarthquakeStats({
    required this.totalCount,
    required this.averageMagnitude,
    required this.maxMagnitude,
    required this.minMagnitude,
    this.earliestTime,
    this.latestTime,
    required this.topRegions,
    required this.magnitudeDistribution,
    required this.sourceBreakdown,
    required this.last7DaysTrend,
    required this.dailyTrend,
    this.weeklyComparison,
  });
}

/// Utility class for calculating earthquake statistics
class EarthquakeStatistics {
  /// Calculate comprehensive statistics from a list of earthquakes
  static EarthquakeStats calculate(List<Earthquake> earthquakes) {
    if (earthquakes.isEmpty) {
      return const EarthquakeStats(
        totalCount: 0,
        averageMagnitude: 0.0,
        maxMagnitude: 0.0,
        minMagnitude: 0.0,
        topRegions: [],
        magnitudeDistribution: [],
        sourceBreakdown: {},
        last7DaysTrend: [],
        dailyTrend: [],
      );
    }

    final totalCount = earthquakes.length;

    // Calculate magnitude stats
    double totalMagnitude = 0.0;
    double maxMag = earthquakes.first.magnitude;
    double minMag = earthquakes.first.magnitude;
    DateTime? earliest = earthquakes.first.time;
    DateTime? latest = earthquakes.first.time;

    for (final quake in earthquakes) {
      totalMagnitude += quake.magnitude;
      if (quake.magnitude > maxMag) maxMag = quake.magnitude;
      if (quake.magnitude < minMag) minMag = quake.magnitude;
      if (earliest == null || quake.time.isBefore(earliest)) {
        earliest = quake.time;
      }
      if (latest == null || quake.time.isAfter(latest)) {
        latest = quake.time;
      }
    }

    final avgMagnitude = totalMagnitude / totalCount;

    // Calculate top regions
    final topRegions = _calculateTopRegions(earthquakes);

    // Calculate magnitude distribution
    final magnitudeDistribution = _calculateMagnitudeDistribution(earthquakes);

    // Calculate source breakdown
    final sourceBreakdown = _calculateSourceBreakdown(earthquakes);

    // Calculate last 7 days trend
    final last7DaysTrend = _calculateLast7DaysTrend(earthquakes);

    // Calculate complete daily trend
    final dailyTrend = _calculateDailyTrend(earthquakes);

    // Calculate weekly comparison
    final weeklyComparison = _calculateWeeklyComparison(earthquakes);

    return EarthquakeStats(
      totalCount: totalCount,
      averageMagnitude: avgMagnitude,
      maxMagnitude: maxMag,
      minMagnitude: minMag,
      earliestTime: earliest,
      latestTime: latest,
      topRegions: topRegions,
      magnitudeDistribution: magnitudeDistribution,
      sourceBreakdown: sourceBreakdown,
      last7DaysTrend: last7DaysTrend,
      dailyTrend: dailyTrend,
      weeklyComparison: weeklyComparison,
    );
  }

  /// Extract region from earthquake place string
  static String _extractRegion(String place) {
    // Try to get the region after the last comma
    if (place.contains(',')) {
      return place.split(',').last.trim();
    }
    // If no comma, try to extract meaningful keyword
    if (place.toLowerCase().contains(' of ')) {
      final parts = place.split(' of ');
      if (parts.length > 1) {
        return parts[1].trim();
      }
    }
    return place.trim();
  }

  /// Calculate top 5 active regions
  static List<RegionStats> _calculateTopRegions(List<Earthquake> earthquakes) {
    final Map<String, int> regionCounts = {};

    for (final quake in earthquakes) {
      final region = _extractRegion(quake.place);
      regionCounts[region] = (regionCounts[region] ?? 0) + 1;
    }

    // Sort by count descending
    final sortedRegions =
        regionCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    // Take top 5
    final top5 = sortedRegions.take(5).toList();
    final total = earthquakes.length;

    return top5.map((entry) {
      return RegionStats(
        region: entry.key,
        count: entry.value,
        percentage: (entry.value / total) * 100,
      );
    }).toList();
  }

  /// Calculate magnitude distribution
  static List<MagnitudeDistribution> _calculateMagnitudeDistribution(
    List<Earthquake> earthquakes,
  ) {
    final Map<String, int> distribution = {
      '3.0-3.9': 0,
      '4.0-4.9': 0,
      '5.0-5.9': 0,
      '6.0-6.9': 0,
      '7.0+': 0,
    };

    final Map<String, String> colors = {
      '3.0-3.9': '#4CAF50', // Green
      '4.0-4.9': '#8BC34A', // Light Green
      '5.0-5.9': '#FFC107', // Amber
      '6.0-6.9': '#FF9800', // Orange
      '7.0+': '#F44336', // Red
    };

    for (final quake in earthquakes) {
      final mag = quake.magnitude;
      if (mag >= 3.0 && mag < 4.0) {
        distribution['3.0-3.9'] = distribution['3.0-3.9']! + 1;
      } else if (mag >= 4.0 && mag < 5.0) {
        distribution['4.0-4.9'] = distribution['4.0-4.9']! + 1;
      } else if (mag >= 5.0 && mag < 6.0) {
        distribution['5.0-5.9'] = distribution['5.0-5.9']! + 1;
      } else if (mag >= 6.0 && mag < 7.0) {
        distribution['6.0-6.9'] = distribution['6.0-6.9']! + 1;
      } else if (mag >= 7.0) {
        distribution['7.0+'] = distribution['7.0+']! + 1;
      }
    }

    final total = earthquakes.length;
    return distribution.entries.map((entry) {
      return MagnitudeDistribution(
        range: entry.key,
        count: entry.value,
        percentage: total > 0 ? (entry.value / total) * 100 : 0.0,
        color: colors[entry.key]!,
      );
    }).toList();
  }

  /// Calculate source breakdown (USGS vs EMSC)
  static Map<String, int> _calculateSourceBreakdown(
    List<Earthquake> earthquakes,
  ) {
    final Map<String, int> breakdown = {};

    for (final quake in earthquakes) {
      breakdown[quake.source] = (breakdown[quake.source] ?? 0) + 1;
    }

    return breakdown;
  }

  /// Calculate earthquake count for the last 7 days
  static List<TemporalStats> _calculateLast7DaysTrend(
    List<Earthquake> earthquakes,
  ) {
    final now = DateTime.now();
    final Map<String, int> dayCounts = {};

    // Initialize last 7 days
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = _formatDate(date);
      dayCounts[key] = 0;
    }

    // Count earthquakes per day
    for (final quake in earthquakes) {
      final daysDiff = now.difference(quake.time).inDays;
      if (daysDiff < 7) {
        final key = _formatDate(quake.time);
        dayCounts[key] = (dayCounts[key] ?? 0) + 1;
      }
    }

    // Convert to list
    return dayCounts.entries.map((entry) {
      return TemporalStats(period: entry.key, count: entry.value);
    }).toList();
  }

  /// Format date as "Mon DD"
  static String _formatDate(DateTime date) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return '${days[date.weekday % 7]} ${date.day}';
  }

  /// Calculate complete daily trend for all data
  static List<DailyTrendPoint> _calculateDailyTrend(
    List<Earthquake> earthquakes,
  ) {
    if (earthquakes.isEmpty) return [];

    // Group by date
    final Map<String, List<Earthquake>> dailyGroups = {};

    for (final quake in earthquakes) {
      final dateKey = _formatDateKey(quake.time);
      dailyGroups.putIfAbsent(dateKey, () => []).add(quake);
    }

    // Convert to trend points
    final List<DailyTrendPoint> points = [];
    final sortedKeys = dailyGroups.keys.toList()..sort();

    for (final key in sortedKeys) {
      final quakes = dailyGroups[key]!;
      final avgMag =
          quakes.fold<double>(0.0, (sum, q) => sum + q.magnitude) /
          quakes.length;

      points.add(
        DailyTrendPoint(
          date: DateTime.parse(key),
          count: quakes.length,
          avgMagnitude: avgMag,
        ),
      );
    }

    return points;
  }

  /// Calculate weekly comparison statistics
  static WeeklyComparison? _calculateWeeklyComparison(
    List<Earthquake> earthquakes,
  ) {
    if (earthquakes.isEmpty) return null;

    final now = DateTime.now();
    final Map<String, int> dailyCounts = {};

    int thisWeek = 0;
    int lastWeek = 0;
    int weekBeforeLast = 0;

    for (final quake in earthquakes) {
      final daysDiff = now.difference(quake.time).inDays;

      if (daysDiff < 7) {
        thisWeek++;
        final dayKey = _formatDate(quake.time);
        dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
      } else if (daysDiff >= 7 && daysDiff < 14) {
        lastWeek++;
      } else if (daysDiff >= 14 && daysDiff < 21) {
        weekBeforeLast++;
      }
    }

    // Find most active day in current week
    String mostActiveDay = 'N/A';
    int maxCount = 0;
    dailyCounts.forEach((day, count) {
      if (count > maxCount) {
        maxCount = count;
        mostActiveDay = day;
      }
    });

    final percentageChange =
        lastWeek > 0
            ? ((thisWeek - lastWeek) / lastWeek) * 100
            : (thisWeek > 0 ? 100.0 : 0.0);

    return WeeklyComparison(
      thisWeek: thisWeek,
      lastWeek: lastWeek,
      weekBeforeLast: weekBeforeLast,
      percentageChange: percentageChange,
      mostActiveDay: mostActiveDay,
      mostActiveDayCount: maxCount,
    );
  }

  /// Calculate moving average for trend smoothing
  static List<double> calculateMovingAverage(
    List<DailyTrendPoint> points,
    int windowSize,
  ) {
    if (points.length < windowSize) return [];

    final List<double> movingAvg = [];

    for (int i = 0; i <= points.length - windowSize; i++) {
      double sum = 0;
      for (int j = 0; j < windowSize; j++) {
        sum += points[i + j].count;
      }
      movingAvg.add(sum / windowSize);
    }

    return movingAvg;
  }

  /// Format date as YYYY-MM-DD for grouping
  static String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
