import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:home_care_admin/core/api_client.dart';
import 'package:home_care_admin/core/token_storage.dart';
import 'package:home_care_admin/models/provider_models.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProviderProfile? _profile;
  bool _isLoading = true;
  bool _isTogglingAvailability = false;
  String _providerName = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    _providerName = await TokenStorage.getName() ?? 'Provider';
    try {
      // GET /nurses/me returns {"status":200, "data": {NurseResponse}}
      final res = await ApiClient.get('/nurses/me');
      final raw = res['data'] as Map<String, dynamic>? ?? res;
      if (raw.isNotEmpty) {
        // nurse_id is the ID field in NurseResponse
        final merged = <String, dynamic>{
          ...raw,
          'id': raw['nurse_id'] ?? raw['id'] ?? raw['_id'] ?? '',
        };
        setState(() => _profile = ProviderProfile.fromJson(merged));
      }
    } catch (_) {
      // Use stored name as fallback
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
      Get.snackbar(
        'Availability Updated',
        _profile!.isAvailable ? 'You are now online' : 'You are now offline',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
      );
    } catch (e) {
      Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => _isTogglingAvailability = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await TokenStorage.clearAll();
      Get.offAllNamed('/phone');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : RefreshIndicator(
              onRefresh: _loadProfile,
              color: const Color(0xFF2563EB),
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 260,
                    floating: false,
                    pinned: true,
                    automaticallyImplyLeading: false,
                    backgroundColor: const Color(0xFF2563EB),
                    title: const Text('My Profile',
                        style: TextStyle(color: Colors.white)),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1E40AF),
                              Color(0xFF2563EB),
                              Color(0xFF3B82F6)
                            ],
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),
                              Stack(
                                children: [
                                  Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 3),
                                    ),
                                    child: const Icon(
                                      Icons.person_rounded,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 2,
                                    right: 2,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: _profile?.isAvailable == true
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFF64748B),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white,
                                            width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _profile?.name ?? _providerName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _profile?.category.replaceAll('_', ' ') ??
                                    'Provider',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_profile != null)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    RatingBarIndicator(
                                      rating: _profile!.rating,
                                      itemBuilder: (context, _) =>
                                          const Icon(Icons.star_rounded,
                                              color: Color(0xFFEAB308)),
                                      itemCount: 5,
                                      itemSize: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_profile!.rating.toStringAsFixed(1)} (${_profile!.totalReviews} reviews)',
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 8),
                              _buildStatusBadge(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAvailabilityCard(),
                          const SizedBox(height: 16),
                          if (_profile != null) ...[
                            _buildProfileDetails(),
                            const SizedBox(height: 16),
                          ],
                          _buildMenuSection('Account', [
                            _MenuItem(
                              icon: Icons.upload_file_rounded,
                              label: 'My Documents',
                              color: const Color(0xFF2563EB),
                              onTap: () => Get.toNamed('/doc-upload'),
                            ),
                            _MenuItem(
                              icon: Icons.notifications_outlined,
                              label: 'Notifications',
                              color: const Color(0xFFEAB308),
                              onTap: () => _viewNotifications(),
                            ),
                            _MenuItem(
                              icon: Icons.support_agent_rounded,
                              label: 'Contact Support',
                              color: const Color(0xFF7C3AED),
                              onTap: _contactSupport,
                            ),
                          ]),
                          const SizedBox(height: 16),
                          _buildMenuSection('Legal', [
                            _MenuItem(
                              icon: Icons.privacy_tip_outlined,
                              label: 'Privacy Policy',
                              color: const Color(0xFF64748B),
                              onTap: () {},
                            ),
                            _MenuItem(
                              icon: Icons.article_outlined,
                              label: 'Terms of Service',
                              color: const Color(0xFF64748B),
                              onTap: () {},
                            ),
                          ]),
                          const SizedBox(height: 16),
                          _buildLogoutButton(),
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusBadge() {
    final status = _profile?.approvalStatus ?? 'PENDING';
    Color color;
    IconData icon;
    switch (status) {
      case 'APPROVED':
        color = const Color(0xFF16A34A);
        icon = Icons.verified_rounded;
        break;
      case 'REJECTED':
        color = const Color(0xFFDC2626);
        icon = Icons.cancel_rounded;
        break;
      default:
        color = const Color(0xFFEAB308);
        icon = Icons.hourglass_top_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            status,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard() {
    final isAvailable = _profile?.isAvailable ?? false;
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
      child: SwitchListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isAvailable
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.toggle_on_rounded,
            color: isAvailable
                ? const Color(0xFF16A34A)
                : const Color(0xFF94A3B8),
            size: 22,
          ),
        ),
        title: const Text('Availability Status',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          isAvailable
              ? 'You are currently visible to customers'
              : 'You are currently hidden from customers',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        value: isAvailable,
        activeThumbColor: const Color(0xFF16A34A),
        onChanged: _isTogglingAvailability
            ? null
            : (_) => _toggleAvailability(),
      ),
    );
  }

  Widget _buildProfileDetails() {
    final p = _profile!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text('Professional Info',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF1E293B))),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _profileRow('Qualification', p.qualification),
          _profileRow('Experience', '${p.yearsOfExperience} years'),
          _profileRow('Shift', p.shiftAvailability),
          _profileRow('Hourly Rate', '₹${p.hourlyRate.toStringAsFixed(0)}/hr'),
          _profileRow('Service Area', p.serviceArea),
          _profileRow('Emergency Capable', p.emergencyCapable ? 'Yes' : 'No'),
        ],
      ),
    );
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF64748B))),
          ),
          Expanded(
            flex: 3,
            child: Text(value.isEmpty ? 'Not set' : value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B))),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title, List<_MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B))),
        ),
        Container(
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
            children: items.asMap().entries.map((entry) {
              final item = entry.value;
              final isLast = entry.key == items.length - 1;
              return Column(
                children: [
                  ListTile(
                    onTap: item.onTap,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                    title: Text(item.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Color(0xFF1E293B))),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                  ),
                  if (!isLast)
                    const Divider(
                        height: 1,
                        indent: 56,
                        endIndent: 16,
                        color: Color(0xFFF1F5F9)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Logout',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          side: const BorderSide(color: Color(0xFFFCA5A5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _viewNotifications() async {
    try {
      final result = await ApiClient.get('/notifications');
      final list = result['notifications'] as List<dynamic>? ??
          result['data'] as List<dynamic>? ??
          [];
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, scrollCtrl) => Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text('Notifications',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 18)),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(
                        child: Text('No notifications',
                            style: TextStyle(color: Color(0xFF64748B))))
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final n = list[i] as Map<String, dynamic>;
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFEFF6FF),
                              child: Icon(Icons.notifications_outlined,
                                  color: Color(0xFF2563EB), size: 20),
                            ),
                            title: Text(n['title'] as String? ?? ''),
                            subtitle: Text(n['body'] as String? ??
                                n['message'] as String? ??
                                ''),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      Get.snackbar('Error', 'Could not load notifications',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _contactSupport() async {
    final controller = TextEditingController();
    final msg = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contact Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Describe your issue and we\'ll get back to you:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type your message...',
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
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Send')),
        ],
      ),
    );

    if (msg == null || msg.isEmpty) return;

    try {
      await ApiClient.post('/support', {
        'subject': 'Provider Support Request',
        'description': msg,
        'category': 'GENERAL',
      });
      Get.snackbar(
        'Request Sent',
        'Our team will reach out to you shortly.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
      );
    } catch (e) {
      Get.snackbar('Error', 'Could not send request. Try again.',
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
