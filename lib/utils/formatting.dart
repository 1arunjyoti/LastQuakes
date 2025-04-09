// lib/utils/formatting.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:provider/provider.dart';
import 'package:lastquake/provider/theme_provider.dart';

class FormattingUtils {
  /// Formats distance in kilometers based on user preference (km or miles).
  /// Requires BuildContext to access the ThemeProvider.
  static String formatDistance(BuildContext context, double distanceKm) {
    // Use listen: false as this is usually called within a build method
    // or callback where the value is needed once. If the widget displaying
    // this needs to rebuild on unit change, use Provider.of<...>(context)
    // or Consumer<...> in its build method.
    final prefsProvider = Provider.of<ThemeProvider>(context, listen: false);

    if (prefsProvider.distanceUnit == DistanceUnit.miles) {
      double distanceMiles = distanceKm * 0.621371;
      // Use NumberFormat for locale-aware number formatting and control decimals
      return "${NumberFormat("0.#").format(distanceMiles)} mi";
    } else {
      return "${NumberFormat("0.#").format(distanceKm)} km";
    }
  }

  /// Formats a DateTime object based on user preference (12/24 hour clock).
  /// Requires BuildContext to access the ThemeProvider.
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
            ? DateFormat.Hm() // 24-hour format (e.g., 14:30)
            : DateFormat.jm(); // 12-hour format (e.g., 2:30 PM)
    return formatter.format(dateTime);
  }

  static String formatPlaceString(BuildContext context, String place) {
    final prefsProvider = Provider.of<ThemeProvider>(context, listen: false);

    // If user preference is km, no need to modify the string
    if (prefsProvider.distanceUnit == DistanceUnit.km) {
      return place;
    }

    // Regex to find a number (integer or decimal) followed by optional space and "km"
    // at the beginning of the string.
    // - ^: Start of the string
    // - (\d+(\.\d+)?): Group 1: Capture the number (one or more digits, optionally followed by '.' and more digits)
    // - \s*: Match zero or more whitespace characters
    // - km: Match the literal "km"
    // - \b: Match a word boundary (ensures it's "km" not "kma" etc.)
    // - (.*): Group 3: Capture the rest of the string
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
        // If any error occurs during parsing/conversion, return original string
        debugPrint("Error parsing place string '$place': $e");
        return place;
      }
    }

    // If no match or error occurred, return the original string
    return place;
  }
}
