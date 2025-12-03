import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'cache_manager.dart';

Future<CacheManager> createCacheManager() async {
  final manager = CacheManagerIO();
  await manager.init();
  return manager;
}

class CacheManagerIO implements CacheManager {
  late Directory _cacheDir;

  @override
  Future<void> init() async {
    _cacheDir = await getApplicationDocumentsDirectory();
  }

  File _getFile(String key) {
    return File('${_cacheDir.path}/$key');
  }

  @override
  Future<String?> read(String key) async {
    final file = _getFile(key);
    if (await file.exists()) {
      return await file.readAsString();
    }
    return null;
  }

  @override
  Future<void> write(String key, String content) async {
    final file = _getFile(key);
    await file.writeAsString(content);
  }

  @override
  Future<void> delete(String key) async {
    final file = _getFile(key);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> clear() async {
    final files = _cacheDir.listSync();
    for (final file in files) {
      if (file is File && file.path.endsWith('.json')) {
        try {
          await file.delete();
        } catch (e) {
          // Ignore errors
        }
      }
    }
  }

  @override
  Future<bool> exists(String key) async {
    return await _getFile(key).exists();
  }

  @override
  Future<int> getSize(String key) async {
    final file = _getFile(key);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }
}
