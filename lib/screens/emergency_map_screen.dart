import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../controllers/admin_controller.dart';
import '../models/models.dart';

/// Displays all active emergencies on a Google Map.
/// Tapping a marker shows the emergency details + status controls.
class EmergencyMapScreen extends StatefulWidget {
  const EmergencyMapScreen({super.key});

  @override
  State<EmergencyMapScreen> createState() => _EmergencyMapScreenState();
}

class _EmergencyMapScreenState extends State<EmergencyMapScreen> {
  final ctrl = Get.find<AdminController>();
  final Completer<GoogleMapController> _mapController = Completer();

  // Default centre: Lucknow, India
  static const _defaultLatLng = LatLng(26.8467, 80.9462);

  Map<MarkerId, Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await ctrl.fetchEmergencies();
    _buildMarkers();
  }

  void _buildMarkers() {
    final Map<MarkerId, Marker> built = {};
    for (final e in ctrl.emergencies) {
      if (!e.hasLocation) continue;
      final id = MarkerId(e.id);
      built[id] = Marker(
        markerId: id,
        position: LatLng(e.latitude!, e.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(_priorityHue(e.priority)),
        infoWindow: InfoWindow(
          title: e.emergencyType ?? 'Emergency',
          snippet: e.description ?? e.address ?? e.status,
          onTap: () => _showDetails(e),
        ),
      );
    }
    if (mounted) setState(() => _markers = built);

    // Auto-zoom to fit all markers
    if (built.isNotEmpty) {
      _fitBounds(built.values.map((m) => m.position).toList());
    }
  }

  Future<void> _fitBounds(List<LatLng> points) async {
    if (points.isEmpty) return;
    final ctrl = await _mapController.future;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    ctrl.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat - 0.05, minLng - 0.05),
        northeast: LatLng(maxLat + 0.05, maxLng + 0.05),
      ),
      60,
    ));
  }

  double _priorityHue(String p) {
    switch (p) {
      case 'CRITICAL':
        return BitmapDescriptor.hueRed;
      case 'HIGH':
        return BitmapDescriptor.hueOrange;
      case 'MEDIUM':
        return BitmapDescriptor.hueYellow;
      default:
        return BitmapDescriptor.hueGreen;
    }
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'CRITICAL':
        return Colors.red;
      case 'HIGH':
        return Colors.orange;
      case 'MEDIUM':
        return Colors.amber.shade700;
      default:
        return Colors.grey;
    }
  }

  void _showDetails(AdminEmergency e) {
    const flow = ['TRIGGERED', 'DISPATCHED', 'EN_ROUTE', 'ARRIVED', 'RESOLVED'];
    final idx = flow.indexOf(e.status);
    final hasNext = idx >= 0 && idx < flow.length - 1;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.emergency, color: _priorityColor(e.priority), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(e.emergencyType ?? 'Emergency Alert',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _priorityColor(e.priority),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(e.priority,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 10),
            if (e.patientName != null)
              _row(Icons.person, e.patientName!),
            if (e.description != null)
              _row(Icons.description, e.description!),
            if (e.address != null)
              _row(Icons.location_on, e.address!),
            _row(Icons.circle_notifications,
                'Status: ${e.status}'),
            _row(Icons.access_time,
                e.createdAt.length > 16
                    ? e.createdAt.substring(0, 16).replaceAll('T', '  ')
                    : e.createdAt),
            if (hasNext) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ctrl.updateEmergency(e.id, flow[idx + 1]);
                  _refresh();
                },
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text('Mark as ${flow[idx + 1]}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Map',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Obx(() {
        // Rebuild markers whenever emergencies list changes
        WidgetsBinding.instance.addPostFrameCallback((_) => _buildMarkers());

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _defaultLatLng,
                zoom: 11,
              ),
              onMapCreated: (c) => _mapController.complete(c),
              markers: _markers.values.toSet(),
              myLocationButtonEnabled: false,
            ),
            if (ctrl.loadingEmergencies.value)
              const Center(child: CircularProgressIndicator()),

            // Legend
            Positioned(
              top: 16,
              left: 16,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      _LegendRow(color: Colors.red, label: 'CRITICAL'),
                      _LegendRow(color: Colors.orange, label: 'HIGH'),
                      _LegendRow(color: Colors.amber, label: 'MEDIUM'),
                      _LegendRow(color: Colors.green, label: 'LOW'),
                    ],
                  ),
                ),
              ),
            ),

            // Counter badge
            Positioned(
              top: 16,
              right: 16,
              child: Obx(() => Card(
                    elevation: 4,
                    color: Colors.red.shade700,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Text(
                        '${ctrl.emergencies.where((e) => e.hasLocation).length} on map',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                  )),
            ),
          ],
        );
      }),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      );
}
