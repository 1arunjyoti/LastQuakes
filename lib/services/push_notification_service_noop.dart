import 'package:lastquakes/services/push_notification_service.dart';
import 'package:lastquakes/utils/secure_logger.dart';

class PushNotificationServiceNoop implements PushNotificationService {
  @override
  Future<void> initialize() async {
    SecureLogger.info("PushNotificationServiceNoop initialized (FOSS flavor)");
  }

  @override
  Future<void> requestPermission() async {
    // No-op
  }

  @override
  Future<String?> getToken() async {
    return null;
  }
}
