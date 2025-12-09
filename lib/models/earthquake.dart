/// Tsunami risk levels based on earthquake characteristics
enum TsunamiRisk {
  /// No significant tsunami risk (landlocked, small magnitude, or deep)
  none,

  /// Low risk - some characteristics present but unlikely
  low,

  /// Moderate risk - multiple risk factors present
  moderate,

  /// High risk - official warning issued OR all major risk factors
  high,
}

class Earthquake {
  final String id;
  final double magnitude;
  final String place;
  final DateTime time;
  final double latitude;
  final double longitude;
  final double? depth;
  final String? url;
  final int? tsunami;
  final String source; // USGS or EMSC
  final Map<String, dynamic> rawData;

  Earthquake({
    required this.id,
    required this.magnitude,
    required this.place,
    required this.time,
    required this.latitude,
    required this.longitude,
    this.depth,
    this.url,
    this.tsunami,
    required this.source,
    required this.rawData,
  });

  factory Earthquake.fromUsgs(Map<String, dynamic> data) {
    final properties = data['properties'];
    final geometry = data['geometry'];
    final coordinates = geometry['coordinates'];

    return Earthquake(
      id: data['id'],
      magnitude: (properties['mag'] ?? 0.0).toDouble(),
      place: properties['place'] ?? 'Unknown location',
      time: DateTime.fromMillisecondsSinceEpoch(properties['time']),
      latitude: coordinates[1].toDouble(),
      longitude: coordinates[0].toDouble(),
      depth: coordinates.length > 2 ? coordinates[2]?.toDouble() : null,
      url: properties['url'],
      tsunami: properties['tsunami'],
      source: 'USGS',
      rawData: data,
    );
  }

  factory Earthquake.fromEmsc(Map<String, dynamic> data) {
    // Handle different possible field names from EMSC
    final String id =
        data['unid']?.toString() ??
        data['id']?.toString() ??
        data['eventid']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final double magnitude =
        (data['mag'] ?? data['magnitude'] ?? 0.0).toDouble();

    final String place =
        data['flynn_region']?.toString() ??
        data['region']?.toString() ??
        data['place']?.toString() ??
        data['description']?.toString() ??
        'Unknown location';

    // Handle different time formats
    DateTime time;
    try {
      if (data['time'] is String) {
        time = DateTime.parse(data['time']);
      } else if (data['time'] is int) {
        time = DateTime.fromMillisecondsSinceEpoch(data['time']);
      } else if (data['datetime'] != null) {
        time = DateTime.parse(data['datetime']);
      } else {
        time = DateTime.now();
      }
    } catch (e) {
      time = DateTime.now();
    }

    final double latitude = (data['lat'] ?? data['latitude'] ?? 0.0).toDouble();
    final double longitude =
        (data['lon'] ?? data['lng'] ?? data['longitude'] ?? 0.0).toDouble();
    final double? depth = (data['depth'] ?? data['dep'])?.toDouble();

    final String? url =
        data['source_catalog'] != null
            ? 'https://www.emsc-csem.org/Earthquake/earthquake.php?id=$id'
            : data['url']?.toString();

    return Earthquake(
      id: id,
      magnitude: magnitude,
      place: place,
      time: time,
      latitude: latitude,
      longitude: longitude,
      depth: depth,
      url: url,
      tsunami: null, // EMSC doesn't usually provide tsunami flag in this feed
      source: 'EMSC',
      rawData: data,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'magnitude': magnitude,
      'place': place,
      'time': time.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'depth': depth,
      'url': url,
      'tsunami': tsunami,
      'source': source,
      'rawData': rawData,
    };
  }

  factory Earthquake.fromJson(Map<String, dynamic> json) {
    return Earthquake(
      id: json['id'],
      magnitude: json['magnitude'].toDouble(),
      place: json['place'],
      time: DateTime.parse(json['time']),
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      depth: json['depth']?.toDouble(),
      url: json['url'],
      tsunami: json['tsunami'],
      source: json['source'],
      rawData: json['rawData'],
    );
  }

  /// Returns the USGS PAGER alert level ('green', 'yellow', 'orange', 'red')
  /// Returns null if not present or not a USGS earthquake
  String? get alert {
    if (source != 'USGS') return null;
    return rawData['properties']?['alert'] as String?;
  }

  /// Calculates tsunami risk based on earthquake characteristics
  /// Uses magnitude, depth, and location to assess potential
  /// Based on NOAA/PTWC scientific criteria
  TsunamiRisk get tsunamiRisk {
    // If USGS already flagged a tsunami warning, it's high risk
    if (tsunami == 1) return TsunamiRisk.high;

    // Calculate risk score based on characteristics
    int riskScore = 0;

    // 1. Magnitude check - larger quakes can displace more water
    // NOAA: M7.0+ typically needed, M6.5 is lower threshold
    if (magnitude >= 7.5) {
      riskScore += 4; // Basin-wide potential
    } else if (magnitude >= 7.0) {
      riskScore += 3; // Regional potential
    } else if (magnitude >= 6.5) {
      riskScore += 1; // Local potential only
    }

    // 2. Depth check - shallow quakes are more tsunamigenic
    // NOAA: Must be <100km depth, shallower is more dangerous
    if (depth != null) {
      if (depth! < 30) {
        riskScore += 2; // Very shallow - highest risk
      } else if (depth! < 70) {
        riskScore += 1; // Shallow
      } else if (depth! >= 100) {
        riskScore -= 2; // Deep - unlikely to cause tsunami
      }
      // 70-100km: no bonus or penalty
    } else {
      // Unknown depth, assume moderate risk if other factors present
      riskScore += 1;
    }

    // 3. Location check - oceanic locations can generate tsunamis
    if (_isOceanicLocation) {
      riskScore += 1; // Reduced from +2 to avoid over-weighting
    }
    if (_isLandlockedLocation) {
      riskScore -= 3; // Strong penalty for landlocked
    }

    // Convert score to risk level
    // HIGH requires strong magnitude + favorable conditions
    if (riskScore >= 6) return TsunamiRisk.high;
    if (riskScore >= 4) return TsunamiRisk.moderate;
    if (riskScore >= 1) return TsunamiRisk.low;
    return TsunamiRisk.none;
  }

  /// Check if location keywords suggest oceanic/coastal area
  bool get _isOceanicLocation {
    final placeLower = place.toLowerCase();
    const oceanicKeywords = [
      'ocean',
      'sea',
      'ridge',
      'trench',
      'coast',
      'island',
      'pacific',
      'atlantic',
      'indian',
      'gulf',
      'bay',
      'strait',
      'channel',
      'offshore',
      'submarine',
    ];
    return oceanicKeywords.any((keyword) => placeLower.contains(keyword));
  }

  /// Check if location keywords suggest landlocked area
  bool get _isLandlockedLocation {
    final placeLower = place.toLowerCase();
    const landlockedKeywords = [
      'inland',
      'mountain',
      'desert',
      'plateau',
      'nevada',
      'utah',
      'wyoming',
      'colorado',
      'arizona',
      'tibet',
      'mongolia',
      'kazakhstan',
      'afghanistan',
    ];
    return landlockedKeywords.any((keyword) => placeLower.contains(keyword));
  }

  /// Returns a list of risk factors that contribute to tsunami risk
  List<String> get tsunamiRiskFactors {
    final factors = <String>[];

    if (tsunami == 1) {
      factors.add('Official tsunami warning issued');
      return factors;
    }

    if (magnitude >= 7.5) {
      factors.add(
        'Very large magnitude (M${magnitude.toStringAsFixed(1)} ≥ 7.5)',
      );
    } else if (magnitude >= 7.0) {
      factors.add('Large magnitude (M${magnitude.toStringAsFixed(1)} ≥ 7.0)');
    } else if (magnitude >= 6.5) {
      factors.add(
        'Significant magnitude (M${magnitude.toStringAsFixed(1)} ≥ 6.5)',
      );
    } else {
      factors.add('Magnitude below tsunami threshold (< 6.5)');
    }

    if (depth != null) {
      if (depth! < 30) {
        factors.add(
          'Very shallow depth (${depth!.toStringAsFixed(1)} km < 30 km)',
        );
      } else if (depth! < 70) {
        factors.add('Shallow depth (${depth!.toStringAsFixed(1)} km < 70 km)');
      } else {
        factors.add(
          'Deep earthquake (${depth!.toStringAsFixed(1)} km ≥ 70 km)',
        );
      }
    }

    if (_isOceanicLocation) {
      factors.add('Oceanic/coastal location');
    } else if (_isLandlockedLocation) {
      factors.add('Landlocked location (low tsunami risk)');
    }

    return factors;
  }
}
