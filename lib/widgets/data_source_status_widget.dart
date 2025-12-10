import 'package:flutter/material.dart';
import 'package:lastquakes/models/data_source_status.dart';
import 'package:lastquakes/presentation/providers/earthquake_provider.dart';
import 'package:provider/provider.dart';

/// Widget that displays the status of data sources
/// Shows users which sources are working and which have failed
class DataSourceStatusWidget extends StatelessWidget {
  final bool compact;

  const DataSourceStatusWidget({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<EarthquakeProvider>(
      builder: (context, provider, _) {
        final statuses = provider.sourceStatuses;

        if (statuses.isEmpty) {
          return const SizedBox.shrink();
        }

        // Check if any sources have issues
        final hasIssues = statuses.values.any(
          (status) => status.health != SourceHealth.healthy,
        );

        if (!hasIssues && compact) {
          // Don't show anything if all sources are healthy in compact mode
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              statuses.entries
                  .map(
                    (entry) => _buildSourceStatus(
                      context,
                      entry.value,
                      compact,
                      isDark,
                    ),
                  )
                  .toList(),
        );
      },
    );
  }

  Widget _buildSourceStatus(
    BuildContext context,
    DataSourceStatus status,
    bool compact,
    bool isDark,
  ) {
    Color statusColor;
    IconData statusIcon;

    switch (status.health) {
      case SourceHealth.healthy:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case SourceHealth.degraded:
        statusColor = Colors.orange;
        statusIcon = Icons.warning_amber_rounded;
        break;
      case SourceHealth.failing:
        statusColor = Colors.red;
        statusIcon = Icons.error_outline_rounded;
        break;
      case SourceHealth.unknown:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline_rounded;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(statusIcon, size: 18, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.sourceName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (!compact || status.health != SourceHealth.healthy)
                  if (status.statusMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        status.statusMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              status.health == SourceHealth.failing
                                  ? statusColor
                                  : Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.color,
                          fontSize: 11,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner widget that appears at the top when sources are failing
class DataSourceBanner extends StatefulWidget {
  const DataSourceBanner({super.key});

  @override
  State<DataSourceBanner> createState() => _DataSourceBannerState();
}

class _DataSourceBannerState extends State<DataSourceBanner> {
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<EarthquakeProvider>(
      builder: (context, provider, _) {
        final statuses = provider.sourceStatuses;

        if (statuses.isEmpty) {
          return const SizedBox.shrink();
        }

        final failedSources =
            statuses.values
                .where((status) => status.health == SourceHealth.failing)
                .toList();

        if (failedSources.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                isDark
                    ? Colors.orange[900]?.withValues(alpha: 0.3)
                    : Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            failedSources.length == 1
                                ? '${failedSources[0].sourceName} is currently unavailable'
                                : '${failedSources.length} data sources are currently unavailable',
                            style: Theme.of(
                              context,
                            ).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark
                                      ? Colors.orange[200]
                                      : Colors.orange[900],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...failedSources.map(
                            (status) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${status.sourceName}: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          isDark
                                              ? Colors.orange[300]
                                              : Colors.orange[800],
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      status.errorMessage ?? 'Unknown error',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            isDark
                                                ? Colors.grey[300]
                                                : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Showing data from available sources and cached data.',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _isDismissed = true;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
