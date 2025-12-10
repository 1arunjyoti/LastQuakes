import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:lastquakes/models/earthquake.dart';

/// Optimized service for managing bookmarked earthquakes using Hive.
/// Uses lazy loading and efficient O(1) lookups for bookmark status checks.
class BookmarkService {
  static const String _boxName = 'earthquake_bookmarks';

  // Singleton instance for app-wide access
  static final BookmarkService _instance = BookmarkService._internal();
  static BookmarkService get instance => _instance;

  BookmarkService._internal();

  // Cache box reference to avoid repeated async calls
  Box<Earthquake>? _box;

  // In-memory cache of bookmark IDs for O(1) lookups
  final Set<String> _bookmarkIds = {};
  bool _isInitialized = false;

  /// Initialize the service - call this during app startup
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox<Earthquake>(_boxName);
      } else {
        _box = Hive.box<Earthquake>(_boxName);
      }

      // Pre-populate the ID cache for O(1) lookups
      _bookmarkIds.clear();
      _bookmarkIds.addAll(_box!.keys.cast<String>());

      _isInitialized = true;
      debugPrint(
        'BookmarkService: Initialized with ${_bookmarkIds.length} bookmarks',
      );
    } catch (e) {
      debugPrint('BookmarkService: Error initializing: $e');
    }
  }

  /// Get the Hive box, initializing if needed
  Future<Box<Earthquake>> _getBox() async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }
    return _box!;
  }

  /// Check if an earthquake is bookmarked - O(1) operation
  bool isBookmarked(String earthquakeId) {
    return _bookmarkIds.contains(earthquakeId);
  }

  /// Get all bookmarked earthquakes, sorted by bookmark time (newest first)
  Future<List<Earthquake>> getBookmarks() async {
    try {
      final box = await _getBox();
      final bookmarks = box.values.toList();

      // Sort by time (most recent earthquakes first)
      bookmarks.sort((a, b) => b.time.compareTo(a.time));

      return bookmarks;
    } catch (e) {
      debugPrint('BookmarkService: Error getting bookmarks: $e');
      return [];
    }
  }

  /// Add an earthquake to bookmarks
  Future<void> addBookmark(Earthquake earthquake) async {
    try {
      final box = await _getBox();

      // Use earthquake ID as the key for efficient lookup
      await box.put(earthquake.id, earthquake);
      _bookmarkIds.add(earthquake.id);

      debugPrint('BookmarkService: Added bookmark for ${earthquake.id}');
    } catch (e) {
      debugPrint('BookmarkService: Error adding bookmark: $e');
    }
  }

  /// Remove an earthquake from bookmarks
  Future<void> removeBookmark(String earthquakeId) async {
    try {
      final box = await _getBox();

      await box.delete(earthquakeId);
      _bookmarkIds.remove(earthquakeId);

      debugPrint('BookmarkService: Removed bookmark for $earthquakeId');
    } catch (e) {
      debugPrint('BookmarkService: Error removing bookmark: $e');
    }
  }

  /// Toggle bookmark status for an earthquake
  Future<bool> toggleBookmark(Earthquake earthquake) async {
    if (isBookmarked(earthquake.id)) {
      await removeBookmark(earthquake.id);
      return false;
    } else {
      await addBookmark(earthquake);
      return true;
    }
  }

  /// Get the count of bookmarked earthquakes
  int get bookmarkCount => _bookmarkIds.length;

  /// Clear all bookmarks
  Future<void> clearAll() async {
    try {
      final box = await _getBox();
      await box.clear();
      _bookmarkIds.clear();

      debugPrint('BookmarkService: Cleared all bookmarks');
    } catch (e) {
      debugPrint('BookmarkService: Error clearing bookmarks: $e');
    }
  }

  /// Dispose the service (call on app close)
  Future<void> dispose() async {
    try {
      if (_box != null && _box!.isOpen) {
        await _box!.close();
      }
      _isInitialized = false;
    } catch (e) {
      debugPrint('BookmarkService: Error disposing: $e');
    }
  }
}
