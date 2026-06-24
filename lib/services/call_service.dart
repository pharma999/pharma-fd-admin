import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:home_care_admin/core/api_config.dart';
import 'package:home_care_admin/core/token_storage.dart';

// ── CallService (Provider App) ────────────────────────────────────────────────
// Manages the WebRTC peer connection and WS signaling channel for one call.
// Mirrors the patient app's CallService — shared logic, separate package.

class CallService {
  static const _iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun.cloudflare.com:3478'},
  ];

  final String callId;
  final String remoteUserId;
  final bool isCaller;

  RTCPeerConnection? _pc;
  MediaStream? localStream;
  MediaStream? remoteStream;

  final remoteRenderer = RTCVideoRenderer();
  final localRenderer  = RTCVideoRenderer();

  WebSocket? _ws;
  bool _disposed = false;

  final ValueNotifier<bool> micEnabled    = ValueNotifier(true);
  final ValueNotifier<bool> cameraEnabled = ValueNotifier(true);
  final ValueNotifier<bool> connected     = ValueNotifier(false);

  VoidCallback? onRemoteEnd;

  CallService({
    required this.callId,
    required this.remoteUserId,
    required this.isCaller,
  });

  Future<void> init() async {
    await remoteRenderer.initialize();
    await localRenderer.initialize();
    await _openSignalingWS();
    await _openCamera();
    await _createPeerConnection();
    if (isCaller) await _sendOffer();
  }

  Future<void> _openSignalingWS() async {
    final token = await TokenStorage.getToken() ?? '';
    final wsBase = ApiConfig.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://')
        .replaceAll('/api', '');
    final uri = '$wsBase/api/ws?token=${Uri.encodeComponent(token)}';
    try {
      _ws = await WebSocket.connect(uri).timeout(const Duration(seconds: 10));
      _ws!.listen(_onWsMessage, onError: (_) {}, onDone: () {});
    } catch (e) {
      debugPrint('[CallService] WS connect failed: $e');
    }
  }

  void _sendSignal(String signalType, Map<String, dynamic> data) {
    if (_ws == null || _disposed) return;
    _ws!.add(jsonEncode({
      'type':        'call_signal',
      'to':          remoteUserId,
      'call_id':     callId,
      'signal_type': signalType,
      'data':        data,
    }));
  }

  void _onWsMessage(dynamic raw) {
    if (_disposed) return;
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String? ?? '';
      if (type != 'call_signal') {
        if (type == 'call_ended') onRemoteEnd?.call();
        return;
      }
      final p = msg['payload'] is String
          ? jsonDecode(msg['payload'] as String) as Map<String, dynamic>
          : Map<String, dynamic>.from(msg['payload'] as Map);

      final signalType = p['signal_type'] as String? ?? '';
      final data       = p['data'] as Map<String, dynamic>? ?? {};

      switch (signalType) {
        case 'offer':  _handleRemoteOffer(data);
        case 'answer': _handleRemoteAnswer(data);
        case 'ice_candidate': _handleRemoteIce(data);
      }
    } catch (_) {}
  }

  Future<void> _openCamera() async {
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user', 'width': {'ideal': 640}, 'height': {'ideal': 480}},
    });
    localRenderer.srcObject = localStream;
  }

  Future<void> _createPeerConnection() async {
    _pc = await createPeerConnection({
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
    });
    localStream?.getTracks().forEach((t) => _pc!.addTrack(t, localStream!));
    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        remoteRenderer.srcObject = remoteStream;
        connected.value = true;
      }
    };
    _pc!.onIceCandidate = (c) => _sendSignal('ice_candidate', c.toMap());
  }

  Future<void> _sendOffer() async {
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    _sendSignal('offer', {'sdp': offer.sdp, 'type': offer.type});
  }

  Future<void> _handleRemoteOffer(Map<String, dynamic> d) async {
    await _pc?.setRemoteDescription(RTCSessionDescription(d['sdp'], d['type']));
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    _sendSignal('answer', {'sdp': answer.sdp, 'type': answer.type});
    connected.value = true;
  }

  Future<void> _handleRemoteAnswer(Map<String, dynamic> d) async {
    await _pc?.setRemoteDescription(RTCSessionDescription(d['sdp'], d['type']));
    connected.value = true;
  }

  Future<void> _handleRemoteIce(Map<String, dynamic> d) async {
    await _pc?.addCandidate(RTCIceCandidate(d['candidate'], d['sdpMid'], d['sdpMLineIndex']));
  }

  void toggleMic() {
    final on = !micEnabled.value;
    localStream?.getAudioTracks().forEach((t) => t.enabled = on);
    micEnabled.value = on;
  }

  void toggleCamera() {
    final on = !cameraEnabled.value;
    localStream?.getVideoTracks().forEach((t) => t.enabled = on);
    cameraEnabled.value = on;
  }

  Future<void> switchCamera() async {
    final tracks = localStream?.getVideoTracks();
    if (tracks != null && tracks.isNotEmpty) await Helper.switchCamera(tracks.first);
  }

  Future<void> dispose() async {
    _disposed = true;
    await localStream?.dispose();
    await remoteStream?.dispose();
    await _pc?.close();
    await _ws?.close();
    localRenderer.dispose();
    remoteRenderer.dispose();
    micEnabled.dispose();
    cameraEnabled.dispose();
    connected.dispose();
  }
}
