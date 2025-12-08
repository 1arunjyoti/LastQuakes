import 'package:flutter/material.dart';
import 'package:lastquakes/models/earthquake.dart';

class EarthquakeBottomSheet extends StatelessWidget {
  final Earthquake earthquake;
  final VoidCallback onViewDetails;

  const EarthquakeBottomSheet({
    super.key,
    required this.earthquake,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final magColor = _getMarkerColor(earthquake.magnitude);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  // Header: Location & Close
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              earthquake.place,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: textTheme.bodySmall?.color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDateTime(earthquake.time),
                                  style: textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Metrics Row (Magnitude, Depth, Tsunami)
                  Row(
                    children: [
                      Expanded(
                        child: _buildStyledMetricBox(
                          context,
                          label: "Magnitude",
                          value: earthquake.magnitude.toStringAsFixed(1),
                          color: magColor,
                          isAlert: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStyledMetricBox(
                          context,
                          label: "Depth",
                          value:
                              "${earthquake.depth?.toStringAsFixed(1) ?? '--'} km",
                          icon: Icons.layers_outlined,
                          color: colorScheme.primary,
                          isAlert: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStyledMetricBox(
                          context,
                          label: "Tsunami",
                          value: earthquake.tsunami == 1 ? "Alert" : "None",
                          icon:
                              earthquake.tsunami == 1
                                  ? Icons.tsunami
                                  : Icons.waves_outlined,
                          color:
                              earthquake.tsunami == 1
                                  ? Colors.blue
                                  : colorScheme.onSurface,
                          isAlert: earthquake.tsunami == 1,
                          borderColor:
                              earthquake.tsunami == 1
                                  ? Colors.blue
                                  : colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Secondary Details (Coordinates & Source)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDetailRow(
                          context,
                          Icons.map_outlined,
                          "${earthquake.latitude.toStringAsFixed(2)}, ${earthquake.longitude.toStringAsFixed(2)}",
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          color: colorScheme.outlineVariant,
                        ),
                        _buildDetailRow(
                          context,
                          Icons.source_outlined,
                          "Source: ${earthquake.source.toUpperCase()}",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onViewDetails();
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text("View Full Details"),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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

  Widget _buildStyledMetricBox(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    IconData? icon,
    bool isAlert = false,
    Color? borderColor,
  }) {
    final theme = Theme.of(context);
    final effectiveBorderColor = borderColor ?? color;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color:
            isAlert
                ? color.withValues(alpha: 0.1)
                : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isAlert
                  ? effectiveBorderColor.withValues(alpha: 0.5)
                  : Colors.transparent,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isAlert ? color : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isAlert ? color : theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isAlert ? color : theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Color _getMarkerColor(double magnitude) {
    if (magnitude >= 7.0) {
      return Colors.red.shade900;
    } else if (magnitude >= 5.0) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }
}
