import 'package:flutter/material.dart';
//import 'package:intl/intl.dart'; // Keep if formatting time here, otherwise remove

class EarthquakeListItem extends StatelessWidget {
  final String location;
  final String distanceText;
  final String formattedTime;
  final double magnitude;
  final Color magnitudeColor;
  final VoidCallback onTap; // Callback for navigation

  const EarthquakeListItem({
    Key? key,
    required this.location,
    required this.distanceText,
    required this.formattedTime,
    required this.magnitude,
    required this.magnitudeColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use const where possible
    const cardMargin = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    const contentPadding = EdgeInsets.all(16.0); // Combined inner/outer padding
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
    const distanceTextStyle = TextStyle(
      color: Colors.blueAccent, // Adjusted color slightly for contrast
      fontSize: 12,
    );
    const indicatorBarWidth = 4.0;
    const indicatorBarPadding = EdgeInsets.symmetric(vertical: 8.0);

    return GestureDetector(
      onTap: onTap, // Use the passed callback
      child: Card(
        margin: cardMargin,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 4,
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
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center, // Center content vertically
                          mainAxisSize: MainAxisSize.min, // Take minimum space
                          children: [
                            Text(
                              distanceText,
                              style: distanceTextStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              location,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: locationTextStyle,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedTime,
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
