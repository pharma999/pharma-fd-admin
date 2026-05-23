import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:home_care_admin/models/provider_models.dart';

class BookingMapScreen extends StatefulWidget {
  final ProviderBooking booking;

  const BookingMapScreen({super.key, required this.booking});

  @override
  State<BookingMapScreen> createState() => _BookingMapScreenState();
}

class _BookingMapScreenState extends State<BookingMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  Position? _myPosition;
  bool _loadingLocation = true;
  Set<Marker> _markers = {};
  Timer? _locationTimer;

  late final LatLng _customerLatLng;

  @override
  void initState() {
    super.initState();
    _customerLatLng = LatLng(
      widget.booking.customerLat!,
      widget.booking.customerLng!,
    );
    _init();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _fetchMyLocation();
    _buildMarkers();
    // refresh provider marker every 10 s
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _fetchMyLocation();
      _buildMarkers();
    });
  }

  Future<void> _fetchMyLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) setState(() { _myPosition = pos; _loadingLocation = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _buildMarkers() {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('customer'),
        position: _customerLatLng,
        infoWindow: InfoWindow(
          title: widget.booking.customerName.isEmpty
              ? 'Customer'
              : widget.booking.customerName,
          snippet: widget.booking.address,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
    if (_myPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('me'),
        position: LatLng(_myPosition!.latitude, _myPosition!.longitude),
        infoWindow: const InfoWindow(title: 'You'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }
    if (mounted) setState(() => _markers = markers);
  }

  Future<void> _openNavigation() async {
    final lat = widget.booking.customerLat!;
    final lng = widget.booking.customerLng!;
    final name = Uri.encodeComponent(
        widget.booking.customerName.isNotEmpty
            ? widget.booking.customerName
            : 'Customer');

    // Try Google Maps app first, then browser fallback
    final gmUri = Uri.parse(
        'google.navigation:q=$lat,$lng&mode=d');
    final webUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving&destination_place_id=$name');

    if (await canLaunchUrl(gmUri)) {
      await launchUrl(gmUri);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _centerOnCustomer() async {
    final ctrl = await _mapController.future;
    ctrl.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: _customerLatLng, zoom: 15),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final initialCamera = CameraPosition(
      target: _myPosition != null
          ? LatLng(
              (_myPosition!.latitude + _customerLatLng.latitude) / 2,
              (_myPosition!.longitude + _customerLatLng.longitude) / 2,
            )
          : _customerLatLng,
      zoom: 13,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Navigate to Customer'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'Centre on customer',
            onPressed: _centerOnCustomer,
          ),
        ],
      ),
      body: Column(
        children: [
          // Customer info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_pin_circle_rounded,
                      color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.booking.customerName.isEmpty
                            ? 'Customer'
                            : widget.booking.customerName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.booking.address.isEmpty
                            ? 'Location pinned on map'
                            : widget.booking.address,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          // Map
          Expanded(
            child: _loadingLocation
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF2563EB)),
                        SizedBox(height: 12),
                        Text('Getting your location…',
                            style: TextStyle(color: Color(0xFF64748B))),
                      ],
                    ),
                  )
                : GoogleMap(
                    initialCameraPosition: initialCamera,
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                    onMapCreated: (ctrl) {
                      if (!_mapController.isCompleted) {
                        _mapController.complete(ctrl);
                      }
                    },
                  ),
          ),
          // Navigate button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openNavigation,
                icon: const Icon(Icons.navigation_rounded, size: 20),
                label: const Text(
                  'Start Navigation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
