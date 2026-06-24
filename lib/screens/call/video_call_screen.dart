import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:home_care_admin/core/api_client.dart';
import 'package:home_care_admin/services/call_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// ── VideoCallScreen (Provider App) ───────────────────────────────────────────
// In-call screen: local PiP + full-screen remote video, mute/camera controls.

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final String remoteUserId;
  final String remoteName;
  final String bookingId;
  final bool isCaller;

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.remoteUserId,
    required this.remoteName,
    required this.bookingId,
    required this.isCaller,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late CallService _call;
  final _duration = ValueNotifier<int>(0);
  Timer? _timer;
  bool _controlsVisible = true;
  bool _ending = false;

  static const _primary = Color(0xFF1A56DB);

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _call = CallService(
      callId: widget.callId,
      remoteUserId: widget.remoteUserId,
      isCaller: widget.isCaller,
    );
    _call.onRemoteEnd = () {
      if (mounted && !_ending) _hangUp(remoteEnded: true);
    };
    _call.init().then((_) {
      _timer = Timer.periodic(
          const Duration(seconds: 1), (_) => _duration.value++);
      if (mounted) setState(() {});
    });
  }

  Future<void> _hangUp({bool remoteEnded = false}) async {
    if (_ending) return;
    _ending = true;
    _timer?.cancel();
    WakelockPlus.disable();
    if (!remoteEnded) {
      try {
        await ApiClient.post('calls/${widget.callId}/end', {});
      } catch (_) {}
    }
    await _call.dispose();
    if (mounted) Navigator.of(context).pop();
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _timer?.cancel();
    _duration.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () =>
            setState(() => _controlsVisible = !_controlsVisible),
        child: Stack(fit: StackFit.expand, children: [
          // ── Remote video ────────────────────────────────────────────────
          RTCVideoView(
            _call.remoteRenderer,
            objectFit:
                RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),

          // ── Connecting overlay ──────────────────────────────────────────
          ValueListenableBuilder<bool>(
            valueListenable: _call.connected,
            builder: (_, connected, __) => connected
                ? const SizedBox.shrink()
                : Container(
                    color: const Color(0xCC0A1628),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                            color: Colors.white),
                        const SizedBox(height: 20),
                        Text('Connecting to ${widget.remoteName}…',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16)),
                      ],
                    ),
                  ),
          ),

          // ── Local PiP ───────────────────────────────────────────────────
          Positioned(
            top: 52, right: 16,
            child: Container(
              width: 100, height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white30),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: RTCVideoView(
                  _call.localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit
                      .RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),

          // ── Top bar ─────────────────────────────────────────────────────
          AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 12,
                    left: 20, right: 20, bottom: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.remoteName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    ValueListenableBuilder<int>(
                      valueListenable: _duration,
                      builder: (_, s, __) => Text(_fmt(s),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Controls ────────────────────────────────────────────────────
          AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 40),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(40)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _call.micEnabled,
                      builder: (_, on, __) => _Btn(
                        icon: on
                            ? Icons.mic_rounded
                            : Icons.mic_off_rounded,
                        label: on ? 'Mute' : 'Unmute',
                        bg: _primary.withValues(alpha: 0.85),
                        onTap: _call.toggleMic,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _Btn(
                      icon: Icons.call_end_rounded,
                      label: 'End',
                      bg: Colors.red,
                      size: 62,
                      onTap: () => _hangUp(),
                    ),
                    const SizedBox(width: 16),
                    ValueListenableBuilder<bool>(
                      valueListenable: _call.cameraEnabled,
                      builder: (_, on, __) => _Btn(
                        icon: on
                            ? Icons.videocam_rounded
                            : Icons.videocam_off_rounded,
                        label: on ? 'Cam off' : 'Cam on',
                        bg: _primary.withValues(alpha: 0.85),
                        onTap: _call.toggleCamera,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _Btn(
                      icon: Icons.flip_camera_ios_rounded,
                      label: 'Flip',
                      bg: Colors.white24,
                      onTap: _call.switchCamera,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final double size;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.label,
      required this.bg, required this.onTap, this.size = 52});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: size, height: size,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
          const SizedBox(height: 5),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
      );
}
