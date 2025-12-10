import 'package:lastquakes/domain/repositories/device_repository.dart';
import 'package:lastquakes/utils/secure_logger.dart';

class DeviceRepositoryNoop implements DeviceRepository {
  @override
  Future<void> registerDevice(
    String token,
    Map<String, dynamic> preferences,
  ) async {
    SecureLogger.info(
      "DeviceRepositoryNoop: registerDevice called (FOSS mode)",
    );
    // Do nothing
  }
}
