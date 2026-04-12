import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';
import '../models/models.dart';
import 'emergency_map_screen.dart';

class EmergenciesScreen extends StatefulWidget {
  const EmergenciesScreen({super.key});
  @override
  State<EmergenciesScreen> createState() => _EmergenciesScreenState();
}

class _EmergenciesScreenState extends State<EmergenciesScreen> {
  final ctrl = Get.find<AdminController>();

  @override
  void initState() {
    super.initState();
    ctrl.fetchEmergencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3F3),
      appBar: AppBar(
        title: const Text('Active Emergencies',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white),
            tooltip: 'Map View',
            onPressed: () => Get.to(() => const EmergencyMapScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: ctrl.fetchEmergencies,
          ),
        ],
      ),
      body: Obx(() {
        if (ctrl.loadingEmergencies.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (ctrl.emergencies.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64, color: Colors.green.shade400),
                const SizedBox(height: 12),
                const Text('No active emergencies',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: ctrl.fetchEmergencies,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ctrl.emergencies.length,
            itemBuilder: (_, i) =>
                _EmergencyCard(e: ctrl.emergencies[i], ctrl: ctrl),
          ),
        );
      }),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  final AdminEmergency e;
  final AdminController ctrl;
  const _EmergencyCard({required this.e, required this.ctrl});

  static const _flow = ['TRIGGERED', 'DISPATCHED', 'EN_ROUTE', 'ARRIVED', 'RESOLVED'];

  Color _priorityColor(String p) {
    switch (p) {
      case 'CRITICAL': return Colors.red;
      case 'HIGH': return Colors.orange;
      case 'MEDIUM': return Colors.amber.shade700;
      default: return Colors.grey;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'TRIGGERED': return Colors.red;
      case 'DISPATCHED': return Colors.orange;
      case 'EN_ROUTE': return Colors.blue;
      case 'ARRIVED': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final idx = _flow.indexOf(e.status);
    final hasNext = idx >= 0 && idx < _flow.length - 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _priorityColor(e.priority).withValues(alpha: 0.4), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.emergency, color: _priorityColor(e.priority)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(e.description ?? 'Emergency Alert',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              _PriorityBadge(priority: e.priority, color: _priorityColor(e.priority)),
            ]),
            if (e.address != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.location_on, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text(e.address!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(e.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(e.status, style: TextStyle(fontSize: 11, color: _statusColor(e.status), fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Text(e.createdAt.length > 16 ? e.createdAt.substring(0, 16).replaceAll('T', '  ') : e.createdAt,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
            if (hasNext) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => ctrl.updateEmergency(e.id, _flow[idx + 1]),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text('Mark as ${_flow[idx + 1]}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  final Color color;
  const _PriorityBadge({required this.priority, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Text(priority, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
      );
}
