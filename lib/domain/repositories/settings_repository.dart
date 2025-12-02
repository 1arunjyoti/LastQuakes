import 'package:lastquake/domain/models/notification_settings_model.dart';
import 'package:lastquake/models/safe_zone.dart';
import 'package:lastquake/utils/enums.dart';

abstract class SettingsRepository {
  Future<NotificationSettingsModel> getNotificationSettings();
  Future<void> saveNotificationSettings(NotificationSettingsModel settings);

  Future<List<SafeZone>> getSafeZones();
  Future<void> saveSafeZones(List<SafeZone> safeZones);

  Future<Set<DataSource>> getSelectedDataSources();
  Future<void> saveSelectedDataSources(Set<DataSource> sources);
}
