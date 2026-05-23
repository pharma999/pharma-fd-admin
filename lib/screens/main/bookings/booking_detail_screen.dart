import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:home_care_admin/core/api_client.dart';
import 'package:home_care_admin/models/provider_models.dart';
import 'package:home_care_admin/screens/main/bookings/booking_map_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final ProviderBooking booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  bool _isLoading = false;
  final _otpInputController = TextEditingController();
  final _rejectReasonController = TextEditingController();
  Timer? _locationTimer;

  late ProviderBooking _booking;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    if (_booking.status == 'IN_PROGRESS') {
      _startLocationUpdates();
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _otpInputController.dispose();
    _rejectReasonController.dispose();
    super.dispose();
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _sendLocation();
    });
  }

  Future<void> _sendLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      await ApiClient.patch('/provider/location', {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'booking_id': _booking.id,
      });
    } catch (_) {}
  }

  Future<void> _accept() async {
    setState(() => _isLoading = true);
    try {
      await ApiClient.post('/provider/bookings/${_booking.id}/accept', {});
      // Mark provider as busy while serving this booking
      ApiClient.patch('/provider/availability', {'is_available': false}).catchError((_) => <String, dynamic>{});
      final accepted = ProviderBooking(
        id: _booking.id,
        serviceName: _booking.serviceName,
        status: 'ACCEPTED',
        scheduledAt: _booking.scheduledAt,
        customerName: _booking.customerName,
        address: _booking.address,
        totalAmount: _booking.totalAmount,
        customerPhone: _booking.customerPhone,
        notes: _booking.notes,
        customerLat: _booking.customerLat,
        customerLng: _booking.customerLng,
      );
      setState(() => _booking = accepted);
      Get.snackbar('Accepted', 'Booking accepted successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade900);
      if (accepted.hasLocation && mounted) {
        Get.to(() => BookingMapScreen(booking: accepted));
      }
    } catch (e) {
      Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: _rejectReasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, _rejectReasonController.text.trim()),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626)),
              child: const Text('Reject')),
        ],
      ),
    );

    if (reason == null) return;

    setState(() => _isLoading = true);
    try {
      await ApiClient.post(
          '/provider/bookings/${_booking.id}/reject', {'reason': reason});
      setState(() => _booking = ProviderBooking(
            id: _booking.id,
            serviceName: _booking.serviceName,
            status: 'REJECTED',
            scheduledAt: _booking.scheduledAt,
            customerName: _booking.customerName,
            address: _booking.address,
            totalAmount: _booking.totalAmount,
            customerPhone: _booking.customerPhone,
            notes: _booking.notes,
          ));
      Get.snackbar('Rejected', 'Booking rejected',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateOtp() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiClient.post(
          '/provider/bookings/${_booking.id}/generate-otp', {});
      // Backend wraps the OTP inside result['data']
      final dataMap = result['data'] as Map<String, dynamic>? ?? result;
      final otp = dataMap['otp'] as String? ??
          dataMap['verification_otp'] as String? ??
          result['otp'] as String? ??
          '';
      if (otp.isEmpty && mounted) {
        Get.snackbar('OTP Error',
            'Could not generate OTP. Please try again.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade100,
            colorText: Colors.red.shade900);
        return;
      }
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Service OTP'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Share this OTP with the customer to start the service:'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFF2563EB), width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        otp,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2563EB),
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: otp));
                          Get.snackbar('Copied', 'OTP copied to clipboard',
                              snackPosition: SnackPosition.BOTTOM);
                        },
                        icon: const Icon(Icons.copy_rounded),
                        color: const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startService() async {
    final otp = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the OTP provided by the customer:'),
            const SizedBox(height: 12),
            TextField(
              controller: _otpInputController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, _otpInputController.text.trim()),
              child: const Text('Start')),
        ],
      ),
    );

    if (otp == null || otp.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ApiClient.post(
          '/provider/bookings/${_booking.id}/start', {'otp': otp});
      setState(() => _booking = ProviderBooking(
            id: _booking.id,
            serviceName: _booking.serviceName,
            status: 'IN_PROGRESS',
            scheduledAt: _booking.scheduledAt,
            customerName: _booking.customerName,
            address: _booking.address,
            totalAmount: _booking.totalAmount,
            customerPhone: _booking.customerPhone,
            notes: _booking.notes,
          ));
      _startLocationUpdates();
      Get.snackbar('Service Started', 'Service is now in progress',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade900);
    } catch (e) {
      Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _complete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Service'),
        content: const Text(
            'Are you sure you want to mark this service as completed?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A)),
              child: const Text('Complete')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await ApiClient.post(
          '/provider/bookings/${_booking.id}/complete', {});
      _locationTimer?.cancel();
      // Mark provider as active/available again after completing the booking
      ApiClient.patch('/provider/availability', {'is_available': true}).catchError((_) => <String, dynamic>{});
      setState(() => _booking = ProviderBooking(
            id: _booking.id,
            serviceName: _booking.serviceName,
            status: 'COMPLETED',
            scheduledAt: _booking.scheduledAt,
            customerName: _booking.customerName,
            address: _booking.address,
            totalAmount: _booking.totalAmount,
            customerPhone: _booking.customerPhone,
            notes: _booking.notes,
          ));
      Get.snackbar('Completed', 'Service completed successfully! You are now active.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade900);
    } catch (e) {
      Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color get _statusColor {
    switch (_booking.status) {
      case 'PENDING':
        return const Color(0xFFEAB308);
      case 'ACCEPTED':
        return const Color(0xFF2563EB);
      case 'IN_PROGRESS':
        return const Color(0xFF7C3AED);
      case 'COMPLETED':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFFDC2626);
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'Not scheduled';
    try {
      final d = DateTime.parse(dateStr);
      return DateFormat('EEE, dd MMM yyyy • hh:mm a').format(d.toLocal());
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Booking Details')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildStatusBanner(),
                  const SizedBox(height: 16),
                  _buildDetailsCard(),
                  const SizedBox(height: 16),
                  _buildCustomerCard(),
                  const SizedBox(height: 24),
                  _buildActions(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_statusIcon, color: _statusColor, size: 28),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _booking.status.replaceAll('_', ' '),
                style: TextStyle(
                  color: _statusColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(
                _statusDescription,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData get _statusIcon {
    switch (_booking.status) {
      case 'PENDING':
        return Icons.hourglass_top_rounded;
      case 'ACCEPTED':
        return Icons.check_circle_outline_rounded;
      case 'IN_PROGRESS':
        return Icons.play_circle_outline_rounded;
      case 'COMPLETED':
        return Icons.verified_rounded;
      default:
        return Icons.cancel_outlined;
    }
  }

  String get _statusDescription {
    switch (_booking.status) {
      case 'PENDING':
        return 'Awaiting your response';
      case 'ACCEPTED':
        return 'Generate OTP to start service';
      case 'IN_PROGRESS':
        return 'Service is currently ongoing';
      case 'COMPLETED':
        return 'Service completed successfully';
      default:
        return 'Booking was rejected/cancelled';
    }
  }

  Widget _buildDetailsCard() {
    return _card('Service Details', [
      _detailRow(Icons.medical_services_outlined, 'Service', _booking.serviceName),
      _detailRow(Icons.schedule_outlined, 'Scheduled', _formatDate(_booking.scheduledAt)),
      _detailRow(Icons.currency_rupee_rounded, 'Amount',
          '₹${_booking.totalAmount.toStringAsFixed(2)}'),
      if (_booking.notes.isNotEmpty)
        _detailRow(Icons.notes_rounded, 'Notes', _booking.notes),
    ]);
  }

  Widget _buildCustomerCard() {
    return _card('Customer Information', [
      _detailRow(Icons.person_outline_rounded, 'Name',
          _booking.customerName.isEmpty ? 'Not provided' : _booking.customerName),
      _detailRow(Icons.phone_outlined, 'Phone',
          _booking.customerPhone.isEmpty ? 'Not provided' : _booking.customerPhone),
      _detailRow(Icons.location_on_outlined, 'Address',
          _booking.address.isEmpty ? 'Not provided' : _booking.address),
    ]);
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF1E293B))),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    if (_booking.isPending) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _reject,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Reject',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFDC2626)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _accept,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Accept Booking',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      );
    }

    if (_booking.isAccepted) {
      return Column(
        children: [
          if (_booking.hasLocation) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Get.to(() => BookingMapScreen(booking: _booking)),
                icon: const Icon(Icons.navigation_rounded),
                label: const Text('Navigate to Customer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generateOtp,
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Generate Service OTP',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startService,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Service with OTP',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
              ),
            ),
          ),
        ],
      );
    }

    if (_booking.isInProgress) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _complete,
          icon: const Icon(Icons.check_circle_rounded),
          label: const Text('Complete Service',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
