// ── API Configuration ─────────────────────────────────────────────────────
//
// Override the base URL at build time using --dart-define:
//   flutter run --dart-define=API_BASE_URL=http://192.168.1.x:8080/api
//
// Defaults:
//   Android emulator  → http://10.0.2.2:8080/api
//   iOS simulator     → http://localhost:8080/api
//   Physical device   → set API_BASE_URL to your LAN IP
//   Production        → set API_BASE_URL to your server URL

class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  static const int timeoutSec = 30;
}
