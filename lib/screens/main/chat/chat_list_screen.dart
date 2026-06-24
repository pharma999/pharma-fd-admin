import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_care_admin/core/api_client.dart';
import 'package:home_care_admin/core/token_storage.dart';
import 'package:home_care_admin/screens/main/chat/chat_room_screen.dart';

/// Wraps a conversation returned from GET /chat/conversations
class ProviderConversation {
  final String id;
  final String bookingId;
  final String patientUserId;
  final String nurseUserId;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadNurse;
  final String otherPartyName;
  final String otherPartyId;

  ProviderConversation({
    required this.id,
    required this.bookingId,
    required this.patientUserId,
    required this.nurseUserId,
    required this.lastMessage,
    this.lastMessageAt,
    required this.unreadNurse,
    required this.otherPartyName,
    required this.otherPartyId,
  });

  factory ProviderConversation.fromJson(Map<String, dynamic> j) =>
      ProviderConversation(
        id: j['conversation_id'] ?? '',
        bookingId: j['booking_id'] ?? '',
        patientUserId: j['patient_user_id'] ?? '',
        nurseUserId: j['nurse_user_id'] ?? '',
        lastMessage: j['last_message'] ?? '',
        lastMessageAt: j['last_message_at'] != null
            ? DateTime.tryParse(j['last_message_at'])
            : null,
        unreadNurse: (j['unread_nurse'] ?? 0) as int,
        otherPartyName: j['other_party_name'] ?? 'Patient',
        otherPartyId: j['other_party_id'] ?? '',
      );
}

/// Lists all conversations for the logged-in provider.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ProviderConversation> _convs = [];
  bool _loading = true;

  // WebSocket for real-time conversation_created events
  WebSocket? _ws;
  Timer? _wsRetry;
  bool _wsDisposed = false;

  static const _blue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _load();
    _connectWs();
  }

  @override
  void dispose() {
    _wsDisposed = true;
    _ws?.close();
    _wsRetry?.cancel();
    super.dispose();
  }

  // ── WS ──────────────────────────────────────────────────────────────────────

  Future<void> _connectWs() async {
    if (_wsDisposed) return;
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) return;
      final base = ApiClient.baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://')
          .replaceAll('/api', '');
      _ws = await WebSocket.connect(
              '$base/api/ws?token=${Uri.encodeComponent(token)}')
          .timeout(const Duration(seconds: 10));
      if (_wsDisposed) { _ws?.close(); return; }
      _ws!.listen(_onWs,
          onDone: _scheduleWsRetry,
          onError: (_) => _scheduleWsRetry(),
          cancelOnError: false);
    } catch (_) {
      _scheduleWsRetry();
    }
  }

  void _scheduleWsRetry() {
    if (_wsDisposed) return;
    _ws = null;
    _wsRetry?.cancel();
    _wsRetry = Timer(const Duration(seconds: 5), () {
      if (!_wsDisposed) _connectWs();
    });
  }

  void _onWs(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String? ?? '';
      if (type == 'peer_chat') {
        final rawP = msg['payload'];
        final p = rawP is String
            ? jsonDecode(rawP) as Map<String, dynamic>
            : Map<String, dynamic>.from(rawP as Map);
        // Refresh list when a new conversation is created or a message arrives
        if ((p['event'] == 'conversation_created') ||
            p.containsKey('message_id')) {
          _load();
        }
      }
      // Also refresh when a booking is accepted
      if (type == 'booking_update' || type == 'booking_status') {
        _load();
      }
    } catch (_) {}
  }

  // ── REST ─────────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get('/chat/conversations');
      final list = (res['data'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((m) => ProviderConversation.fromJson(
              Map<String, dynamic>.from(m)))
          .toList();
      if (mounted) setState(() => _convs = list);
    } catch (_) {
      if (mounted) setState(() => _convs = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Messages',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        backgroundColor: _blue,
        automaticallyImplyLeading: false,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _blue))
          : _convs.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _blue,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _convs.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _ConvTile(conv: _convs[i], onTap: () async {
                          await Get.to(
                              () => ChatRoomScreen(conv: _convs[i]));
                          _load();
                        }),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.06),
                shape: BoxShape.circle),
            child: Icon(Icons.chat_bubble_outline_rounded,
                size: 44, color: _blue.withValues(alpha: 0.35)),
          ),
          const SizedBox(height: 16),
          const Text('No messages yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          const Text(
            'When you accept a booking, you can\nchat with the customer here.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

// ── Conversation tile ─────────────────────────────────────────────────────────

class _ConvTile extends StatelessWidget {
  final ProviderConversation conv;
  final VoidCallback onTap;
  const _ConvTile({required this.conv, required this.onTap});

  static const _blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final unread = conv.unreadNurse;
    final name   = conv.otherPartyName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: unread > 0
                  ? _blue.withValues(alpha: 0.3)
                  : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _blue.withValues(alpha: 0.1),
              border: Border.all(
                  color: _blue.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: _blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1E293B))),
                      if (conv.lastMessageAt != null)
                        Text(_fmtTime(conv.lastMessageAt!),
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8))),
                    ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                    child: Text(
                      conv.lastMessage.isEmpty
                          ? 'Start chatting'
                          : conv.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: unread > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: unread > 0
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  if (unread > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: _blue,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day &&
        dt.month == now.month &&
        dt.year == now.year) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
    }
    return '${dt.day}/${dt.month}';
  }
}
