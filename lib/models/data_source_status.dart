import 'package:lastquakes/utils/enums.dart';

/// Status of a data source
enum SourceHealth {
  healthy,
  degraded,
  failing,
  unknown,
}

/// Information about a data source's operational status
class DataSourceStatus {
  final DataSource source;
  final SourceHealth health;
  final String? errorMessage;
  final int earthquakeCount;
  final DateTime lastUpdated;
  final int responseTimeMs;

  const DataSourceStatus({
    required this.source,
    required this.health,
    this.errorMessage,
    this.earthquakeCount = 0,
    required this.lastUpdated,
    this.responseTimeMs = 0,
  });

  /// Create a healthy status
  factory DataSourceStatus.healthy({
    required DataSource source,
    required int earthquakeCount,
    required int responseTimeMs,
  }) {
    return DataSourceStatus(
      source: source,
      health: SourceHealth.healthy,
      earthquakeCount: earthquakeCount,
      lastUpdated: DateTime.now(),
      responseTimeMs: responseTimeMs,
    );
  }

  /// Create a failed status
  factory DataSourceStatus.failed({
    required DataSource source,
    required String errorMessage,
    required int responseTimeMs,
  }) {
    return DataSourceStatus(
      source: source,
      health: SourceHealth.failing,
      errorMessage: errorMessage,
      lastUpdated: DateTime.now(),
      responseTimeMs: responseTimeMs,
    );
  }

  /// Create a degraded status (partial failure)
  factory DataSourceStatus.degraded({
    required DataSource source,
    required String errorMessage,
    required int earthquakeCount,
    required int responseTimeMs,
  }) {
    return DataSourceStatus(
      source: source,
      health: SourceHealth.degraded,
      errorMessage: errorMessage,
      earthquakeCount: earthquakeCount,
      lastUpdated: DateTime.now(),
      responseTimeMs: responseTimeMs,
    );
  }

  /// Create an unknown status (not yet checked)
  factory DataSourceStatus.unknown(DataSource source) {
    return DataSourceStatus(
      source: source,
      health: SourceHealth.unknown,
      lastUpdated: DateTime.now(),
    );
  }

  /// Get display name for the source
  String get sourceName {
    switch (source) {
      case DataSource.usgs:
        return 'USGS';
      case DataSource.emsc:
        return 'EMSC';
    }
  }

  /// Get a short status message
  String get statusMessage {
    switch (health) {
      case SourceHealth.healthy:
        return '$earthquakeCount earthquakes · ${responseTimeMs}ms';
      case SourceHealth.degraded:
        return 'Partial data · $errorMessage';
      case SourceHealth.failing:
        return errorMessage ?? 'Source unavailable';
      case SourceHealth.unknown:
        return 'Not checked';
    }
  }

  /// Whether this source is providing data
  bool get isProvidingData => 
      health == SourceHealth.healthy || health == SourceHealth.degraded;
}
