import 'package:flutter/material.dart';
import 'package:lastquakes/models/earthquake.dart';
import 'package:lastquakes/presentation/providers/earthquake_provider.dart';
import 'package:lastquakes/services/earthquake_statistics.dart';
import 'package:lastquakes/widgets/appbar.dart';
import 'package:lastquakes/widgets/custom_drawer.dart';
import 'package:lastquakes/widgets/statistics/simple_line_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // Cache statistics to avoid recalculating on every rebuild
  EarthquakeStats? _cachedStats;
  String? _lastCacheKey;

  /// Generate a cache key based on list content, not reference
  String _generateCacheKey(List<Earthquake> earthquakes) {
    if (earthquakes.isEmpty) return 'empty';
    // Use length + first/last IDs + first/last times for quick content fingerprint
    final first = earthquakes.first;
    final last = earthquakes.last;
    return '${earthquakes.length}_${first.id}_${last.id}_${first.time.millisecondsSinceEpoch}_${last.time.millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LastQuakesAppBar(title: 'Statistics & Insights'),
      drawer: const CustomDrawer(),
      body: Consumer<EarthquakeProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.listEarthquakes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.listEarthquakes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No earthquake data available',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Pull down to refresh'),
                ],
              ),
            );
          }

          // Use content-based cache key to detect actual data changes
          final currentCacheKey = _generateCacheKey(provider.listEarthquakes);
          if (_lastCacheKey != currentCacheKey) {
            _cachedStats = EarthquakeStatistics.calculate(
              provider.listEarthquakes,
            );
            _lastCacheKey = currentCacheKey;
          }

          final stats = _cachedStats!;

          return RefreshIndicator(
            onRefresh: () => provider.loadData(forceRefresh: true),
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                          children: [
                            _buildOverviewCard(context, stats),
                            const SizedBox(height: 16),
                            if (stats.dailyTrend.isNotEmpty)
                              _buildHistoricalTrendCard(context, stats),
                            if (stats.dailyTrend.isNotEmpty)
                              const SizedBox(height: 16),
                            if (stats.weeklyComparison != null)
                              _buildWeeklyComparisonCard(context, stats),
                            if (stats.weeklyComparison != null)
                              const SizedBox(height: 16),
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _buildTopRegionsCard(context, stats),
                                        const SizedBox(height: 16),
                                        _buildLast7DaysTrendCard(
                                          context,
                                          stats,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _buildMagnitudeDistributionCard(
                                          context,
                                          stats,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildDataSourcesCard(context, stats),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _buildTopRegionsCard(context, stats),
                              const SizedBox(height: 16),
                              _buildMagnitudeDistributionCard(context, stats),
                              const SizedBox(height: 16),
                              _buildLast7DaysTrendCard(context, stats),
                              const SizedBox(height: 16),
                              _buildDataSourcesCard(context, stats),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context, EarthquakeStats stats) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final dateRange =
        stats.earliestTime != null && stats.latestTime != null
            ? '${dateFormat.format(stats.earliestTime!)} - ${dateFormat.format(stats.latestTime!)}'
            : 'N/A';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Overview',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Total Earthquakes',
                    stats.totalCount.toString(),
                    Icons.public,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Avg Magnitude',
                    stats.averageMagnitude.toStringAsFixed(1),
                    Icons.speed,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Max Magnitude',
                    stats.maxMagnitude.toStringAsFixed(1),
                    Icons.warning_amber_rounded,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Min Magnitude',
                    stats.minMagnitude.toStringAsFixed(1),
                    Icons.trending_down,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Date Range',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(dateRange, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTopRegionsCard(BuildContext context, EarthquakeStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Most Active Regions',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            if (stats.topRegions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No data available'),
                ),
              )
            else
              ...stats.topRegions.map((region) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              region.region,
                              style: Theme.of(context).textTheme.bodyLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${region.count} (${region.percentage.toStringAsFixed(1)}%)',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: region.percentage / 100,
                        backgroundColor:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMagnitudeDistributionCard(
    BuildContext context,
    EarthquakeStats stats,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.equalizer,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Magnitude Distribution',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            ...stats.magnitudeDistribution.map((dist) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'M ${dist.range}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          '${dist.count} (${dist.percentage.toStringAsFixed(1)}%)',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: dist.percentage / 100,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(int.parse(dist.color.replaceFirst('#', '0xFF'))),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLast7DaysTrendCard(BuildContext context, EarthquakeStats stats) {
    final maxCount =
        stats.last7DaysTrend.isEmpty
            ? 1
            : stats.last7DaysTrend
                .map((e) => e.count)
                .reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.show_chart,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Last 7 Days Activity',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            if (stats.last7DaysTrend.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No data available'),
                ),
              )
            else
              SizedBox(
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children:
                      stats.last7DaysTrend.map((trend) {
                        final barHeight =
                            maxCount > 0 ? (trend.count / maxCount) * 120 : 0.0;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (trend.count > 0)
                                  Text(
                                    trend.count.toString(),
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                if (trend.count > 0) const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  height: barHeight.clamp(8, 120),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  trend.period.split(' ')[0],
                                  style: Theme.of(context).textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSourcesCard(BuildContext context, EarthquakeStats stats) {
    final total = stats.sourceBreakdown.values.fold(0, (a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.source_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Data Sources',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            if (stats.sourceBreakdown.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No data available'),
                ),
              )
            else
              ...stats.sourceBreakdown.entries.map((entry) {
                final percentage =
                    total > 0 ? (entry.value / total) * 100 : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color:
                              entry.key == 'USGS' ? Colors.blue : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      Text(
                        '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalTrendCard(
    BuildContext context,
    EarthquakeStats stats,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Historical Trend Analysis',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${stats.dailyTrend.length} days of data',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            SimpleLineChart(
              data: stats.dailyTrend,
              showMovingAverage: true,
              lineColor: Theme.of(context).colorScheme.primary,
              fillColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Daily earthquake count with 3-day moving average',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyComparisonCard(
    BuildContext context,
    EarthquakeStats stats,
  ) {
    final comparison = stats.weeklyComparison!;
    final isIncrease = comparison.percentageChange > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.compare_arrows,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Weekly Comparison',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildWeeklyStatBox(
                    context,
                    'This Week',
                    comparison.thisWeek.toString(),
                    Icons.calendar_today,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildWeeklyStatBox(
                    context,
                    'Last Week',
                    comparison.lastWeek.toString(),
                    Icons.history,
                    Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isIncrease ? Colors.orange : Colors.green).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isIncrease ? Icons.trending_up : Icons.trending_down,
                    color: isIncrease ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isIncrease
                          ? '${comparison.percentageChange.toStringAsFixed(1)}% increase from last week'
                          : '${comparison.percentageChange.abs().toStringAsFixed(1)}% decrease from last week',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Most Active Day: ${comparison.mostActiveDay} (${comparison.mostActiveDayCount} earthquakes)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyStatBox(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
