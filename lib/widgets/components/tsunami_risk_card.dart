import 'package:flutter/material.dart';
import 'package:lastquakes/models/earthquake.dart';

/// A card widget that displays tsunami risk assessment based on earthquake characteristics
class TsunamiRiskCard extends StatelessWidget {
  final Earthquake earthquake;

  const TsunamiRiskCard({super.key, required this.earthquake});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final risk = earthquake.tsunamiRisk;
    final factors = earthquake.tsunamiRiskFactors;

    // Get styling based on risk level
    final (color, icon, title, description) = _getRiskStyling(risk);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TSUNAMI RISK ASSESSMENT",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Risk level badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    risk.name.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),

                // Risk Factors
                Text(
                  "Risk Factors:",
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                ...factors.map(
                  (factor) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _getFactorIcon(factor),
                          size: 16,
                          color: _getFactorColor(factor, color),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            factor,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Disclaimer
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "This is an automated risk estimate based on earthquake characteristics. "
                          "Always follow official warnings from local authorities.",
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns (color, icon, title, description) based on risk level
  (Color, IconData, String, String) _getRiskStyling(TsunamiRisk risk) {
    switch (risk) {
      case TsunamiRisk.high:
        return (
          Colors.red.shade700,
          Icons.tsunami_rounded,
          "High Tsunami Risk",
          "This earthquake has characteristics strongly associated with tsunami generation. "
              "If near the coast, move to higher ground immediately and monitor official warnings.",
        );
      case TsunamiRisk.moderate:
        return (
          Colors.orange.shade700,
          Icons.warning_amber_rounded,
          "Moderate Tsunami Risk",
          "This earthquake has some characteristics that could generate a tsunami. "
              "Monitor official warning centers for updates if you are in a coastal area.",
        );
      case TsunamiRisk.low:
        return (
          Colors.amber.shade700,
          Icons.notifications_outlined,
          "Low Tsunami Risk",
          "This earthquake has limited tsunami-generating potential based on its characteristics. "
              "Coastal areas should still stay alert for official updates.",
        );
      case TsunamiRisk.none:
        return (
          Colors.green.shade700,
          Icons.shield_outlined,
          "No Significant Tsunami Risk",
          "Based on this earthquake's characteristics (magnitude, depth, location), "
              "a tsunami is unlikely. The earthquake is either too small, too deep, or landlocked.",
        );
    }
  }

  /// Get appropriate icon for risk factor
  IconData _getFactorIcon(String factor) {
    if (factor.contains('magnitude') || factor.contains('Magnitude')) {
      return Icons.speed_outlined;
    }
    if (factor.contains('depth') || factor.contains('Depth')) {
      return Icons.layers_outlined;
    }
    if (factor.contains('location') || factor.contains('Location')) {
      return Icons.location_on_outlined;
    }
    if (factor.contains('warning') || factor.contains('Warning')) {
      return Icons.warning_rounded;
    }
    return Icons.check_circle_outline;
  }

  /// Get color for factor based on whether it's positive or negative for risk
  Color _getFactorColor(String factor, Color baseColor) {
    // Factors that reduce risk (show in green)
    if (factor.contains('below threshold') ||
        factor.contains('Deep earthquake') ||
        factor.contains('Landlocked') ||
        factor.contains('low tsunami risk')) {
      return Colors.green.shade600;
    }
    // Factors that increase risk (show in base color)
    return baseColor;
  }
}
