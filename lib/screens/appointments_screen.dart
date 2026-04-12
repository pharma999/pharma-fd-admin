import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';
import '../models/models.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});
  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final ctrl = Get.find<AdminController>();
  String _filter = '';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    ctrl.fetchAppointments();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminAppointment> get _filtered {
    var list = ctrl.appointments.toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((a) =>
              a.id.toLowerCase().contains(q) ||
              a.appointmentType.toLowerCase().contains(q) ||
              a.patientUserId.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF00838F),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: ctrl.fetchAppointments,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search by patient ID, type or appointment ID…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          // Status filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  '',
                  'PENDING',
                  'CONFIRMED',
                  'IN_PROGRESS',
                  'COMPLETED',
                  'CANCELLED'
                ]
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s.isEmpty ? 'All' : s,
                                style: const TextStyle(fontSize: 12)),
                            selected: _filter == s,
                            selectedColor:
                                const Color(0xFF00838F).withValues(alpha: 0.15),
                            onSelected: (_) {
                              setState(() => _filter = s);
                              ctrl.fetchAppointments(
                                  status: s.isEmpty ? null : s);
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              if (ctrl.loadingAppointments.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = _filtered;
              if (list.isEmpty) {
                return _EmptyState(
                  icon: Icons.calendar_today_outlined,
                  title: _searchQuery.isNotEmpty
                      ? 'No appointments match "$_searchQuery"'
                      : _filter.isNotEmpty
                          ? 'No $_filter appointments'
                          : 'No appointments yet',
                  subtitle: 'Appointments will appear here once booked',
                );
              }
              return RefreshIndicator(
                onRefresh: ctrl.fetchAppointments,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _AppointmentTile(a: list[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  final AdminAppointment a;
  const _AppointmentTile({required this.a});

  Color _statusColor(String s) {
    switch (s) {
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _typeColor(String t) {
    switch (t.toUpperCase()) {
      case 'HOME_VISIT':
        return Colors.teal;
      case 'ONLINE':
        return Colors.indigo;
      case 'CLINIC':
        return Colors.purple;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = a.scheduledAt.length >= 10
        ? a.scheduledAt.substring(0, 10)
        : a.scheduledAt;
    final timeStr = a.scheduledAt.length >= 16
        ? a.scheduledAt.substring(11, 16)
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _typeColor(a.appointmentType)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          a.appointmentType.replaceAll('_', ' '),
                          style: TextStyle(
                              fontSize: 11,
                              color: _typeColor(a.appointmentType),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      '$dateStr${timeStr.isNotEmpty ? ' • $timeStr' : ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(a.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(a.status,
                    style: TextStyle(
                        fontSize: 11,
                        color: _statusColor(a.status),
                        fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(children: [
              _InfoChip(
                icon: Icons.currency_rupee,
                label: a.totalAmount.toStringAsFixed(0),
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.payment,
                label: a.paymentStatus,
                color: a.paymentStatus == 'PAID'
                    ? Colors.green
                    : Colors.orange,
              ),
              const Spacer(),
              Text(
                'ID: ${a.id.length > 8 ? a.id.substring(0, 8) : a.id}…',
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade400),
              ),
            ]),
            if (a.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Note: ${a.notes}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}
