import 'package:flutter/material.dart';
import 'package:lastquake/utils/formatting.dart';
//import 'package:intl/intl.dart'; // Keep if formatting time here, otherwise remove

class EarthquakeListItem extends StatelessWidget {
  final String location;
  final double magnitude;
  final Color magnitudeColor;
  final VoidCallback onTap;
  final DateTime timestamp; // Pass DateTime instead of formatted string
  final double? distanceKm; // Pass distance in KM (can be null)

  const EarthquakeListItem({
    Key? key,
    required this.location,
    required this.magnitude,
    required this.magnitudeColor,
    required this.onTap,
    required this.timestamp,
    required this.distanceKm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Format distance and time using utils inside build method
    String displayDistance;
    if (distanceKm != null) {
      displayDistance = FormattingUtils.formatDistance(context, distanceKm!);
      displayDistance = "$displayDistance from your location";
    } else {
      // Or show placeholder if location services are off/unavailable
      displayDistance = "Enable location for distance";
    }
    final String displayTime = FormattingUtils.formatDateTime(
      context,
      timestamp,
    );
    final String displayLocation = FormattingUtils.formatPlaceString(
      context,
      location,
    );

    const cardMargin = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    const contentPadding = EdgeInsets.all(16.0);
    const magnitudeBoxPadding = EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    );
    const magnitudeTextStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 26,
    );
    const locationTextStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );
    const timeTextStyle = TextStyle(fontSize: 12);
    const distanceTextStyle = TextStyle(color: Colors.blueAccent, fontSize: 12);
    const indicatorBarWidth = 4.0;
    const indicatorBarPadding = EdgeInsets.symmetric(vertical: 8.0);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: cardMargin,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
        child: IntrinsicHeight(
          // Ensure Row children have same height for the bar
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Stretch children vertically
            children: [
              // Side Indicator Bar (using Container decoration)
              Container(
                width: indicatorBarWidth,
                margin: indicatorBarPadding, // Padding around the bar
                decoration: BoxDecoration(
                  color: magnitudeColor,
                  borderRadius: BorderRadius.circular(indicatorBarWidth / 2),
                ),
              ),
              // Main Content
              Expanded(
                child: Padding(
                  padding: contentPadding, // Apply padding here
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
                              style: distanceTextStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayLocation,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: locationTextStyle,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayTime,
                              style: timeTextStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8), // Spacing
                      // Right Section - Magnitude Box
                      Container(
                        padding: magnitudeBoxPadding,
                        decoration: BoxDecoration(
                          color: magnitudeColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          magnitude.toStringAsFixed(1),
                          style: magnitudeTextStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
