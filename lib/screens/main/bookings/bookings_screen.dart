import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:home_care_admin/core/api_client.dart';
import 'package:home_care_admin/core/token_storage.dart';
import 'package:home_care_admin/models/provider_models.dart';
import 'package:home_care_admin/screens/main/bookings/booking_detail_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ProviderBooking> _allBookings = [];
  bool _isLoading = true;

  WebSocket? _ws;
  Timer? _wsPollTimer;
  bool _wsDisposed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookings();
    _connectWS();
    // Fallback: poll every 15 s when WebSocket is disconnected
    _wsPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_ws == null) _silentRefresh();
    });
  }

  @override
  void dispose() {
    _wsDisposed = true;
    _ws?.close();
    _wsPollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _connectWS() async {
    if (_wsDisposed) return;
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) return;
      final wsUrl = ApiClient.baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://')
          .replaceAll('/api', '');
      _ws = await WebSocket.connect('$wsUrl/api/ws?token=${Uri.encodeComponent(token)}')
          .timeout(const Duration(seconds: 10));
      if (_wsDisposed) { _ws?.close(); return; }
      _ws!.listen(
        _onWsMessage,
        onError: (_) { _ws = null; _scheduleWsReconnect(); },
        onDone: () { _ws = null; _scheduleWsReconnect(); },
        cancelOnError: false,
      );
    } catch (_) {
      _scheduleWsReconnect();
    }
  }

  void _scheduleWsReconnect() {
    if (_wsDisposed) return;
    Future.delayed(const Duration(seconds: 5), () {
      if (!_wsDisposed) _connectWS();
    });
  }

  void _onWsMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      if (msg['type'] == 'booking_status') {
        final payload = msg['payload'];
        final Map<String, dynamic> p = payload is String
            ? jsonDecode(payload) as Map<String, dynamic>
            : Map<String, dynamic>.from(payload as Map);
        final event = p['event'] as String? ?? '';
        final serviceName = p['service_name'] as String? ?? 'a service';
        if (event == 'NEW_BOOKING') {
          _silentRefresh();
          if (mounted) {
            Get.snackbar(
              '🔔 New Booking!',
              'New request for $serviceName — check your bookings tab.',
              snackPosition: SnackPosition.TOP,
              backgroundColor: const Color(0xFF2563EB),
              colorText: Colors.white,
              duration: const Duration(seconds: 5),
              icon: const Icon(Icons.notifications_active, color: Colors.white),
            );
            // Jump to New tab
            _tabController.animateTo(0);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _silentRefresh() async {
    try {
      final result = await ApiClient.get('/provider/bookings');
      final list = result['data'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _allBookings = list
              .map((b) => ProviderBooking.fromJson(b as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiClient.get('/provider/bookings');
      final list = result['data'] as List<dynamic>? ??
          result['bookings'] as List<dynamic>? ??
          [];
      setState(() {
        _allBookings = list
            .map((b) => ProviderBooking.fromJson(b as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<ProviderBooking> get _newRequests =>
      _allBookings.where((b) => b.isPending).toList();

  List<ProviderBooking> get _active => _allBookings
      .where((b) => b.isAccepted || b.isInProgress)
      .toList();

  List<ProviderBooking> get _completed =>
      _allBookings.where((b) => b.isCompleted || b.isRejected).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Bookings'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadBookings,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF2563EB),
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('New'),
                  if (_newRequests.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_newRequests.length}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Active'),
                  if (_active.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_active.length}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const Tab(text: 'Completed'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : TabBarView(
              controller: _tabController,
              children: [
                _BookingList(bookings: _newRequests, onRefresh: _loadBookings),
                _BookingList(bookings: _active, onRefresh: _loadBookings),
                _BookingList(bookings: _completed, onRefresh: _loadBookings),
              ],
            ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<ProviderBooking> bookings;
  final VoidCallback onRefresh;

  const _BookingList({required this.bookings, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'No bookings here',
              style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                  fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: const Color(0xFF2563EB),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return BookingCard(
            booking: bookings[index],
            onTap: () async {
              await Get.to(() => BookingDetailScreen(booking: bookings[index]));
              onRefresh();
            },
          );
        },
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  final ProviderBooking booking;
  final VoidCallback onTap;

  const BookingCard({super.key, required this.booking, required this.onTap});

  Color get _statusColor {
    switch (booking.status) {
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
      return DateFormat('EEE, dd MMM • hh:mm a').format(d.toLocal());
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.06),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      booking.serviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      booking.status,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row(Icons.person_outline, booking.customerName.isEmpty ? 'Customer' : booking.customerName),
                  const SizedBox(height: 6),
                  _row(Icons.location_on_outlined,
                      booking.address.isEmpty ? 'Address not provided' : booking.address),
                  const SizedBox(height: 6),
                  _row(Icons.schedule_outlined, _formatDate(booking.scheduledAt)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${booking.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('View Details',
                                style: TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 10, color: Color(0xFF2563EB)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF374151)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
