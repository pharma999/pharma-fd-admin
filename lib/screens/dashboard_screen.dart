import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        title: Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Admin Dashboard',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                Text('Welcome, ${ctrl.adminName.value}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ],
            )),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: ctrl.fetchAnalytics,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _confirmLogout(context, ctrl),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: ctrl.fetchAnalytics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Platform Overview'),
              const SizedBox(height: 12),
              Obx(() {
                if (ctrl.loadingAnalytics.value) {
                  return const Center(
                      child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ));
                }
                final a = ctrl.analytics.value;
                if (a == null) {
                  return const Center(child: Text('No data'));
                }
                return Column(
                  children: [
                    _statsRow(
                      _StatData('Users', a.totalUsers, Icons.people, Colors.blue),
                      _StatData('Revenue',
                          '₹${(a.totalRevenue / 1000).toStringAsFixed(1)}K',
                          Icons.currency_rupee, Colors.green),
                    ),
                    const SizedBox(height: 12),
                    _statsRow(
                      _StatData('Doctors', a.totalDoctors,
                          Icons.medical_services, Colors.purple),
                      _StatData('Nurses', a.totalNurses,
                          Icons.local_hospital, Colors.teal),
                    ),
                    const SizedBox(height: 12),
                    _statsRow(
                      _StatData('Hospitals', a.totalHospitals,
                          Icons.business, Colors.orange),
                      _StatData('Bookings', a.totalBookings,
                          Icons.bookmark, Colors.indigo),
                    ),
                    const SizedBox(height: 12),
                    _statsRow(
                      _StatData('Appointments', a.totalAppointments,
                          Icons.calendar_today, Colors.cyan),
                      _StatData('Active SOS', a.activeEmergencies,
                          Icons.emergency, Colors.red,
                          highlight: a.activeEmergencies > 0),
                    ),
                    const SizedBox(height: 12),
                    _statsRow(
                      _StatData('Pending Approvals', a.pendingApprovals,
                          Icons.pending_actions, Colors.amber,
                          highlight: a.pendingApprovals > 0),
                      _StatData('Open Tickets', a.openTickets,
                          Icons.support_agent, Colors.deepOrange,
                          highlight: a.openTickets > 0),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 28),
              _sectionTitle('Manage'),
              const SizedBox(height: 12),
              _menuGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A237E)));

  Widget _statsRow(_StatData a, _StatData b) => Row(
        children: [_statCard(a), const SizedBox(width: 12), _statCard(b)],
      );

  Widget _statCard(_StatData d) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: d.highlight ? Colors.red.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: d.highlight
                ? Border.all(color: Colors.red.shade300, width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: d.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(d.icon, color: d.color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(d.value.toString(),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              Text(d.label,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
      );

  Widget _menuGrid(BuildContext ctx) {
    final items = [
      _MenuItem('Pending Approvals', Icons.pending_actions,
          const Color(0xFF5C6BC0), '/approvals'),
      _MenuItem('User Management', Icons.manage_accounts,
          const Color(0xFF26A69A), '/users'),
      _MenuItem('All Bookings', Icons.bookmark_added,
          const Color(0xFFEF6C00), '/bookings'),
      _MenuItem('Active Emergencies', Icons.emergency,
          const Color(0xFFE53935), '/emergencies'),
      _MenuItem('Support Tickets', Icons.support_agent,
          const Color(0xFF7B1FA2), '/tickets'),
      _MenuItem('Subscription Plans', Icons.card_membership,
          const Color(0xFF00897B), '/plans'),
      _MenuItem('Service Zones', Icons.map, const Color(0xFF1565C0),
          '/zones'),
      _MenuItem('Appointments', Icons.calendar_today,
          const Color(0xFF00838F), '/appointments'),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.0,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12),
      itemCount: items.length,
      itemBuilder: (_, i) => _menuTile(items[i]),
    );
  }

  Widget _menuTile(_MenuItem m) => GestureDetector(
        onTap: () => Get.toNamed(m.route),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6)
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(m.icon, color: m.color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(m.label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 2),
              ),
            ],
          ),
        ),
      );

  void _confirmLogout(BuildContext ctx, AdminController ctrl) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ctrl.logout();
              },
              child: const Text('Logout')),
        ],
      ),
    );
  }
}

class _StatData {
  final String label;
  final dynamic value;
  final IconData icon;
  final Color color;
  final bool highlight;
  const _StatData(this.label, this.value, this.icon, this.color,
      {this.highlight = false});
}

class _MenuItem {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  const _MenuItem(this.label, this.icon, this.color, this.route);
}
