/// Platform-agnostic push notification message model.
/// This abstracts away Firebase's RemoteMessage to allow FOSS builds
/// without Firebase dependencies in shared code.
class PushMessage {
  final String? title;
  final String? body;
  final Map<String, dynamic> data;

  const PushMessage({this.title, this.body, this.data = const {}});

  /// Get a value from data with optional default
  String? getDataValue(String key, {String? defaultValue}) {
    return data[key]?.toString() ?? defaultValue;
  }
}
