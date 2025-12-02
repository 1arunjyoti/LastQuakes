import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lastquake/models/earthquake.dart';
import 'package:lastquake/services/secure_http_client.dart';
import 'package:lastquake/services/sources/earthquake_data_source.dart';
import 'package:lastquake/utils/secure_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmscDataSource implements EarthquakeDataSource {
  final SecureHttpClient _client;
  final SharedPreferences _prefs;
  static const int _maxEarthquakesPerSource = 10000;

  EmscDataSource(this._client, this._prefs);

  @override
  Future<List<Earthquake>> fetchEarthquakes({
    required double minMagnitude,
    required int days,
  }) async {
    try {
      final DateTime now = DateTime.now();
      final DateTime startDate = now.subtract(Duration(days: days));

      final Uri url =
          Uri.https("www.seismicportal.eu", "/fdsnws/event/1/query", {
            "format": "json",
            "orderby": "time-desc",
            "starttime": startDate.toIso8601String().split('T')[0],
            "endtime": now.toIso8601String().split('T')[0],
            "minmagnitude": minMagnitude.toString(),
            "limit": _maxEarthquakesPerSource.toString(),
          });

      // Check for cached ETag/Last-Modified
      final cacheKey = 'emsc_etag_${minMagnitude}_$days';
      final lastModifiedKey = 'emsc_last_modified_${minMagnitude}_$days';
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
        "www.seismicportal.eu/fdsnws/event/1/query",
        statusCode: response.statusCode,
        method: "GET",
      );

      if (response.statusCode == 304) {
        SecureLogger.info("EMSC data not modified (304), returning empty list");
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
        throw HttpException("EMSC API Error: ${response.statusCode}");
      }
    } catch (e) {
      SecureLogger.error("Error fetching EMSC data", e);
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

      if (data is! Map || data["features"] == null) {
        return [];
      }

      final earthquakeList = data["features"] as List;
      if (earthquakeList.isEmpty) return [];

      final List<Earthquake> allEarthquakes = [];
      const int chunkSize = 1000;

      for (int i = 0; i < earthquakeList.length; i += chunkSize) {
        final end =
            (i + chunkSize < earthquakeList.length)
                ? i + chunkSize
                : earthquakeList.length;
        final chunk = earthquakeList.sublist(i, end);

        final earthquakes =
            chunk
                .whereType<Map<String, dynamic>>()
                .map((quake) {
                  try {
                    final earthquakeData =
                        quake['properties'] as Map<String, dynamic>?;
                    if (earthquakeData == null) return null;

                    final earthquake = Earthquake.fromEmsc(earthquakeData);
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
      return [];
    }
  }
}
