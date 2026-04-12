import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';
import '../models/models.dart';

class ZonesScreen extends StatefulWidget {
  const ZonesScreen({super.key});
  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  final ctrl = Get.find<AdminController>();

  @override
  void initState() {
    super.initState();
    ctrl.fetchZones();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Zones',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1565C0),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _createDialog(context),
          ),
        ],
      ),
      body: Obx(() {
        if (ctrl.loadingZones.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (ctrl.zones.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('No service zones yet'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _createDialog(context),
                  child: const Text('Add Zone'),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ctrl.zones.length,
          itemBuilder: (_, i) => _ZoneCard(zone: ctrl.zones[i], ctrl: ctrl),
        );
      }),
    );
  }

  void _createDialog(BuildContext ctx) {
    final nameC = TextEditingController();
    final cityC = TextEditingController();
    final stateC = TextEditingController();
    final pinsC = TextEditingController();

    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Add Service Zone'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(nameC, 'Zone Name'),
              _field(cityC, 'City'),
              _field(stateC, 'State'),
              _field(pinsC, 'Pin Codes (comma separated)'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final pins = pinsC.text
                  .split(',')
                  .map((p) => p.trim())
                  .where((p) => p.isNotEmpty)
                  .toList();
              ctrl.createZone({
                'name': nameC.text,
                'city': cityC.text,
                'state': stateC.text,
                'pin_codes': pins,
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );
}

class _ZoneCard extends StatelessWidget {
  final AdminZone zone;
  final AdminController ctrl;
  const _ZoneCard({required this.zone, required this.ctrl});

  Color _statusColor(String s) {
    switch (s) {
      case 'ACTIVE': return Colors.green;
      case 'INACTIVE': return Colors.grey;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.location_city, color: Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(zone.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(zone.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(zone.status,
                    style: TextStyle(
                        fontSize: 11,
                        color: _statusColor(zone.status),
                        fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('${zone.city}, ${zone.state}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            if (zone.pinCodes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: zone.pinCodes
                    .map((p) => Chip(
                          label: Text(p, style: const TextStyle(fontSize: 11)),
                          backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.08),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            Row(children: [
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => ctrl.deleteZone(zone.id),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
