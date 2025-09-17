import 'package:flutter/material.dart';
import 'package:lastquake/utils/formatting.dart';

class EarthquakeListItem extends StatelessWidget {
  final String location;
  final double magnitude;
  final Color magnitudeColor;
  final VoidCallback onTap;
  final DateTime timestamp; 
  final double? distanceKm; 

  const EarthquakeListItem({
    super.key,
    required this.location,
    required this.magnitude,
    required this.magnitudeColor,
    required this.onTap,
    required this.timestamp,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    // Format distance and time using utils inside build method
    String displayDistance;
    if (distanceKm != null) {
      displayDistance = FormattingUtils.formatDistance(context, distanceKm!);
      displayDistance = "$displayDistance from your location";
    } else {
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
      fontSize: 17,
    );
    const timeTextStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w500);
    const distanceTextStyle = TextStyle(color: Colors.blue, fontSize: 14);
    const indicatorBarWidth = 4.0;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: cardMargin,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: magnitudeColor,
                  width: indicatorBarWidth,
                ),
              ),
            ),
            child: Padding(
              padding: contentPadding,
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
                  const SizedBox(width: 8),
                   
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
        ),
      ),
    );
  }
}
