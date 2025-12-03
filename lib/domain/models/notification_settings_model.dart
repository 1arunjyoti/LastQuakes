import 'package:lastquakes/models/safe_zone.dart';
import 'package:lastquakes/utils/enums.dart';

class NotificationSettingsModel {
  final NotificationFilterType filterType;
  final double magnitude;
  final String country;
  final double radius;
  final bool useCurrentLocation;
  final List<SafeZone> safeZones;

  const NotificationSettingsModel({
    this.filterType = NotificationFilterType.none,
    this.magnitude = 5.0,
    this.country = "ALL",
    this.radius = 500.0,
    this.useCurrentLocation = false,
    this.safeZones = const [],
  });

  NotificationSettingsModel copyWith({
    NotificationFilterType? filterType,
    double? magnitude,
    String? country,
    double? radius,
    bool? useCurrentLocation,
    List<SafeZone>? safeZones,
  }) {
    return NotificationSettingsModel(
      filterType: filterType ?? this.filterType,
      magnitude: magnitude ?? this.magnitude,
      country: country ?? this.country,
      radius: radius ?? this.radius,
      useCurrentLocation: useCurrentLocation ?? this.useCurrentLocation,
      safeZones: safeZones ?? this.safeZones,
    );
  }
}
