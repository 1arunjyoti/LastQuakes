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
}
