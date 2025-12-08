import 'package:flutter/foundation.dart';
import 'package:lastquakes/models/earthquake.dart';
import 'package:lastquakes/services/bookmark_service.dart';

/// Provider for managing bookmark state with reactive updates.
/// Uses BookmarkService for persistence and provides O(1) lookup operations.
class BookmarkProvider with ChangeNotifier {
  final BookmarkService _bookmarkService = BookmarkService.instance;

  List<Earthquake> _bookmarks = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  /// List of bookmarked earthquakes
  List<Earthquake> get bookmarks => _bookmarks;

  /// Whether bookmarks are currently loading
  bool get isLoading => _isLoading;

  /// Number of bookmarked earthquakes
  int get bookmarkCount => _bookmarkService.bookmarkCount;

  /// Check if an earthquake is bookmarked - O(1) operation
  bool isBookmarked(String earthquakeId) {
    return _bookmarkService.isBookmarked(earthquakeId);
  }

  /// Initialize and load bookmarks
  Future<void> loadBookmarks() async {
    if (_isInitialized && _bookmarks.isNotEmpty) return;

    _isLoading = true;
    // Don't notify here to avoid unnecessary rebuilds during init

    try {
      await _bookmarkService.init();
      _bookmarks = await _bookmarkService.getBookmarks();
      _isInitialized = true;
    } catch (e) {
      debugPrint('BookmarkProvider: Error loading bookmarks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle bookmark status for an earthquake
  Future<void> toggleBookmark(Earthquake earthquake) async {
    final wasBookmarked = isBookmarked(earthquake.id);

    // Optimistic update for immediate UI response
    if (wasBookmarked) {
      _bookmarks.removeWhere((e) => e.id == earthquake.id);
    } else {
      _bookmarks.insert(0, earthquake);
    }
    notifyListeners();

    // Persist the change
    try {
      await _bookmarkService.toggleBookmark(earthquake);
    } catch (e) {
      // Rollback on error
      if (wasBookmarked) {
        _bookmarks.insert(0, earthquake);
      } else {
        _bookmarks.removeWhere((e) => e.id == earthquake.id);
      }
      notifyListeners();
      debugPrint('BookmarkProvider: Error toggling bookmark: $e');
    }
  }

  /// Remove a bookmark
  Future<void> removeBookmark(String earthquakeId) async {
    final earthquake = _bookmarks.firstWhere(
      (e) => e.id == earthquakeId,
      orElse: () => throw StateError('Earthquake not found'),
    );

    _bookmarks.removeWhere((e) => e.id == earthquakeId);
    notifyListeners();

    try {
      await _bookmarkService.removeBookmark(earthquakeId);
    } catch (e) {
      // Rollback on error
      _bookmarks.insert(0, earthquake);
      notifyListeners();
      debugPrint('BookmarkProvider: Error removing bookmark: $e');
    }
  }

  /// Clear all bookmarks
  Future<void> clearAllBookmarks() async {
    final previousBookmarks = List<Earthquake>.from(_bookmarks);

    _bookmarks.clear();
    notifyListeners();

    try {
      await _bookmarkService.clearAll();
    } catch (e) {
      // Rollback on error
      _bookmarks = previousBookmarks;
      notifyListeners();
      debugPrint('BookmarkProvider: Error clearing bookmarks: $e');
    }
  }

  /// Refresh bookmarks from storage
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      _bookmarks = await _bookmarkService.getBookmarks();
    } catch (e) {
      debugPrint('BookmarkProvider: Error refreshing bookmarks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
