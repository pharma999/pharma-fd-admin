import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/token_storage.dart';
import '../core/admin_websocket.dart';
import '../models/models.dart';
import '../services/admin_service.dart';

class AdminController extends GetxController {
  final _svc = AdminService();

  // ── Identity ───────────────────────────────────────────────────────────
  RxString adminName = ''.obs;
  RxString adminRole = ''.obs;

  // ── Analytics ─────────────────────────────────────────────────────────
  Rx<AdminAnalytics?> analytics = Rx(null);
  RxBool loadingAnalytics = false.obs;

  // ── Users ──────────────────────────────────────────────────────────────
  RxList<AdminUser> users = <AdminUser>[].obs;
  RxBool loadingUsers = false.obs;
  RxString userRoleFilter = ''.obs;

  // ── Approvals ─────────────────────────────────────────────────────────
  RxList<AdminDoctor> doctors = <AdminDoctor>[].obs;
  RxList<AdminNurse> nurses = <AdminNurse>[].obs;
  RxList<Map<String, dynamic>> hospitals = <Map<String, dynamic>>[].obs;
  RxBool loadingApprovals = false.obs;
  RxString approvalFilter = 'PENDING'.obs;

  // ── Bookings ──────────────────────────────────────────────────────────
  RxList<AdminBooking> bookings = <AdminBooking>[].obs;
  RxBool loadingBookings = false.obs;

  // ── Emergencies ───────────────────────────────────────────────────────
  RxList<AdminEmergency> emergencies = <AdminEmergency>[].obs;
  RxBool loadingEmergencies = false.obs;

  // ── Tickets ───────────────────────────────────────────────────────────
  RxList<AdminTicket> tickets = <AdminTicket>[].obs;
  RxBool loadingTickets = false.obs;
  RxString ticketFilter = ''.obs;

  // ── Plans ─────────────────────────────────────────────────────────────
  RxList<AdminPlan> plans = <AdminPlan>[].obs;
  RxBool loadingPlans = false.obs;

  // ── Appointments ──────────────────────────────────────────────────────
  RxList<AdminAppointment> appointments = <AdminAppointment>[].obs;
  RxBool loadingAppointments = false.obs;

  // ── Zones ─────────────────────────────────────────────────────────────
  RxList<AdminZone> zones = <AdminZone>[].obs;
  RxBool loadingZones = false.obs;

  // ── Error ─────────────────────────────────────────────────────────────
  RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadIdentity();
    fetchAnalytics();
    _connectWs();
  }

  void _connectWs() {
    AdminWebSocket.instance.connect();
    AdminWebSocket.instance.messages.listen((msg) {
      switch (msg.event) {
        case AdminWsEvent.emergencyNew:
        case AdminWsEvent.emergencyStatus:
          // Refresh emergency list to pick up any new/updated emergency
          fetchEmergencies();
        case AdminWsEvent.ambulanceLocation:
          // Update ambulance position on the shared map if available
          final id = msg.payload['emergency_id'] as String?;
          if (id == null) break;
          final lat = double.tryParse(
              msg.payload['latitude']?.toString() ?? '');
          final lng = double.tryParse(
              msg.payload['longitude']?.toString() ?? '');
          if (lat != null && lng != null) {
            ambulancePositions[id] = AmbulancePosition(lat, lng);
          }
        default:
          break;
      }
    });
  }

  @override
  void onClose() {
    AdminWebSocket.instance.disconnect();
    super.onClose();
  }

  // ── Real-time ambulance positions (emergencyId → position) ────────────────
  final RxMap<String, AmbulancePosition> ambulancePositions =
      <String, AmbulancePosition>{}.obs;

  Future<void> _loadIdentity() async {
    adminName.value = await TokenStorage.getName() ?? '';
    adminRole.value = await TokenStorage.getRole() ?? '';
  }

  // ── Auth ──────────────────────────────────────────────────────────────

  final RxString _verificationId = ''.obs;
  RxBool loadingAuth = false.obs;

  /// Step 1: request OTP via MessageCentral
  Future<bool> sendOtp(String phone) async {
    loadingAuth.value = true;
    error.value = '';
    try {
      final res = await _svc.sendOtp(phone);
      if (res['success'] == true) {
        _verificationId.value = res['verification_id'] ?? '';
        return true;
      }
      error.value = res['message'] ?? 'Failed to send OTP';
    } catch (e) {
      error.value = 'Network error. Please try again.';
    } finally {
      loadingAuth.value = false;
    }
    return false;
  }

  /// Step 2: verify OTP — receives JWT unique to this user
  Future<bool> verifyOtp(String phone, String otp) async {
    loadingAuth.value = true;
    error.value = '';
    try {
      final res = await _svc.verifyOtp(phone, otp, _verificationId.value);
      if (res['success'] != true) {
        error.value = res['message'] ?? 'OTP verification failed';
        return false;
      }
      final role = res['role'] ?? '';
      if (role != 'ADMIN' && role != 'SUPER_ADMIN') {
        error.value = 'Access denied. Admin credentials required.';
        return false;
      }
      await TokenStorage.save(
        token: res['token'] ?? res['access_token'] ?? '',
        userId: res['user_id'] ?? '',
        role: role,
        name: res['name'] ?? 'Admin',
      );
      adminRole.value = role;
      adminName.value = res['name'] ?? 'Admin';
      return true;
    } catch (e) {
      error.value = 'Network error. Please try again.';
    } finally {
      loadingAuth.value = false;
    }
    return false;
  }

  Future<void> logout() async {
    await TokenStorage.clear();
    Get.offAllNamed('/login');
  }

  // ── Analytics ─────────────────────────────────────────────────────────

  Future<void> fetchAnalytics() async {
    try {
      loadingAnalytics.value = true;
      analytics.value = await _svc.getAnalytics();
    } catch (e) {
      error.value = e.toString();
    } finally {
      loadingAnalytics.value = false;
    }
  }

  // ── Users ─────────────────────────────────────────────────────────────

  Future<void> fetchUsers({String? role}) async {
    try {
      loadingUsers.value = true;
      users.value = await _svc.listUsers(
          role: role ?? (userRoleFilter.value.isEmpty ? null : userRoleFilter.value));
    } catch (e) {
      error.value = e.toString();
    } finally {
      loadingUsers.value = false;
    }
  }

  Future<void> blockUser(String id, bool block) async {
    try {
      await _svc.blockUser(id, block);
      fetchUsers();
      _successSnackbar(block ? 'User blocked' : 'User unblocked');
    } catch (e) {
      _errorSnackbar(e.toString());
    }
  }

  // ── Approvals ─────────────────────────────────────────────────────────

  Future<void> fetchApprovals({String? filter}) async {
    final f = filter ?? approvalFilter.value;
    try {
      loadingApprovals.value = true;
      doctors.value = await _svc.listDoctors(approvalStatus: f);
      nurses.value = await _svc.listNurses(approvalStatus: f);
      hospitals.value = await _svc.listHospitals(approvalStatus: f);
    } catch (e) {
      error.value = e.toString();
    } finally {
      loadingApprovals.value = false;
    }
  }

  Future<void> approveDoctor(String id, String status) async {
    try {
      await _svc.approveDoctor(id, status);
      fetchApprovals();
      _successSnackbar('Doctor $status');
    } catch (e) {
      _errorSnackbar(e.toString());
    }
  }

  Future<void> approveNurse(String id, String status) async {
    try {
      await _svc.approveNurse(id, status);
      fetchApprovals();
      _successSnackbar('Nurse $status');
    } catch (e) {
      _errorSnackbar(e.toString());
    }
  }

  Future<void> approveHospital(String id, String status) async {
    try {
      await _svc.approveHospital(id, status);
      fetchApprovals();
      _successSnackbar('Hospital $status');
    } catch (e) {
      _errorSnackbar(e.toString());
    }
  }

  // ── Bookings ──────────────────────────────────────────────────────────

  Future<void> fetchBookings({String? status}) async {
    try {
      loadingBookings.value = true;
      bookings.value = await _svc.listBookings(status: status);
    } catch (e) {
      error.value = e.toString();
    } finally {
      loadingBookings.value = false;
    }
  }

  Future<void> updateBooking(String id, String status) async {
    try {
      await _svc.updateBookingStatus(id, status);
      fetchBookings();
      _successSnackbar('Booking → $status');
    } catch (e) {
      _errorSnackbar(e.toString());
    }
  }

  // ── Emergencies ───────────────────────────────────────────────────────

  Future<void> fetchEmergencies() async {
    try {
      loadingEmergencies.value = true;
      emergencies.value = await _svc.listActiveEmergencies();
    } catch (e) {
      error.value = e.toString();
    } finally {
      loadingEmergencies.value = false;
    }
  }

  Future<void> updateEmergency(String id, String status) async {
    try {
      await _svc.updateEmergencyStatus(id, status);
      fetchEmergencies();
      _successSnackbar('Emergency → $status');
    } catch (e) {
      _errorSnackbar(e.toString());
    }
  }

  // ── Tickets ───────────────────────────────────────────────────────────

  Future<void> fetchTickets({String? status}) async {
    try {
      loadingTickets.value = true;
      tickets.value = await _svc.listTickets(
          status: status ??
              (ticketFilter.value.isEmpty ? null : ticketFilter.value));
    } catch (e) {
      error.value = e.toString();
    } finally {
      loadingTickets.value = false;
    }
  }

  Future<void> resolveTicket(String id, String resolution) async {
    try {
      await _svc.resolveTicket(id, resolution: resolution);
      fetchTickets();
      _successSnackbar('Ticket resolved');
    } catch (e) {
      _errorSnackbar(e.toString());
    }
  }

  // ── Plans ─────────────────────────────────────────────────────────────

  Future<void> fetchPlans() async {
    try {
      loadingPlans.value = true;
      plans.value = await _svc.listPlans();
    } catch (e) {
      error.value = e.toString();
    } finally {
      loadingPlans.value = false;
    }
  }

  Future<void> createPlan(Map<String, dynamic> body) async {
    try {
      await _svc.createPlan(body);
      fetchPlans();
      _successSnackbar('Plan created');
    } catch (e) {
      _errorSnackbar(e.toString());
    }
  }

  Future<void> togglePlan(String id, bool active) async {
    try {
      await _svc.togglePlan(id, active);
      fetchPlans();
    } catch (e) {
      _errorSnackbar(e.toString());
    }
  }

  Future<void> deletePlan(String id) async {
    try {
      await _svc.deletePlan(id);
      plans.removeWhere((p) => p.id == id);
      _successSnackbar('Plan deleted');
    } catch (e) {
      _errorSnackbar(e.toString());
    }
  }

  // ── Appointments ──────────────────────────────────────────────────────

  Future<void> fetchAppointments({String? status}) async {
    try {
      loadingAppointments.value = true;
      appointments.value = await _svc.listAppointments(status: status);
    } catch (e) {
      error.value = e.toString();
    } finally {
      loadingAppointments.value = false;
    }
  }

  // ── Zones ─────────────────────────────────────────────────────────────

  Future<void> fetchZones() async {
    try {
      loadingZones.value = true;
      zones.value = await _svc.listZones();
    } catch (e) {
      error.value = e.toString();
    } finally {
      loadingZones.value = false;
    }
  }

  Future<void> createZone(Map<String, dynamic> body) async {
    try {
      await _svc.createZone(body);
      fetchZones();
      _successSnackbar('Zone created');
    } catch (e) {
      _errorSnackbar(e.toString());
    }
  }

  Future<void> deleteZone(String id) async {
    try {
      await _svc.deleteZone(id);
      zones.removeWhere((z) => z.id == id);
      _successSnackbar('Zone deleted');
    } catch (e) {
      _errorSnackbar(e.toString());
    }
  }

  // ── Snackbar helpers ──────────────────────────────────────────────────

  void _successSnackbar(String message) {
    Get.snackbar(
      'Done',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF2E7D32),
      colorText: Colors.white,
      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(12),
    );
  }

  void _errorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFC62828),
      colorText: Colors.white,
      icon: const Icon(Icons.error_outline, color: Colors.white),
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(12),
    );
  }
}
