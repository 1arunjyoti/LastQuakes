import 'package:http/http.dart' as http;

http.Client createClient() {
  return http.Client();
}

bool checkSocketException(Object e) {
  return false;
}

bool checkHandshakeException(Object e) {
  return false;
}
