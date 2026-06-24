import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:home_care_admin/core/api_client.dart';
import 'package:home_care_admin/models/provider_models.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

// ── Booking Map Screen (Provider) ─────────────────────────────────────────────
// Uses OpenStreetMap (no Google Maps, no API key required).
// Geolocator stream updates every 4 s; marker glides smoothly to each new fix.
// Each location update is sent to the backend → patient's tracking page reacts.

class BookingMapScreen extends StatefulWidget {
  final ProviderBooking booking;
  const BookingMapScreen({super.key, required this.booking});

  @override
  State<BookingMapScreen> createState() => _BookingMapScreenState();
}

class _BookingMapScreenState extends State<BookingMapScreen> {
  final _mapController = MapController();

  // ── Map state ─────────────────────────────────────────────────────────────
  LatLng? _animLoc;           // smoothly interpolated provider position
  LatLng? _animFrom;
  Timer? _animTimer;

  double _heading      = 0;
  double _distKm       = 0;
  int    _etaMin       = 0;
  bool   _loadingLoc   = true;
  bool   _cameraFollow = true; // pause auto-follow when user pans

  List<LatLng> _routePoints = [];
  bool         _routeFetched = false;

  late final LatLng _destLoc; // customer location

  // Geolocator live stream
  StreamSubscription<Position>? _posSub;

  static const _blue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _destLoc = LatLng(
      widget.booking.customerLat ?? 0,
      widget.booking.customerLng ?? 0,
    );
    _startLocationStream();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _animTimer?.cancel();
    super.dispose();
  }

  // ── GPS stream ────────────────────────────────────────────────────────────

  Future<void> _startLocationStream() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _loadingLoc = false);
        return;
      }
      final initial = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      _onPosition(initial);

      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          timeLimit: Duration(seconds: 4),
        ),
      ).listen(_onPosition, onError: (_) {});
    } catch (_) {
      if (mounted) setState(() => _loadingLoc = false);
    }
  }

  void _onPosition(Position pos) {
    final newLoc = LatLng(pos.latitude, pos.longitude);

    // Calculate heading before animating
    if (_animLoc != null && _animLoc != newLoc) {
      _heading = _bearing(_animLoc!, newLoc);
    }

    _animateTo(newLoc);
    _recalcEta(newLoc);
    if (mounted) setState(() => _loadingLoc = false);

    // Push location to backend → triggers WS event → patient map moves
    ApiClient.patch('/provider/location', {
      'latitude':   pos.latitude,
      'longitude':  pos.longitude,
      'booking_id': widget.booking.id,
    }).catchError((_) => <String, dynamic>{});

    // Fetch route once when we have provider position
    if (!_routeFetched && _destLoc.latitude != 0) {
      _routeFetched = true;
      _fetchOsrmRoute(newLoc, _destLoc);
    }
  }

  // ── OSRM routing ──────────────────────────────────────────────────────────

  Future<void> _fetchOsrmRoute(LatLng from, LatLng to) async {
    try {
      final url =
          'http://router.project-osrm.org/route/v1/driving/'
          '${from.longitude},${from.latitude};'
          '${to.longitude},${to.latitude}'
          '?geometries=geojson&overview=full';
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) { _setFallback(from, to); return; }
      final data   = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) { _setFallback(from, to); return; }
      final coords = routes[0]['geometry']['coordinates'] as List;
      final pts = coords
          .map((c) =>
              LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      if (mounted) setState(() => _routePoints = pts);
    } catch (_) {
      _setFallback(from, to);
    }
  }

  void _setFallback(LatLng from, LatLng to) {
    if (mounted) setState(() => _routePoints = [from, to]);
  }

  // ── Smooth marker animation ───────────────────────────────────────────────

  void _animateTo(LatLng newLoc) {
    final from = _animLoc;
    if (from == null) {
      _animLoc = newLoc;
      if (mounted) setState(() {});
      if (_cameraFollow) _moveCamera(newLoc);
      return;
    }
    _animFrom = from;
    _animTimer?.cancel();
    const steps = 16;
    int step = 0;
    _animTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!mounted) { t.cancel(); return; }
      step++;
      final f = step / steps;
      _animLoc = LatLng(
        _animFrom!.latitude  + (newLoc.latitude  - _animFrom!.latitude)  * f,
        _animFrom!.longitude + (newLoc.longitude - _animFrom!.longitude) * f,
      );
      setState(() {});
      if (_cameraFollow) _moveCamera(_animLoc!);
      if (step >= steps) { t.cancel(); _animFrom = null; }
    });
  }

  void _moveCamera(LatLng loc) {
    try {
      _mapController.move(loc, _mapController.camera.zoom);
    } catch (_) {}
  }

  // ── ETA ───────────────────────────────────────────────────────────────────

  void _recalcEta(LatLng from) {
    if (_destLoc.latitude == 0) return;
    final d = _haversineKm(
        from.latitude, from.longitude, _destLoc.latitude, _destLoc.longitude);
    if (mounted) {
      setState(() {
        _distKm = (d * 10).round() / 10;
        _etaMin = (d / 30 * 60).ceil();
      });
    }
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude  * math.pi / 180;
    final lat2 = to.latitude    * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  // ── Fit both markers ──────────────────────────────────────────────────────

  void _fitBounds() {
    if (_animLoc == null) return;
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: [_animLoc!, _destLoc],
          padding: const EdgeInsets.all(70),
        ),
      );
    } catch (_) {}
  }

  // ── Open external navigation ──────────────────────────────────────────────

  Future<void> _openNavigation() async {
    final lat  = _destLoc.latitude;
    final lng  = _destLoc.longitude;
    final gm   = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final web  = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(gm)) {
      await launchUrl(gm);
    } else {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final initialCenter = _animLoc ?? _destLoc;

    return Scaffold(
      body: _loadingLoc
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _blue),
                  SizedBox(height: 12),
                  Text('Getting your location…',
                      style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            )
          : Stack(
              children: [
                // ── OpenStreetMap ─────────────────────────────────────────
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: initialCenter,
                      initialZoom: 15,
                      onMapEvent: (event) {
                        // Pause auto-follow when user initiates a drag gesture
                        if (event is MapEventMoveStart &&
                            event.source == MapEventSource.dragStart) {
                          _cameraFollow = false;
                        }
                      },
                    ),
                    children: [
                      // OSM tile layer
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.homecare.provider',
                        maxZoom: 19,
                      ),
                      // Route polyline
                      if (_routePoints.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              color:
                                  const Color(0xFF2563EB).withValues(alpha: 0.85),
                              strokeWidth: 5,
                              borderColor: const Color(0xFF1E3A8A)
                                  .withValues(alpha: 0.3),
                              borderStrokeWidth: 1,
                            ),
                          ],
                        ),
                      // Destination marker (customer)
                      MarkerLayer(markers: [
                        Marker(
                          point: _destLoc,
                          width: 48,
                          height: 60,
                          alignment: Alignment.bottomCenter,
                          child: const _CustomerPin(),
                        ),
                      ]),
                      // Provider (self) moving marker
                      if (_animLoc != null)
                        MarkerLayer(markers: [
                          Marker(
                            point: _animLoc!,
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            child: _VehicleMarker(heading: _heading),
                          ),
                        ]),
                      // Attribution
                      RichAttributionWidget(
                        alignment: AttributionAlignment.bottomLeft,
                        attributions: [
                          TextSourceAttribution(
                              '© OpenStreetMap contributors',
                              onTap: () => launchUrl(Uri.parse(
                                  'https://openstreetmap.org/copyright'))),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Top bar ───────────────────────────────────────────────
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: _buildTopBar(),
                ),

                // ── Resume camera follow FAB ──────────────────────────────
                if (!_cameraFollow)
                  Positioned(
                    right: 16,
                    bottom: 190,
                    child: FloatingActionButton.small(
                      heroTag: 'refollow',
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      onPressed: () {
                        setState(() => _cameraFollow = true);
                        if (_animLoc != null) _moveCamera(_animLoc!);
                      },
                      child: const Icon(Icons.my_location_rounded),
                    ),
                  ),

                // ── Fit-bounds FAB ────────────────────────────────────────
                Positioned(
                  right: 16,
                  bottom: 250,
                  child: FloatingActionButton.small(
                    heroTag: 'fitBounds',
                    backgroundColor: Colors.white,
                    foregroundColor: _blue,
                    elevation: 4,
                    onPressed: _fitBounds,
                    child: const Icon(Icons.fit_screen_rounded),
                  ),
                ),

                // ── Bottom panel ──────────────────────────────────────────
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _buildBottomPanel(),
                ),
              ],
            ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _CircleBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8)
                  ],
                ),
                child: Row(children: [
                  const Icon(Icons.directions_run_rounded,
                      color: _blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.booking.address.isEmpty
                          ? 'Navigating to customer'
                          : widget.booking.address,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            _CircleBtn(
                icon: Icons.fit_screen_rounded, onTap: _fitBounds),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Color(0x22000000),
              blurRadius: 20,
              offset: Offset(0, -4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              children: [
                // ETA strip
                if (_distKm > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_blue, Color(0xFF1E40AF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _col('Distance',
                            '${_distKm.toStringAsFixed(1)} KM'),
                        const SizedBox(width: 20),
                        Container(
                          width: 1, height: 32,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 20),
                        _col('ETA', '$_etaMin min'),
                        const Spacer(),
                        const Icon(Icons.electric_moped_rounded,
                            color: Colors.white70, size: 30),
                      ],
                    ),
                  ),
                // Open external navigation button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openNavigation,
                    icon: const Icon(Icons.navigation_rounded, size: 20),
                    label: const Text(
                      'Open Turn-by-Turn Navigation',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _col(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900)),
      ],
    );
  }
}

// ── Custom Markers ────────────────────────────────────────────────────────────

/// Pulsing animated vehicle marker that rotates toward heading.
class _VehicleMarker extends StatefulWidget {
  final double heading;
  const _VehicleMarker({this.heading = 0});

  @override
  State<_VehicleMarker> createState() => _VehicleMarkerState();
}

class _VehicleMarkerState extends State<_VehicleMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 0.88, end: 1.12)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: Transform.rotate(
        angle: widget.heading * math.pi / 180,
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color:
                      const Color(0xFF2563EB).withValues(alpha: 0.55),
                  blurRadius: 14,
                  spreadRadius: 1)
            ],
          ),
          child: const Icon(Icons.two_wheeler_rounded,
              color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

/// Fixed pin for the customer's address.
class _CustomerPin extends StatelessWidget {
  const _CustomerPin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.5),
                  blurRadius: 12, spreadRadius: 1)
            ],
          ),
          child: const Icon(Icons.person_pin_circle_rounded,
              color: Colors.white, size: 24),
        ),
        CustomPaint(
          size: const Size(14, 10),
          painter: _NeedlePainter(const Color(0xFFDC2626)),
        ),
      ],
    );
  }
}

class _NeedlePainter extends CustomPainter {
  final Color color;
  const _NeedlePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_NeedlePainter o) => o.color != color;
}

// ── Shared helper ─────────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)
          ],
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF1E293B)),
      ),
    );
  }
}
