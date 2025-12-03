import 'package:flutter/material.dart';
import 'package:lastquakes/utils/formatting.dart';

/// Pre-computed source badge styles to avoid rebuilding on every frame
class _SourceBadgeStyles {
  static const usgsBackground = Color(0xFFBBDEFB); // Colors.blue.shade100
  static const usgsTextColor = Color(0xFF1976D2); // Colors.blue.shade700
  static const usgsBorderColor = Color(0xFF64B5F6); // Colors.blue.shade300
  static const emscBackground = Color(0xFFC8E6C9); // Colors.green.shade100
  static const emscTextColor = Color(0xFF388E3C); // Colors.green.shade700
  static const emscBorderColor = Color(0xFF81C784); // Colors.green.shade300
}

class EarthquakeListItem extends StatelessWidget {
  final String location;
  final double magnitude;
  final Color magnitudeColor;
  final VoidCallback onTap;
  final DateTime timestamp;
  final double? distanceKm;
  final String? source;

  // Pre-computed formatted strings (passed from parent)
  final String? formattedDistance;
  final String? formattedTime;
  final String? formattedLocation;

  const EarthquakeListItem({
    super.key,
    required this.location,
    required this.magnitude,
    required this.magnitudeColor,
    required this.onTap,
    required this.timestamp,
    required this.distanceKm,
    this.source,
    this.formattedDistance,
    this.formattedTime,
    this.formattedLocation,
  });

  // Static constants moved outside build() for better performance
  static const _cardMargin = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
  static const _contentPadding = EdgeInsets.all(16.0);
  static const _magnitudeBoxPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );
  static const _magnitudeTextStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontSize: 26,
  );
  static const _locationTextStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 17,
  );
  static const _timeTextStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w500);
  static const _distanceTextStyle = TextStyle(color: Colors.blue, fontSize: 14);
  static const _indicatorBarWidth = 4.0;
  static const _sourceBadgePadding = EdgeInsets.symmetric(horizontal: 6, vertical: 2);
  static const _sourceTextStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context) {
    // Use pre-computed values if available, otherwise compute on-demand
    final String displayDistance = formattedDistance ?? _computeDistance(context);
    final String displayTime = formattedTime ?? FormattingUtils.formatDateTime(context, timestamp);
    final String displayLocation = formattedLocation ?? FormattingUtils.formatPlaceString(context, location);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: _cardMargin,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: magnitudeColor,
                  width: _indicatorBarWidth,
                ),
              ),
            ),
            child: Padding(
              padding: _contentPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Section - Location & Time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayDistance,
                          style: _distanceTextStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayLocation,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: _locationTextStyle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayTime,
                          style: _timeTextStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Right Section - Magnitude Box and Source
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: _magnitudeBoxPadding,
                        decoration: BoxDecoration(
                          color: magnitudeColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          magnitude.toStringAsFixed(1),
                          style: _magnitudeTextStyle,
                        ),
                      ),
                      if (source != null) _buildSourceBadge(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Compute distance string on-demand (fallback when not pre-computed)
  String _computeDistance(BuildContext context) {
    if (distanceKm != null) {
      return "${FormattingUtils.formatDistance(context, distanceKm!)} from your location";
    }
    return "Enable location for distance";
  }

  /// Build source badge with cached colors to avoid repeated color lookups
  Widget _buildSourceBadge() {
    final isUsgs = source == 'USGS';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: _sourceBadgePadding,
        decoration: BoxDecoration(
          color: isUsgs
              ? _SourceBadgeStyles.usgsBackground
              : _SourceBadgeStyles.emscBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isUsgs
                ? _SourceBadgeStyles.usgsBorderColor
                : _SourceBadgeStyles.emscBorderColor,
            width: 1,
          ),
        ),
        child: Text(
          source!,
          style: _sourceTextStyle.copyWith(
            color: isUsgs
                ? _SourceBadgeStyles.usgsTextColor
                : _SourceBadgeStyles.emscTextColor,
          ),
        ),
      ),
    );
  }
}
