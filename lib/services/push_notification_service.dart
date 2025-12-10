abstract class PushNotificationService {
  static late PushNotificationService instance;

  Future<void> initialize();
  Future<void> requestPermission();
  Future<String?> getToken();
}
