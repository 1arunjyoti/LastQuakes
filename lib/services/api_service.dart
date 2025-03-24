import 'dart:convert';
import 'package:flutter/foundation.dart'; // Import for debugPrint
import 'package:http/http.dart' as http;

class ApiService {
  /// Fetches earthquake data from the USGS API based on minimum magnitude and days range.
  static Future<List<Map<String, dynamic>>> fetchEarthquakes({
    double minMagnitude = 3.0,
    int days = 45,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime startDate = now.subtract(Duration(days: days));

    // Constructing URL using Uri.https for better readability & safety
    final Uri url = Uri.https("earthquake.usgs.gov", "/fdsnws/event/1/query", {
      "format": "geojson",
      "orderby": "time",
      "starttime": startDate.toIso8601String(),
      "endtime": now.toIso8601String(),
    });

    debugPrint("Fetching data from: $url"); // Better than print()

    try {
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 10)); // Added timeout
      debugPrint("API Status Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["features"] == null || (data["features"] as List).isEmpty) {
          debugPrint("No earthquakes found.");
          return [];
        }

        List allEarthquakes = data["features"];

        List<Map<String, dynamic>> filteredEarthquakes =
            allEarthquakes
                .where((quake) {
                  var mag = quake["properties"]["mag"];
                  if (mag == null) return false; // Handling null values safely
                  double magnitude = (mag is int) ? mag.toDouble() : mag;
                  return magnitude >= minMagnitude;
                })
                .map((quake) => Map<String, dynamic>.from(quake))
                .toList(); // Ensuring type safety

        debugPrint("Fetched ${filteredEarthquakes.length} earthquakes.");
        return filteredEarthquakes;
      } else {
        throw Exception("API Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      throw Exception("Error fetching earthquake data: $e");
    }
  }
}
