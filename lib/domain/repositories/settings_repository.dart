import 'package:lastquakes/utils/enums.dart';

abstract class SettingsRepository {
  Future<Set<DataSource>> getSelectedDataSources();
  Future<void> saveSelectedDataSources(Set<DataSource> sources);
}
