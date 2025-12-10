import 'package:flutter/material.dart';
import 'package:lastquakes/models/earthquake.dart';
import 'package:lastquakes/screens/earthquake_details.dart';
import 'package:lastquakes/services/historical_comparison_service.dart';
import 'package:lastquakes/utils/formatting.dart';
import 'package:lastquakes/widgets/appbar.dart';

class EarthquakeComparisonScreen extends StatefulWidget {
  final Earthquake earthquake;

  const EarthquakeComparisonScreen({super.key, required this.earthquake});

  @override
  State<EarthquakeComparisonScreen> createState() =>
      _EarthquakeComparisonScreenState();
}

class _EarthquakeComparisonScreenState
    extends State<EarthquakeComparisonScreen> {
  HistoricalComparisonResult? _result;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComparison();
  }

  Future<void> _loadComparison() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await HistoricalComparisonService.instance
          .fetchHistoricalComparison(
            earthquake: widget.earthquake,
            radiusKm: 200,
            minMagnitude: 4.0, // Fetch all significant earthquakes (M4+)
            yearsBack: 50,
          );

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load comparison data. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LastQuakesAppBar(title: "Historical Comparison"),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState(context);
    }

    if (_error != null) {
      return _buildErrorState(context);
    }

    if (_result == null) {
      return const Center(child: Text("No data available"));
    }

    return RefreshIndicator(
      onRefresh: _loadComparison,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCurrentEarthquakeCard(context),
                const SizedBox(height: 16),
                _buildStatisticsCard(context),
                const SizedBox(height: 16),
                _buildRankingCard(context),
                const SizedBox(height: 16),
                _buildHistoricalList(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            "Searching historical records...",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            "Fetching 50 years of data within 200km",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
              onPressed: _loadComparison,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentEarthquakeCard(BuildContext context) {
    final eq = widget.earthquake;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final magColor = _getMagnitudeColor(eq.magnitude);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.compare_arrows,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "COMPARING",
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: magColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    eq.magnitude.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        FormattingUtils.formatPlaceString(context, eq.place),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        FormattingUtils.formatDateTime(context, eq.time),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(BuildContext context) {
    final result = _result!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "REGIONAL STATISTICS",
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              "Within ${result.radiusKm.toInt()}km • Past ${result.yearsSearched} years",
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    icon: Icons.format_list_numbered,
                    label: "Similar Events",
                    value: result.totalCount.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    context,
                    icon: Icons.trending_up,
                    label: "Avg Magnitude",
                    value: result.averageMagnitude.toStringAsFixed(1),
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
                    icon: Icons.bolt,
                    label: "Strongest",
                    value:
                        result.strongest?.magnitude.toStringAsFixed(1) ?? "N/A",
                    valueColor: Colors.red.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    context,
                    icon: Icons.schedule,
                    label: "Most Recent",
                    value: result.mostRecent?.time.year.toString() ?? "N/A",
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingCard(BuildContext context) {
    final result = _result!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ranking = result.currentRanking;
    final total = result.totalCount + 1;

    // Determine ranking context
    String rankingText;
    Color rankingColor;
    IconData rankingIcon;

    if (ranking == 1) {
      rankingText = "Strongest earthquake in this region!";
      rankingColor = Colors.red.shade700;
      rankingIcon = Icons.warning_rounded;
    } else if (ranking <= 5) {
      rankingText = "Among the top 5 strongest";
      rankingColor = Colors.orange.shade700;
      rankingIcon = Icons.trending_up;
    } else if (ranking <= total * 0.25) {
      rankingText = "Stronger than 75% of similar events";
      rankingColor = Colors.amber.shade700;
      rankingIcon = Icons.arrow_upward;
    } else {
      rankingText = "Typical for this region";
      rankingColor = Colors.green.shade600;
      rankingIcon = Icons.check_circle_outline;
    }

    return Card(
      elevation: 2,
      //color: rankingColor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: rankingColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(rankingIcon, color: rankingColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ranked #$ranking of $total",
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: rankingColor,
                    ),
                  ),
                  Text(
                    rankingText,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalList(BuildContext context) {
    final result = _result!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (result.historicalEarthquakes.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  size: 48,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  "No similar earthquakes found",
                  style: textTheme.titleMedium,
                ),
                Text(
                  "This is a rare event for this region!",
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Take top 10 sorted by magnitude
    final sortedQuakes = [...result.historicalEarthquakes];
    sortedQuakes.sort((a, b) => b.magnitude.compareTo(a.magnitude));
    final topQuakes = sortedQuakes.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Text(
                "HISTORICAL EARTHQUAKES",
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                "Showing strongest 10 of ${result.totalCount}",
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topQuakes.length,
            separatorBuilder:
                (context, index) => const Divider(height: 1, indent: 16),
            itemBuilder: (context, index) {
              final eq = topQuakes[index];
              return _buildHistoricalItem(context, eq);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoricalItem(BuildContext context, Earthquake eq) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final magColor = _getMagnitudeColor(eq.magnitude);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EarthquakeDetailsScreen(earthquake: eq),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: magColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                eq.magnitude.toStringAsFixed(1),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: magColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FormattingUtils.formatPlaceString(context, eq.place),
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatHistoricalDate(eq.time),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  String _formatHistoricalDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  Color _getMagnitudeColor(double magnitude) {
    if (magnitude >= 8.0) return Colors.red.shade900;
    if (magnitude >= 7.0) return Colors.red.shade700;
    if (magnitude >= 6.0) return Colors.orange.shade800;
    if (magnitude >= 5.0) return Colors.amber.shade700;
    return Colors.green.shade600;
  }
}
