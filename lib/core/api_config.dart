import 'package:flutter/foundation.dart';

class ApiConfig {
  // Override at run time:
  //   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080/api
  //
  // Auto-detection (no --dart-define set):
  //   Web browser          → http://localhost:8080/api
  //   Android emulator     → http://10.0.2.2:8080/api
  //   Physical Android     → supply --dart-define with your LAN IP
  //   Windows/macOS/Linux  → http://localhost:8080/api
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api';
    }
    return 'http://localhost:8080/api';
  }

  static const int timeoutSec = 30;
}
