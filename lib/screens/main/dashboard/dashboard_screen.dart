import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:home_care_admin/core/api_client.dart';
import 'package:home_care_admin/core/token_storage.dart';
import 'package:home_care_admin/models/provider_models.dart';
import 'package:home_care_admin/screens/main/bookings/booking_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ProviderProfile? _profile;
  ProviderEarnings? _earnings;
  List<ProviderBooking> _bookings = [];
  bool _isLoading = true;
  bool _isTogglingAvailability = false;
  String _providerName = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _providerName = await TokenStorage.getName() ?? 'Provider';
    try {
      final results = await Future.wait([
        ApiClient.get('/provider/profile').catchError((_) => <String, dynamic>{}),
        ApiClient.get('/provider/bookings').catchError((_) => <String, dynamic>{}),
        ApiClient.get('/provider/earnings').catchError((_) => <String, dynamic>{}),
      ]);

      final profileData = results[0];
      final bookingsData = results[1];
      final earningsData = results[2];

      // API wraps data in {"data": {...}} — unwrap before parsing
      final profileInner = profileData['data'] as Map<String, dynamic>? ?? profileData;
      if (profileInner.isNotEmpty) {
        _profile = ProviderProfile.fromJson(profileInner);
      }
      final bookingsList = bookingsData['data'] as List<dynamic>? ??
          bookingsData['bookings'] as List<dynamic>? ??
          [];
      _bookings = bookingsList
          .map((b) => ProviderBooking.fromJson(b as Map<String, dynamic>))
          .toList();
      final earningsInner = earningsData['data'] as Map<String, dynamic>? ?? earningsData;
      if (earningsInner.isNotEmpty) {
        _earnings = ProviderEarnings.fromJson(earningsInner);
      }
    } catch (e) {
      // Non-fatal; partial data is still shown
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAvailability() async {
    if (_profile == null) return;
    setState(() => _isTogglingAvailability = true);
    try {
      await ApiClient.patch('/provider/availability', {
        'is_available': !_profile!.isAvailable,
      });
      setState(() {
        _profile = ProviderProfile(
          id: _profile!.id,
          userId: _profile!.userId,
          name: _profile!.name,
          category: _profile!.category,
          approvalStatus: _profile!.approvalStatus,
          qualification: _profile!.qualification,
          serviceArea: _profile!.serviceArea,
          shiftAvailability: _profile!.shiftAvailability,
          hourlyRate: _profile!.hourlyRate,
          dailyRate: _profile!.dailyRate,
          rating: _profile!.rating,
          yearsOfExperience: _profile!.yearsOfExperience,
          totalReviews: _profile!.totalReviews,
          isAvailable: !_profile!.isAvailable,
          emergencyCapable: _profile!.emergencyCapable,
          imageUrl: _profile!.imageUrl,
          phone: _profile!.phone,
        );
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() => _isTogglingAvailability = false);
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  ProviderBooking? get _activeBooking {
    try {
      return _bookings.firstWhere((b) => b.isInProgress);
    } catch (_) {
      return null;
    }
  }

  List<ProviderBooking> get _recentBookings =>
      _bookings.take(5).toList();

  int get _todaysBookings {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _bookings.where((b) {
      if (b.scheduledAt.isEmpty) return false;
      try {
        final d = DateTime.parse(b.scheduledAt);
        return DateFormat('yyyy-MM-dd').format(d) == today;
      } catch (_) {
        return false;
      }
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF2563EB),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              backgroundColor: const Color(0xFF2563EB),
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E40AF), Color(0xFF2563EB), Color(0xFF3B82F6)],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_greeting,',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _profile?.name ?? _providerName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          _buildAvailabilityToggle(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatsRow(),
                      const SizedBox(height: 20),
                      if (_activeBooking != null) ...[
                        _buildActiveBookingCard(_activeBooking!),
                        const SizedBox(height: 20),
                      ],
                      _buildQuickActions(),
                      const SizedBox(height: 20),
                      _buildRecentBookings(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityToggle() {
    final isAvailable = _profile?.isAvailable ?? false;
    return GestureDetector(
      onTap: _isTogglingAvailability ? null : _toggleAvailability,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isAvailable
              ? const Color(0xFF16A34A)
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isAvailable
                ? const Color(0xFF16A34A)
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
        child: _isTogglingAvailability
            ? const SizedBox(
                width: 16,
                height: 16,
                child:
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isAvailable ? 'Online' : 'Offline',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: "Today's Bookings",
            value: '$_todaysBookings',
            icon: Icons.calendar_today_rounded,
            color: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Total Earned',
            value: '₹${_earnings?.totalEarned.toStringAsFixed(0) ?? '0'}',
            icon: Icons.currency_rupee_rounded,
            color: const Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Rating',
            value: _profile != null
                ? _profile!.rating.toStringAsFixed(1)
                : '--',
            icon: Icons.star_rounded,
            color: const Color(0xFFEAB308),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveBookingCard(ProviderBooking booking) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radio_button_checked,
                        color: Color(0xFF86EFAC), size: 12),
                    SizedBox(width: 4),
                    Text('Active Booking',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            booking.serviceName,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            booking.customerName,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: Colors.white60, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  booking.address.isEmpty ? 'Address not provided' : booking.address,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '₹${booking.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.toggle_on_rounded,
                label: 'Availability',
                color: const Color(0xFF2563EB),
                onTap: _toggleAvailability,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Earnings',
                color: const Color(0xFF16A34A),
                onTap: () {
                  // Navigate to earnings tab
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.support_agent_rounded,
                label: 'Support',
                color: const Color(0xFF7C3AED),
                onTap: _contactSupport,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _contactSupport() async {
    try {
      await ApiClient.post('/support', {
        'subject': 'Provider Support Request',
        'description': 'I need assistance with my provider account.',
        'category': 'GENERAL',
      });
      Get.snackbar(
        'Support Request Sent',
        'Our team will reach out to you shortly.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not send request. Try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Widget _buildRecentBookings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Bookings',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B)),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recentBookings.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 40, color: Color(0xFF94A3B8)),
                  SizedBox(height: 12),
                  Text(
                    'No bookings yet',
                    style: TextStyle(
                        color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'New bookings will appear here',
                    style:
                        TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          ...(_recentBookings.map((b) => _BookingListTile(booking: b))),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingListTile extends StatelessWidget {
  final ProviderBooking booking;

  const _BookingListTile({required this.booking});

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
      case 'REJECTED':
      case 'CANCELLED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'Not scheduled';
    try {
      final d = DateTime.parse(dateStr);
      return DateFormat('dd MMM, hh:mm a').format(d.toLocal());
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(() => BookingDetailScreen(booking: booking)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: _statusColor.withValues(alpha: 0.1),
            child: Text(
              booking.customerName.isNotEmpty
                  ? booking.customerName[0].toUpperCase()
                  : 'C',
              style: TextStyle(
                  color: _statusColor, fontWeight: FontWeight.w700),
            ),
          ),
          title: Text(
            booking.serviceName,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B)),
          ),
          subtitle: Text(
            _formatDate(booking.scheduledAt),
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  booking.status,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${booking.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1E293B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
