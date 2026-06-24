import 'package:flutter/foundation.dart';

class ApiConfig {
  // Override at run time:
  //   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080/api
  //
  // Current server LAN IP: 192.168.1.7
  //   Web browser          → http://localhost:8080/api
  //   Android emulator     → http://10.0.2.2:8080/api
  //   Physical Android     → http://192.168.1.7:8080/api
  //   Windows/macOS/Linux  → http://localhost:8080/api
  static const String _serverLanIp = '192.168.1.7';

  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kIsWeb) return 'http://localhost:8080/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://$_serverLanIp:8080/api';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://$_serverLanIp:8080/api';
    }
    return 'http://localhost:8080/api';
  }

  static const int timeoutSec = 30;
}
