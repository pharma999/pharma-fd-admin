import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_config.dart';
import 'token_storage.dart';

enum AdminWsEvent { emergencyNew, emergencyStatus, ambulanceLocation, ping }

class AdminWsMessage {
  final AdminWsEvent event;
  final Map<String, dynamic> payload;
  const AdminWsMessage(this.event, this.payload);
}

/// Singleton WebSocket client for the admin panel.
/// Subscribes to `admin:emergencies` room automatically after connect.
class AdminWebSocket {
  AdminWebSocket._();
  static final instance = AdminWebSocket._();

  WebSocketChannel? _channel;
  final _controller = StreamController<AdminWsMessage>.broadcast();
  Stream<AdminWsMessage> get messages => _controller.stream;

  bool _connected = false;
  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_connected) return;
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) return;

      // Convert http://host/api → ws://host/api
      final wsBase = ApiConfig.baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');

      final uri = Uri.parse('$wsBase/ws?token=$token&rooms=admin:emergencies');
      _channel = WebSocketChannel.connect(uri);
      _connected = true;

      _channel!.stream.listen(
        (raw) {
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            final type = data['type'] as String? ?? '';
            final payload =
                (data['payload'] as Map<String, dynamic>?) ?? {};
            final event = _toEvent(type);
            if (event != null) _controller.add(AdminWsMessage(event, payload));
          } catch (_) {}
        },
        onDone: () => _connected = false,
        onError: (_) => _connected = false,
      );
    } catch (_) {
      _connected = false;
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _connected = false;
  }

  AdminWsEvent? _toEvent(String type) {
    switch (type) {
      case 'emergency_triggered':
        return AdminWsEvent.emergencyNew;
      case 'emergency_status':
        return AdminWsEvent.emergencyStatus;
      case 'ambulance_location':
        return AdminWsEvent.ambulanceLocation;
      case 'ping':
        return AdminWsEvent.ping;
      default:
        return null;
    }
  }
}
