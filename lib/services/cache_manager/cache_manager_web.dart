import 'package:hive_flutter/hive_flutter.dart';
import 'cache_manager.dart';

Future<CacheManager> createCacheManager() async {
  final manager = CacheManagerWeb();
  await manager.init();
  return manager;
}

class CacheManagerWeb implements CacheManager {
  late Box<String> _box;
  static const String _boxName = 'earthquake_web_cache';

  @override
  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<String>(_boxName);
    } else {
      _box = Hive.box<String>(_boxName);
    }
  }

  @override
  Future<String?> read(String key) async {
    return _box.get(key);
  }

  @override
  Future<void> write(String key, String content) async {
    await _box.put(key, content);
  }

  @override
  Future<void> delete(String key) async {
    await _box.delete(key);
  }

  @override
  Future<void> clear() async {
    await _box.clear();
  }

  @override
  Future<bool> exists(String key) async {
    return _box.containsKey(key);
  }

  @override
  Future<int> getSize(String key) async {
    final content = _box.get(key);
    return content?.length ?? 0;
  }
}
