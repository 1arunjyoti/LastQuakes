import 'dart:async';

/// Coordinates backend notification registrations by brokering requests
/// between platform services (token refresh, permission changes) and the
/// SettingsProvider, which actually knows the user's preferences.
typedef NotificationSyncCallback = Future<void> Function();

class NotificationRegistrationCoordinator {
  static NotificationSyncCallback? _syncCallback;
  static bool _pendingSyncRequest = false;

  /// Registers the callback that should be executed whenever a sync is needed.
  /// Typically called by SettingsProvider once it has loaded persisted settings.
  static void registerSyncCallback(NotificationSyncCallback callback) {
    _syncCallback = callback;

    if (_pendingSyncRequest) {
      _pendingSyncRequest = false;
      // Fire-and-forget is acceptable here; caller requested sync before we
      // had a callback. Any errors will be handled inside the provider.
      unawaited(callback());
    }
  }

  /// Clears the current callback, e.g., when the provider is disposed.
  static void unregisterSyncCallback(NotificationSyncCallback callback) {
    if (identical(_syncCallback, callback)) {
      _syncCallback = null;
    }
  }

  /// Request a backend sync. If the SettingsProvider hasn't registered yet,
  /// the request will be queued and executed once registration completes.
  static Future<void> requestSync() async {
    final callback = _syncCallback;
    if (callback != null) {
      await callback();
    } else {
      _pendingSyncRequest = true;
    }
  }
}
