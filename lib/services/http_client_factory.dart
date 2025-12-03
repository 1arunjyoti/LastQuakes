import 'package:http/http.dart' as http;

import 'http_client_factory_io.dart'
    if (dart.library.html) 'http_client_factory_web.dart';

http.Client createHttpClient() => createClient();

bool isSocketException(Object e) => checkSocketException(e);

bool isHandshakeException(Object e) => checkHandshakeException(e);
