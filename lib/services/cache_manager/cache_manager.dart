import 'cache_manager_io.dart' if (dart.library.html) 'cache_manager_web.dart';

abstract class CacheManager {
  Future<void> init();
  Future<String?> read(String key);
  Future<void> write(String key, String content);
  Future<void> delete(String key);
  Future<void> clear();
  Future<bool> exists(String key);
  Future<int> getSize(String key);

  static Future<CacheManager> create() => createCacheManager();
}
