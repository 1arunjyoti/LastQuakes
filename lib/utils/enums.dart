enum DistanceUnit { km, miles }

enum TimeWindow { lastHour, last24Hours, last7Days, last45Days }

enum NotificationFilterType {
  none, // Disable all notifications
  distance, // Within a certain distance of current location or safe zones
  country, // Within a specific country
  worldwide, // Any earthquake meeting magnitude threshold
}

enum MapLayerType {
  osm, // OpenStreetMap Standard
  satellite, // Satellite Imagery
  terrain, // Topographic/Terrain Map
  dark, // Dark Mode Map
}

enum DataSource {
  usgs, // United States Geological Survey
  emsc, // European-Mediterranean Seismological Centre
}
