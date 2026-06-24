import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_care_admin/core/api_client.dart';
import 'package:home_care_admin/core/token_storage.dart';
import 'package:home_care_admin/screens/main/chat/chat_list_screen.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Individual chat room between provider and a patient.
class ChatRoomScreen extends StatefulWidget {
  final ProviderConversation conv;
  const ChatRoomScreen({super.key, required this.conv});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  static const _blue = Color(0xFF2563EB);

  final _input  = TextEditingController();
  final _scroll = ScrollController();

  List<_Msg> _msgs  = [];
  bool _loading = true;
  bool _sending = false;
  String _myId  = '';

  WebSocket? _ws;
  Timer? _wsRetry;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _disposed = true;
    _ws?.close();
    _wsRetry?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _myId = await TokenStorage.getUserId() ?? '';
    await _loadHistory();
    _connectWs();
    _markRead();
  }

  Future<void> _loadHistory() async {
    try {
      final res = await ApiClient.get(
          '/chat/conversations/${widget.conv.id}/messages');
      final list = (res['data'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((m) => _Msg.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      if (mounted) setState(() { _msgs = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
    _scrollToBottom();
  }

  void _markRead() {
    ApiClient.patch(
        '/chat/conversations/${widget.conv.id}/read', {}).catchError(
        (_) => <String, dynamic>{});
  }

  // ── WebSocket ─────────────────────────────────────────────────────────

  Future<void> _connectWs() async {
    if (_disposed) return;
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
      if (_disposed) { _ws?.close(); return; }
      _ws!.listen(_onWs,
          onDone: _retry, onError: (_) => _retry(),
          cancelOnError: false);
    } catch (_) {
      _retry();
    }
  }

  void _retry() {
    if (_disposed) return;
    _ws = null;
    _wsRetry?.cancel();
    _wsRetry = Timer(const Duration(seconds: 4), () {
      if (!_disposed) _connectWs();
    });
  }

  void _onWs(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      if (msg['type'] != 'peer_chat') return;
      final rawP = msg['payload'];
      final p = rawP is String
          ? jsonDecode(rawP) as Map<String, dynamic>
          : Map<String, dynamic>.from(rawP as Map);
      if (p['conversation_id'] != widget.conv.id) return;
      if (mounted) {
        setState(() {
          _msgs.add(_Msg(
            id: p['message_id'] ?? '',
            senderId: p['sender_id'] ?? '',
            content: p['content'] ?? '',
            messageType: p['message_type'] ?? 'text',
            fileUrl: p['file_url'] ?? '',
            fileName: p['file_name'] ?? '',
            fileSize: p['file_size'] ?? '',
            isRead: false,
            createdAt: p['created_at'] != null
                ? DateTime.tryParse(p['created_at'].toString()) ??
                    DateTime.now()
                : DateTime.now(),
          ));
        });
        _scrollToBottom();
        _markRead();
      }
    } catch (_) {}
  }

  // ── Send ──────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();

    final optimistic = _Msg(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      senderId: _myId,
      content: text,
      isRead: false,
      createdAt: DateTime.now(),
    );
    setState(() { _msgs.add(optimistic); _sending = true; });
    _scrollToBottom();

    try {
      final res = await ApiClient.post(
        '/chat/conversations/${widget.conv.id}/messages',
        {'content': text, 'message_type': 'text'},
      );
      final d = res['data'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          final idx =
              _msgs.indexWhere((m) => m.id == optimistic.id);
          if (idx != -1) _msgs[idx] = _Msg.fromJson(d);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _msgs.removeWhere((m) => m.id == optimistic.id));
        Get.snackbar('Error', 'Message failed. Please retry.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  // ── Media ─────────────────────────────────────────────────────────────

  Future<void> _pickFromCamera() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.camera, imageQuality: 75, maxWidth: 1280);
    if (picked == null) return;
    await _sendMedia(File(picked.path), 'image');
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 75, maxWidth: 1280);
    if (picked == null) return;
    await _sendMedia(File(picked.path), 'image');
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    final ext = path.split('.').last.toLowerCase();
    await _sendMedia(File(path), ext == 'pdf' ? 'pdf' : 'file');
  }

  Future<void> _sendMedia(File file, String type) async {
    if (_sending) return;
    setState(() => _sending = true);

    final optimisticId = '${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = _Msg(
      id: optimisticId,
      senderId: _myId,
      content: file.path.split('/').last,
      messageType: type,
      fileUrl: type == 'image' ? file.path : '',
      fileName: file.path.split('/').last,
      isRead: false,
      createdAt: DateTime.now(),
    );
    setState(() => _msgs.add(optimistic));
    _scrollToBottom();

    try {
      // Upload file
      final token = await TokenStorage.getToken() ?? '';
      final uri = Uri.parse('${ApiClient.baseUrl}/chat/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('file', file.path));
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final body = await streamed.stream.bytesToString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      if (streamed.statusCode != 200 && streamed.statusCode != 201) {
        throw Exception(json['message'] ?? 'Upload failed');
      }
      final meta = json['data'] as Map<String, dynamic>? ?? json;
      final fileUrl  = meta['file_url']  as String? ?? '';
      final fileName = meta['file_name'] as String? ?? '';
      final fileSize = meta['file_size'] as String? ?? '';

      // Send message
      final res = await ApiClient.post(
        '/chat/conversations/${widget.conv.id}/messages',
        {
          'content': type == 'image' ? '' : fileName,
          'message_type': type,
          'file_url': fileUrl,
          'file_name': fileName,
          'file_size': fileSize,
        },
      );
      final d = res['data'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          final idx = _msgs.indexWhere((m) => m.id == optimisticId);
          if (idx != -1) _msgs[idx] = _Msg.fromJson(d);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _msgs.removeWhere((m) => m.id == optimisticId));
        Get.snackbar('Upload Failed', e.toString().replaceAll('Exception: ', ''),
            snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildList()),
          _buildInput(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    final name = widget.conv.otherPartyName;
    final init = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    return AppBar(
      backgroundColor: _blue,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
        onPressed: () => Get.back(),
      ),
      titleSpacing: 0,
      title: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2)),
          child: Center(
            child: Text(init,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              Text(
                  'Booking #${widget.conv.bookingId.length >= 8 ? widget.conv.bookingId.substring(0, 8) : widget.conv.bookingId}',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 11)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _blue));
    }
    if (_msgs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 56,
                color: _blue.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            const Text('No messages yet.\nSay hello! 👋',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF64748B), fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _msgs.length,
      itemBuilder: (_, i) {
        final m = _msgs[i];
        final showDate = i == 0 ||
            !_sameDay(_msgs[i - 1].createdAt, m.createdAt);
        return Column(children: [
          if (showDate) _DateDivider(m.createdAt),
          _Bubble(msg: m, isMine: m.senderId == _myId),
        ]);
      },
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _ProvMediaBtn(Icons.camera_alt_rounded, Colors.green,
              _sending ? null : _pickFromCamera),
          _ProvMediaBtn(Icons.photo_library_rounded, Colors.orange,
              _sending ? null : _pickFromGallery),
          _ProvMediaBtn(Icons.attach_file_rounded, Colors.purple,
              _sending ? null : _pickFile),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _input,
                onSubmitted: (_) => _send(),
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14),
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Type a message…',
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _sending ? Colors.grey.shade300 : _blue,
                boxShadow: _sending
                    ? []
                    : [
                        BoxShadow(
                            color: _blue.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.day == b.day && a.month == b.month && a.year == b.year;
}

// ── Media icon button ─────────────────────────────────────────────────────────

class _ProvMediaBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ProvMediaBtn(this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34, height: 34,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
              color: onTap != null
                  ? color.withValues(alpha: 0.1)
                  : Colors.grey.shade100,
              shape: BoxShape.circle),
          child: Icon(icon,
              size: 17,
              color:
                  onTap != null ? color : Colors.grey.shade400),
        ),
      );
}

// ── Message model ─────────────────────────────────────────────────────────────

class _Msg {
  final String id;
  final String senderId;
  final String content;
  final String messageType; // text | image | file | pdf
  final String fileUrl;
  final String fileName;
  final String fileSize;
  final bool isRead;
  final DateTime createdAt;

  _Msg({
    required this.id,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    this.fileUrl = '',
    this.fileName = '',
    this.fileSize = '',
    required this.isRead,
    required this.createdAt,
  });

  bool get isImage => messageType == 'image';
  bool get isFile  => messageType == 'file' || messageType == 'pdf';

  factory _Msg.fromJson(Map<String, dynamic> j) => _Msg(
        id: j['message_id'] ?? '',
        senderId: j['sender_id'] ?? '',
        content: j['content'] ?? '',
        messageType: j['message_type'] ?? 'text',
        fileUrl: j['file_url'] ?? '',
        fileName: j['file_name'] ?? '',
        fileSize: j['file_size'] ?? '',
        isRead: j['is_read'] ?? false,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at']) ?? DateTime.now()
            : DateTime.now(),
      );
}

// ── Bubble ────────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final _Msg msg;
  final bool isMine;
  const _Bubble({required this.msg, required this.isMine});

  static const _blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          top: 4, bottom: 4,
          left: isMine ? (msg.isImage ? 24 : 56) : 0,
          right: isMine ? 0 : (msg.isImage ? 24 : 56)),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: msg.isImage
            ? _buildImageBubble(context)
            : msg.isFile
                ? _buildFileBubble()
                : _buildTextBubble(),
      ),
    );
  }

  Widget _buildTextBubble() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? _blue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 5, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(msg.content,
                style: TextStyle(
                    color: isMine ? Colors.white : const Color(0xFF1E293B),
                    fontSize: 14,
                    height: 1.4)),
            const SizedBox(height: 4),
            _ts(),
          ],
        ),
      );

  Widget _buildImageBubble(BuildContext context) {
    final url = msg.fileUrl;
    final isLocal = url.startsWith('/') || url.startsWith('file:');
    final imgWidget = isLocal
        ? Image.file(File(url), fit: BoxFit.cover)
        : Image.network(url, fit: BoxFit.cover,
            loadingBuilder: (_, child, prog) => prog == null
                ? child
                : const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: _blue))));
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    title: const Text('Image')),
                body: Center(
                    child: InteractiveViewer(
                        child: isLocal
                            ? Image.file(File(url))
                            : Image.network(url))),
              ))),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
        child: Stack(children: [
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: 200, minWidth: 100, maxHeight: 200),
            child: imgWidget,
          ),
          Positioned(
              bottom: 6, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8)),
                child: _ts(light: true),
              )),
        ]),
      ),
    );
  }

  Widget _buildFileBubble() {
    final isPdf = msg.messageType == 'pdf';
    final iconData = isPdf
        ? Icons.picture_as_pdf_rounded
        : Icons.insert_drive_file_rounded;
    final iconColor = isPdf ? Colors.red : _blue;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMine ? _blue : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5, offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: isMine
                    ? Colors.white.withValues(alpha: 0.2)
                    : iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(iconData,
                color: isMine ? Colors.white : iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(msg.fileName.isNotEmpty ? msg.fileName : 'File',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isMine ? Colors.white : const Color(0xFF1E293B))),
              if (msg.fileSize.isNotEmpty)
                Text(msg.fileSize,
                    style: TextStyle(
                        fontSize: 11,
                        color: isMine ? Colors.white60 : const Color(0xFF94A3B8))),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        _ts(),
      ]),
    );
  }

  Widget _ts({bool light = false}) {
    final dt = msg.createdAt;
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}',
          style: TextStyle(
              fontSize: 10,
              color: light
                  ? Colors.white70
                  : isMine
                      ? Colors.white.withValues(alpha: 0.65)
                      : const Color(0xFF94A3B8))),
      if (isMine) ...[
        const SizedBox(width: 4),
        Icon(
            msg.isRead ? Icons.done_all_rounded : Icons.done_rounded,
            size: 12,
            color: light
                ? Colors.white70
                : msg.isRead
                    ? Colors.lightBlueAccent
                    : Colors.white.withValues(alpha: 0.6)),
      ],
    ]);
  }
}

// ── Date divider ──────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider(this.date);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = (date.day == now.day &&
            date.month == now.month &&
            date.year == now.year)
        ? 'Today'
        : (date.day == now.day - 1 &&
                date.month == now.month &&
                date.year == now.year)
            ? 'Yesterday'
            : '${date.day}/${date.month}/${date.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF94A3B8))),
        ),
        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
      ]),
    );
  }
}
