import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:home_care_admin/core/api_client.dart';
import 'package:home_care_admin/models/provider_models.dart';
import 'package:home_care_admin/screens/main/bookings/booking_map_screen.dart';

/// Full-screen incoming booking alert — shown when a new booking is
/// assigned to this provider via WebSocket.  Plays a looping ringtone
/// and displays a countdown. Provider must Accept or Reject within
/// [timeoutSeconds] or the booking is re-assigned automatically.
class IncomingBookingScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final int timeoutSeconds;

  const IncomingBookingScreen({
    super.key,
    required this.bookingData,
    this.timeoutSeconds = 60,
  });

  @override
  State<IncomingBookingScreen> createState() => _IncomingBookingScreenState();
}

class _IncomingBookingScreenState extends State<IncomingBookingScreen>
    with TickerProviderStateMixin {
  late int _remaining;
  Timer? _countdownTimer;
  Timer? _alertTimer;

  final _player = AudioPlayer();
  bool _isProcessing = false;

  // Pulse animation for the accept button
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _remaining = widget.timeoutSeconds;

    // Pulse animation on accept button
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _startSound();
    _startCountdown();
  }

  void _startSound() {
    // Play asset sound if available, otherwise fall back to system beeps.
    // To add a custom ringtone: create assets/sounds/booking_alert.mp3
    // and register it in pubspec.yaml under flutter: assets:
    _player.setReleaseMode(ReleaseMode.loop);
    _player.play(AssetSource('sounds/booking_alert.mp3')).catchError((_) {
      // Asset not found — fall back to repeating system alert
      _alertTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
      });
    });
  }

  void _stopSound() {
    _player.stop();
    _alertTimer?.cancel();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _countdownTimer?.cancel();
        _stopSound();
        if (mounted) Navigator.of(context).pop(false);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _alertTimer?.cancel();
    _pulseCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _countdownTimer?.cancel();
    _stopSound();

    final bookingId = widget.bookingData['booking_id']?.toString() ?? '';
    try {
      await ApiClient.post('/provider/bookings/$bookingId/accept', {});
      ApiClient.patch('/provider/availability', {'is_available': false})
          .catchError((_) => <String, dynamic>{});

      if (!mounted) return;
      Navigator.of(context).pop(true);

      // ── Auto-open navigation map immediately after accept ─────────────────
      // patient_lat / patient_lng are included in the WS booking payload.
      final patLat = double.tryParse(
          widget.bookingData['patient_lat']?.toString() ?? '');
      final patLng = double.tryParse(
          widget.bookingData['patient_lng']?.toString() ?? '');

      if (patLat != null && patLng != null && patLat != 0 && patLng != 0) {
        final booking = ProviderBooking(
          id: bookingId,
          serviceName:
              widget.bookingData['service_name']?.toString() ?? 'Service',
          status: 'ACCEPTED',
          scheduledAt: '',
          customerName: '',
          address: widget.bookingData['address']?.toString() ?? '',
          totalAmount:
              (widget.bookingData['amount'] as num?)?.toDouble() ?? 0,
          customerPhone: '',
          notes: widget.bookingData['notes']?.toString() ?? '',
          customerLat: patLat,
          customerLng: patLng,
        );
        Get.to(() => BookingMapScreen(booking: booking),
            transition: Transition.downToUp);
      } else {
        Get.snackbar(
          'Booking Accepted!',
          'Head to ${widget.bookingData['address'] ?? 'the customer location'}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade700,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _startCountdown();
      _startSound();
      Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _reject() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _countdownTimer?.cancel();
    _stopSound();

    final bookingId = widget.bookingData['booking_id']?.toString() ?? '';
    try {
      await ApiClient.post('/provider/bookings/$bookingId/reject', {});
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pop(false);
      Get.snackbar(
        'Booking Declined',
        'The request will be reassigned.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF374151),
        colorText: Colors.white,
      );
    }
  }

  Color get _timerColor {
    if (_remaining > 30) return const Color(0xFF16A34A);
    if (_remaining > 10) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final serviceName =
        widget.bookingData['service_name']?.toString() ?? 'Healthcare Service';
    final address =
        widget.bookingData['address']?.toString() ?? 'Address not provided';
    final amount = (widget.bookingData['amount'] ?? 0).toDouble();
    final notes = widget.bookingData['notes']?.toString() ?? '';

    return PopScope(
      canPop: false, // prevent back-button dismissal during alert
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Column(
            children: [
              // ── Top: Pulsing alert header ───────────────────────────────
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated incoming icon
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.8, end: 1.1),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeInOut,
                        builder: (_, scale, child) => Transform.scale(
                          scale: scale,
                          child: child,
                        ),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2),
                          ),
                          child: const Icon(
                            Icons.medical_services_rounded,
                            size: 52,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'New Booking Request',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        serviceName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Countdown ring
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: CircularProgressIndicator(
                              value: _remaining / widget.timeoutSeconds,
                              strokeWidth: 5,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.15),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(_timerColor),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$_remaining',
                                style: TextStyle(
                                  color: _timerColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Text(
                                'sec',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Middle: Booking details ─────────────────────────────────
              Expanded(
                flex: 2,
                child: Container(
                  color: const Color(0xFF1E293B),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(
                        icon: Icons.medical_services_outlined,
                        label: 'Service',
                        value: serviceName,
                        iconColor: const Color(0xFF60A5FA),
                      ),
                      const SizedBox(height: 14),
                      _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Address',
                        value: address,
                        iconColor: const Color(0xFF34D399),
                      ),
                      if (amount > 0) ...[
                        const SizedBox(height: 14),
                        _DetailRow(
                          icon: Icons.currency_rupee_rounded,
                          label: 'Amount',
                          value: '₹${amount.toStringAsFixed(0)}',
                          iconColor: const Color(0xFFFBBF24),
                        ),
                      ],
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _DetailRow(
                          icon: Icons.notes_rounded,
                          label: 'Notes',
                          value: notes,
                          iconColor: const Color(0xFFA78BFA),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Bottom: Action buttons ──────────────────────────────────
              Container(
                color: const Color(0xFF0F172A),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: _isProcessing
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF3B82F6)))
                    : Row(
                        children: [
                          // Reject
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _reject,
                              icon: const Icon(Icons.close_rounded, size: 20),
                              label: const Text('Decline',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side:
                                    const BorderSide(color: Color(0xFFEF4444)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Accept (pulsing)
                          Expanded(
                            flex: 2,
                            child: ScaleTransition(
                              scale: _pulseAnim,
                              child: ElevatedButton.icon(
                                onPressed: _accept,
                                icon: const Icon(Icons.check_rounded, size: 22),
                                label: const Text('Accept Booking',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  elevation: 6,
                                  shadowColor: const Color(0xFF16A34A),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
