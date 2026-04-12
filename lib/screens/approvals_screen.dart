import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';
import '../models/models.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final ctrl = Get.find<AdminController>();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    ctrl.fetchApprovals();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1A237E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Doctors'),
            Tab(text: 'Nurses'),
            Tab(text: 'Hospitals'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Obx(() => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['PENDING', 'APPROVED', 'REJECTED']
                        .map((f) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(f),
                                selected: ctrl.approvalFilter.value == f,
                                onSelected: (_) {
                                  ctrl.approvalFilter.value = f;
                                  ctrl.fetchApprovals(filter: f);
                                },
                              ),
                            ))
                        .toList(),
                  ),
                )),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _DoctorList(ctrl: ctrl),
                _NurseList(ctrl: ctrl),
                _HospitalList(ctrl: ctrl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Doctor list ────────────────────────────────────────────────────────────

class _DoctorList extends StatelessWidget {
  final AdminController ctrl;
  const _DoctorList({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.loadingApprovals.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (ctrl.doctors.isEmpty) {
        return const Center(child: Text('No doctors'));
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ctrl.doctors.length,
        itemBuilder: (_, i) {
          final d = ctrl.doctors[i];
          return _ApprovalTile(
            title: d.name,
            sub1: '${d.specialty} • ${d.experience} yrs',
            sub2: '₹${d.consultationFee.toInt()} / consult',
            rating: d.rating,
            status: d.approvalStatus,
            onApprove: () => ctrl.approveDoctor(d.id, 'APPROVED'),
            onReject: () => ctrl.approveDoctor(d.id, 'REJECTED'),
          );
        },
      );
    });
  }
}

// ── Nurse list ─────────────────────────────────────────────────────────────

class _NurseList extends StatelessWidget {
  final AdminController ctrl;
  const _NurseList({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.loadingApprovals.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (ctrl.nurses.isEmpty) {
        return const Center(child: Text('No nurses'));
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ctrl.nurses.length,
        itemBuilder: (_, i) {
          final n = ctrl.nurses[i];
          return _ApprovalTile(
            title: n.name,
            sub1: '${n.category} • ${n.experience} yrs',
            sub2: '₹${n.hourlyRate.toInt()}/hr',
            rating: n.rating,
            status: n.approvalStatus,
            onApprove: () => ctrl.approveNurse(n.id, 'APPROVED'),
            onReject: () => ctrl.approveNurse(n.id, 'REJECTED'),
          );
        },
      );
    });
  }
}

// ── Hospital list ──────────────────────────────────────────────────────────

class _HospitalList extends StatelessWidget {
  final AdminController ctrl;
  const _HospitalList({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.loadingApprovals.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (ctrl.hospitals.isEmpty) {
        return const Center(child: Text('No hospitals'));
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ctrl.hospitals.length,
        itemBuilder: (_, i) {
          final h = ctrl.hospitals[i];
          return _ApprovalTile(
            title: h['name'] ?? 'Hospital',
            sub1: h['city'] ?? '',
            sub2: 'Reg: ${h['registration_number'] ?? '—'}',
            rating: 0,
            status: h['approval_status'] ?? 'PENDING',
            onApprove: () =>
                ctrl.approveHospital(h['id'] ?? '', 'APPROVED'),
            onReject: () =>
                ctrl.approveHospital(h['id'] ?? '', 'REJECTED'),
          );
        },
      );
    });
  }
}

// ── Shared tile ────────────────────────────────────────────────────────────

class _ApprovalTile extends StatelessWidget {
  final String title, sub1, sub2, status;
  final double rating;
  final VoidCallback onApprove, onReject;

  const _ApprovalTile({
    required this.title,
    required this.sub1,
    required this.sub2,
    required this.rating,
    required this.status,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'PENDING';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15))),
              if (rating > 0)
                Row(children: [
                  const Icon(Icons.star, color: Colors.amber, size: 15),
                  Text(rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 13)),
                ]),
            ]),
            const SizedBox(height: 4),
            Text(sub1,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13)),
            Text(sub2,
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 12)),
            const SizedBox(height: 4),
            _StatusBadge(status: status),
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red)),
                    child: const Text('Reject',
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green),
                    child: const Text('Approve'),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 11, color: _color, fontWeight: FontWeight.bold)),
    );
  }
}
