import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_care_admin/core/api_client.dart';
import 'package:home_care_admin/screens/call/video_call_screen.dart';

// ── IncomingCallScreen (Provider App) ────────────────────────────────────────
// Full-screen alert shown to the provider when a patient starts a call.
// Pushed by the WS listener in BookingsScreen._handleWsMessage().

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerId;       // patient's user_id
  final String callerName;
  final String bookingId;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.bookingId,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  Timer? _autoRejectTimer;
  bool _busy = false;

  static const _primary = Color(0xFF1A56DB);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.94, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _autoRejectTimer = Timer(const Duration(seconds: 45), () {
      if (mounted) _reject();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _autoRejectTimer?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    _autoRejectTimer?.cancel();
    try {
      await ApiClient.post('calls/${widget.callId}/accept', {});
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            callId:       widget.callId,
            remoteUserId: widget.callerId,
            remoteName:   widget.callerName,
            bookingId:    widget.bookingId,
            isCaller:     false,
          ),
        ),
      );
    } catch (e) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not accept call')));
    }
  }

  Future<void> _reject() async {
    if (_busy) return;
    setState(() => _busy = true);
    _autoRejectTimer?.cancel();
    try {
      await ApiClient.post('calls/${widget.callId}/reject', {});
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Column(children: [
          const Spacer(flex: 2),

          // ── Avatar ──────────────────────────────────────────────────────
          ScaleTransition(
            scale: _pulse,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_primary, Color(0xFF0E3999)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                      color: _primary.withValues(alpha: 0.5),
                      blurRadius: 30, spreadRadius: 5)
                ],
              ),
              child: Center(
                child: Text(
                  widget.callerName.isNotEmpty
                      ? widget.callerName[0].toUpperCase()
                      : 'P',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 48,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),
          Text(widget.callerName,
              style: const TextStyle(
                  color: Colors.white, fontSize: 26,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Incoming Video Call',
              style: TextStyle(color: Colors.white60, fontSize: 14)),

          const Spacer(flex: 3),

          // ── Buttons ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CallBtn(
                  icon: Icons.call_end_rounded,
                  color: Colors.red,
                  label: 'Decline',
                  onTap: _busy ? null : _reject,
                ),
                _CallBtn(
                  icon: Icons.videocam_rounded,
                  color: Colors.green,
                  label: 'Accept',
                  onTap: _busy ? null : _accept,
                ),
              ],
            ),
          ),
          const SizedBox(height: 60),
        ]),
      ),
    );
  }
}

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  const _CallBtn({required this.icon, required this.color,
      required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 16, spreadRadius: 2)]),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      );
}
