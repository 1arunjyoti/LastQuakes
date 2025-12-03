import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lastquakes/utils/enums.dart';
import 'package:provider/provider.dart';
import 'package:lastquakes/provider/theme_provider.dart';

class FormattingUtils {
  /// Formats distance in kilometers based on user preference (km or miles).
  static String formatDistance(BuildContext context, double distanceKm) {
    final prefsProvider = Provider.of<ThemeProvider>(context, listen: false);

    if (prefsProvider.distanceUnit == DistanceUnit.miles) {
      double distanceMiles = distanceKm * 0.621371;
      return "${NumberFormat("0.#").format(distanceMiles)} mi";
    } else {
      return "${NumberFormat("0.#").format(distanceKm)} km";
    }
  }

  /// Formats a DateTime object based on user preference (12/24 hour clock).
  static String formatDateTime(BuildContext context, DateTime dateTime) {
    final prefsProvider = Provider.of<ThemeProvider>(context, listen: false);
    final DateFormat formatter;

    if (prefsProvider.use24HourClock) {
      // Example: Jan 5, 2024, 14:30 or 09:05
      formatter = DateFormat('MMM d, yyyy, HH:mm'); // 24-hour format
    } else {
      // Example: Jan 5, 2024, 2:30 PM or 9:05 AM
      formatter = DateFormat(
        'MMM d, yyyy, h:mm a',
      ); // 12-hour format with AM/PM
    }
    return formatter.format(dateTime);
  }

  /// Formats just the time part based on user preference
  static String formatTimeOnly(BuildContext context, DateTime dateTime) {
    final prefsProvider = Provider.of<ThemeProvider>(context, listen: false);
    final DateFormat formatter =
        prefsProvider.use24HourClock
            ? DateFormat.Hm() // 24-hour format
            : DateFormat.jm(); // 12-hour format
    return formatter.format(dateTime);
  }

  static String formatPlaceString(BuildContext context, String place) {
    final prefsProvider = Provider.of<ThemeProvider>(context, listen: false);

    // If user preference is km, no need to modify the string
    if (prefsProvider.distanceUnit == DistanceUnit.km) {
      return place;
    }
    // Regex to find patterns like "123 km" or "12.3 km"
    final regex = RegExp(r'^(\d+(\.\d+)?)\s*km\b(.*)', caseSensitive: false);
    final match = regex.firstMatch(place);

    if (match != null) {
      try {
        // Extract the matched number string (Group 1)
        final kmString = match.group(1);
        // Extract the rest of the string (Group 3)
        final restOfString = match.group(3) ?? '';

        if (kmString != null) {
          // Parse the number string to double
          final double? kmValue = double.tryParse(kmString);

          if (kmValue != null) {
            // Convert km to miles
            double milesValue = kmValue * 0.621371;
            // Format miles (e.g., one decimal place)
            String formattedMiles = NumberFormat("0.#").format(milesValue);
            // Reconstruct the string with "mi"
            // Ensure there's a space before the restOfString if it's not empty
            return "$formattedMiles mi${restOfString.isNotEmpty ? ' ' : ''}${restOfString.trim()}";
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint("Error parsing place string '$place': $e");
        }
        return place;
      }
    }
    return place;
  }
}
