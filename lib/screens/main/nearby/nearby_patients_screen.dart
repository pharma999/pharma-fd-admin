import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:home_care_admin/core/api_client.dart';

class NearbyPatientsScreen extends StatefulWidget {
  const NearbyPatientsScreen({super.key});

  @override
  State<NearbyPatientsScreen> createState() => _NearbyPatientsScreenState();
}

class _NearbyPatientsScreenState extends State<NearbyPatientsScreen> {
  List<Map<String, dynamic>> _patients = [];
  bool _loading = true;
  bool _locating = false;
  String _error = '';
  double _lat = 0, _lng = 0;
  double _radius = 5;
  bool _locationReady = false;

  static const _radii = [5.0, 10.0, 20.0, 50.0];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await _getPosition();
      if (pos != null) {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _locationReady = true;
        // Push provider location to backend
        _syncProviderLocation();
        await _fetchNearby();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() {_locating = false; _loading = false;});
    }
  }

  Future<void> _syncProviderLocation() async {
    try {
      await ApiClient.post('/provider/location', {
        'latitude': _lat,
        'longitude': _lng,
      });
    } catch (_) {}
  }

  Future<void> _fetchNearby() async {
    if (!_locationReady) return;
    if (mounted) setState(() => _loading = true);
    try {
      final res = await ApiClient.get(
        '/patients/nearby?lat=$_lat&lng=$_lng&radius=$_radius',
      );
      final raw = res['data'];
      if (mounted) {
        setState(() {
          _patients = (raw is List)
              ? raw
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList()
              : [];
        });
      }
    } catch (_) {
      if (mounted) setState(() => _patients = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _locating = true);
    try {
      final pos = await _getPosition();
      if (pos != null) {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _locationReady = true;
        _syncProviderLocation();
        await _fetchNearby();
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<Position?> _getPosition() async {
    bool svc = await Geolocator.isLocationServiceEnabled();
    if (!svc) return null;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) { return null; }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: const Color(0xFF2563EB),
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Nearby Patients',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                            Text(
                              _locationReady
                                  ? '${_patients.length} within ${_radius.toStringAsFixed(0)} KM'
                                  : 'Fetching your location…',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: _locating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.my_location_rounded,
                                color: Colors.white),
                        onPressed: _locating ? null : _refresh,
                        tooltip: 'Refresh location',
                      ),
                    ]),
                    const SizedBox(height: 8),
                    // Radius chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _radii.map((r) {
                          final active = _radius == r;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _radius = r);
                              _fetchNearby();
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: active
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${r.toStringAsFixed(0)} KM',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? const Color(0xFF2563EB)
                                      : Colors.white,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error.isNotEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.location_off_rounded,
              size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Location unavailable',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 8),
          TextButton(
              onPressed: _refresh, child: const Text('Try Again')),
        ]),
      );
    }

    if (_loading || _locating) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }

    if (_patients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded,
                size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No patients found within\n${_radius.toStringAsFixed(0)} KM',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: _radii
                  .where((r) => r > _radius)
                  .map((r) => OutlinedButton(
                        onPressed: () {
                          setState(() => _radius = r);
                          _fetchNearby();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text('Expand to ${r.toStringAsFixed(0)} KM',
                            style: const TextStyle(fontSize: 12)),
                      ))
                  .toList(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF2563EB),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _patients.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _PatientCard(patient: _patients[i]),
      ),
    );
  }
}

// ── Patient card ──────────────────────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final Map<String, dynamic> patient;
  const _PatientCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    final name    = patient['name']?.toString() ?? 'Patient';
    final phone   = patient['phone']?.toString() ?? '';
    final service = patient['requested_service']?.toString() ?? '';
    final dist    = (patient['distance_km'] ?? 0).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'P',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB)),
          ),
        ),
        title: Text(name,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF1E293B))),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (phone.isNotEmpty)
              Text(phone,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B))),
            if (service.isNotEmpty)
              Text('Service: $service',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
        trailing: dist > 0
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.near_me_rounded,
                      size: 14, color: Color(0xFF16A34A)),
                  Text(
                    '${dist.toStringAsFixed(1)} KM',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A)),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
