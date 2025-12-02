import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lastquake/models/earthquake.dart';
import 'package:lastquake/services/secure_http_client.dart';
import 'package:lastquake/services/sources/earthquake_data_source.dart';
import 'package:lastquake/utils/secure_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsgsDataSource implements EarthquakeDataSource {
  final SecureHttpClient _client;
  final SharedPreferences _prefs;
  static const int _maxEarthquakesPerSource = 10000;

  UsgsDataSource(this._client, this._prefs);

  @override
  Future<List<Earthquake>> fetchEarthquakes({
    required double minMagnitude,
    required int days,
  }) async {
    try {
      final DateTime now = DateTime.now();
      final DateTime startDate = now.subtract(Duration(days: days));

      final Uri url =
          Uri.https("earthquake.usgs.gov", "/fdsnws/event/1/query", {
            "format": "geojson",
            "orderby": "time",
            "starttime": startDate.toIso8601String(),
            "endtime": now.toIso8601String(),
            "minmagnitude": minMagnitude.toString(),
            "limit": _maxEarthquakesPerSource.toString(),
          });

      // Check for cached ETag/Last-Modified
      final cacheKey = 'usgs_etag_${minMagnitude}_$days';
      final lastModifiedKey = 'usgs_last_modified_${minMagnitude}_$days';
      final etag = _prefs.getString(cacheKey);
      final lastModified = _prefs.getString(lastModifiedKey);

      final Map<String, String> headers = {};
      if (etag != null) headers['If-None-Match'] = etag;
      if (lastModified != null) headers['If-Modified-Since'] = lastModified;

      final response = await _client.get(
        url,
        headers: headers,
        timeout: const Duration(seconds: 30),
      );

      SecureLogger.api(
        "earthquake.usgs.gov/fdsnws/event/1/query",
        statusCode: response.statusCode,
        method: "GET",
      );

      if (response.statusCode == 304) {
        SecureLogger.info("USGS data not modified (304), returning empty list");
        return [];
      }

      if (response.statusCode == 200) {
        // Save ETag/Last-Modified
        final newEtag = response.headers['etag'];
        final newLastModified = response.headers['last-modified'];
        if (newEtag != null) await _prefs.setString(cacheKey, newEtag);
        if (newLastModified != null) {
          await _prefs.setString(lastModifiedKey, newLastModified);
        }

        return await _parseResponse(response.body, minMagnitude);
      } else if (response.statusCode == 204) {
        return [];
      } else {
        throw HttpException("USGS API Error: ${response.statusCode}");
      }
    } catch (e) {
      SecureLogger.error("Error fetching USGS data", e);
      rethrow;
    }
  }

  Future<List<Earthquake>> _parseResponse(
    String responseBody,
    double minMagnitude,
  ) async {
    return compute(_parseIsolate, {
      'body': responseBody,
      'minMagnitude': minMagnitude,
    });
  }

  static List<Earthquake> _parseIsolate(Map<String, dynamic> args) {
    final responseBody = args['body'] as String;
    final minMagnitude = args['minMagnitude'] as double;

    try {
      final data = json.decode(responseBody);
      if (data["features"] == null) return [];

      final features = data["features"] as List;
      if (features.isEmpty) return [];

      final List<Earthquake> allEarthquakes = [];

      // Process in chunks even inside isolate to manage memory
      const int chunkSize = 1000;
      for (int i = 0; i < features.length; i += chunkSize) {
        final end =
            (i + chunkSize < features.length) ? i + chunkSize : features.length;
        final chunk = features.sublist(i, end);

        final earthquakes =
            chunk
                .whereType<Map<String, dynamic>>()
                .map((quake) {
                  try {
                    final earthquake = Earthquake.fromUsgs(quake);
                    return earthquake.magnitude >= minMagnitude
                        ? earthquake
                        : null;
                  } catch (e) {
                    return null;
                  }
                })
                .whereType<Earthquake>()
                .toList();

        allEarthquakes.addAll(earthquakes);
      }

      return allEarthquakes;
    } catch (e) {
      if (kDebugMode) {
        print('Error in USGS isolate: $e');
      }
      return [];
    }
  }
}
