import 'package:flutter_test/flutter_test.dart';
import 'package:lastquakes/models/push_message.dart';
import 'package:lastquakes/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

void main() {
  late NotificationService service;
  late MockFlutterLocalNotificationsPlugin mockPlugin;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    service = NotificationService.test(plugin: mockPlugin);

    registerFallbackValue(
      const InitializationSettings(
        android: AndroidInitializationSettings('app_icon'),
      ),
    );

    // Stub initialization
    when(
      () => mockPlugin.initialize(
        any(),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
        onDidReceiveBackgroundNotificationResponse: any(
          named: 'onDidReceiveBackgroundNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => true);
  });

  group('NotificationService Tests', () {
    test('initNotifications initializes the plugin', () async {
      await service.initNotifications();

      verify(
        () => mockPlugin.initialize(
          any(),
          onDidReceiveNotificationResponse: any(
            named: 'onDidReceiveNotificationResponse',
          ),
          onDidReceiveBackgroundNotificationResponse: any(
            named: 'onDidReceiveBackgroundNotificationResponse',
          ),
        ),
      ).called(1);
    });

    test('showPushNotification calls plugin show', () async {
      when(
        () => mockPlugin.show(
          any(),
          any(),
          any(),
          any(),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      const message = PushMessage(
        title: 'Test',
        body: 'Body',
        data: {'title': 'Test', 'body': 'Body', 'earthquakeId': '123'},
      );

      await service.showPushNotification(message);

      verify(
        () => mockPlugin.show(any(), 'Test', 'Body', any(), payload: '123'),
      ).called(1);
    });
  });
}
