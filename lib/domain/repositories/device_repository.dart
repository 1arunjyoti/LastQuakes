abstract class DeviceRepository {
  Future<void> registerDevice(String token, Map<String, dynamic> preferences);
}
