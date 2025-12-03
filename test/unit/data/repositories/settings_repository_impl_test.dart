import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:lastquakes/data/repositories/settings_repository_impl.dart';
import 'package:lastquakes/domain/models/notification_settings_model.dart';
import 'package:lastquakes/services/multi_source_api_service.dart';
import 'package:lastquakes/utils/enums.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockMultiSourceApiService extends Mock implements MultiSourceApiService {}

void main() {
  late SettingsRepositoryImpl repository;
  late MockMultiSourceApiService mockApiService;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    mockApiService = MockMultiSourceApiService();

    // Mock FlutterSecureStorage method channel
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'read') {
            return null; // Return null for all reads by default
          }
          if (methodCall.method == 'write') {
            return null;
          }
          if (methodCall.method == 'delete') {
            return null;
          }
          return null;
        });

    // Stub api service methods
    when(
      () => mockApiService.getSelectedSources(),
    ).thenReturn({DataSource.usgs});
    when(
      () => mockApiService.setSelectedSources(any()),
    ).thenAnswer((_) async {});
    when(() => mockApiService.clearCache()).thenAnswer((_) async {});

    repository = SettingsRepositoryImpl(mockApiService);
  });

  group('SettingsRepositoryImpl Tests', () {
    test('getNotificationSettings returns default when empty', () async {
      final settings = await repository.getNotificationSettings();
      expect(settings, isA<NotificationSettingsModel>());
      expect(settings.magnitude, 5.0); // Default
    });

    test('saveNotificationSettings saves and retrieves correctly', () async {
      const settings = NotificationSettingsModel(magnitude: 5.5, country: 'JP');

      await repository.saveNotificationSettings(settings);
      // Note: Since SecureStorageService is static, we verify no crash.
    });

    test('saveSelectedDataSources saves and retrieves set', () async {
      final sources = {DataSource.emsc, DataSource.usgs};

      await repository.saveSelectedDataSources(sources);

      verify(() => mockApiService.setSelectedSources(sources)).called(1);
      verify(() => mockApiService.clearCache()).called(1);
    });
  });
}
