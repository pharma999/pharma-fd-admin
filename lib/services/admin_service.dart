import '../core/api_client.dart';
import '../models/models.dart';

class AdminService {
  final _c = ApiClient.instance;

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// Step 1: send OTP via MessageCentral — returns verification_id
  Future<Map<String, dynamic>> sendOtp(String phone) async =>
      await _c.post('auth/send-otp', {'phone_number': phone}, auth: false);

  /// Step 2: verify OTP — returns token, user_id, role, name
  Future<Map<String, dynamic>> verifyOtp(
          String phone, String otp, String verificationId) async =>
      await _c.post('auth/verify-otp', {
        'phone_number': phone,
        'otp': otp,
        'verification_id': verificationId,
      }, auth: false);

  // ── Analytics ─────────────────────────────────────────────────────────────

  Future<AdminAnalytics> getAnalytics() async {
    final res = await _c.get('admin/analytics');
    return AdminAnalytics.fromJson(res['data']);
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  Future<List<AdminUser>> listUsers({String? role, String? status, int page = 1}) async {
    final q = <String, String>{'page': '$page', 'limit': '20'};
    if (role != null && role.isNotEmpty) q['role'] = role;
    if (status != null && status.isNotEmpty) q['status'] = status;
    final res = await _c.get('admin/users', query: q);
    return (res['data'] as List).map((e) => AdminUser.fromJson(e)).toList();
  }

  Future<void> blockUser(String id, bool block) =>
      _c.patch('admin/users/$id/block', {'block': block});

  // ── Doctors ───────────────────────────────────────────────────────────────

  Future<List<AdminDoctor>> listDoctors({String? approvalStatus, int page = 1}) async {
    final q = <String, String>{'page': '$page', 'limit': '20'};
    if (approvalStatus != null && approvalStatus.isNotEmpty) {
      q['approval_status'] = approvalStatus;
    }
    final res = await _c.get('admin/doctors', query: q);
    return (res['data'] as List).map((e) => AdminDoctor.fromJson(e)).toList();
  }

  Future<void> approveDoctor(String id, String status) =>
      _c.patch('admin/doctors/$id/approval', {'status': status});

  // ── Nurses ────────────────────────────────────────────────────────────────

  Future<List<AdminNurse>> listNurses({String? approvalStatus, int page = 1}) async {
    final q = <String, String>{'page': '$page', 'limit': '20'};
    if (approvalStatus != null && approvalStatus.isNotEmpty) {
      q['approval_status'] = approvalStatus;
    }
    final res = await _c.get('admin/nurses', query: q);
    return (res['data'] as List).map((e) => AdminNurse.fromJson(e)).toList();
  }

  Future<void> approveNurse(String id, String status) =>
      _c.patch('admin/nurses/$id/approval', {'status': status});

  // ── Hospitals ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listHospitals(
      {String? approvalStatus, int page = 1}) async {
    final q = <String, String>{'page': '$page', 'limit': '20'};
    if (approvalStatus != null && approvalStatus.isNotEmpty) {
      q['approval_status'] = approvalStatus;
    }
    final res = await _c.get('admin/hospitals', query: q);
    return (res['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> approveHospital(String id, String status) =>
      _c.patch('admin/hospitals/$id/approval', {'status': status});

  // ── Bookings ──────────────────────────────────────────────────────────────

  Future<List<AdminBooking>> listBookings({String? status, int page = 1}) async {
    final q = <String, String>{'page': '$page', 'limit': '20'};
    if (status != null && status.isNotEmpty) q['status'] = status;
    final res = await _c.get('admin/bookings', query: q);
    return (res['data'] as List).map((e) => AdminBooking.fromJson(e)).toList();
  }

  Future<void> updateBookingStatus(String id, String status) =>
      _c.patch('admin/bookings/$id/status', {'status': status});

  // ── Emergencies ───────────────────────────────────────────────────────────

  Future<List<AdminEmergency>> listActiveEmergencies() async {
    final res = await _c.get('admin/emergencies/active');
    return (res['data'] as List)
        .map((e) => AdminEmergency.fromJson(e))
        .toList();
  }

  Future<void> updateEmergencyStatus(String id, String status) =>
      _c.patch('admin/emergencies/$id/status', {'status': status});

  // ── Support Tickets ───────────────────────────────────────────────────────

  Future<List<AdminTicket>> listTickets({String? status, int page = 1}) async {
    final q = <String, String>{'page': '$page', 'limit': '20'};
    if (status != null && status.isNotEmpty) q['status'] = status;
    final res = await _c.get('admin/support', query: q);
    return (res['data'] as List).map((e) => AdminTicket.fromJson(e)).toList();
  }

  Future<void> resolveTicket(String id,
          {required String resolution}) =>
      _c.patch('admin/support/$id',
          {'status': 'RESOLVED', 'resolution': resolution});

  // ── Subscription Plans ────────────────────────────────────────────────────

  Future<List<AdminPlan>> listPlans() async {
    final res = await _c.get('admin/plans');
    return (res['data'] as List).map((e) => AdminPlan.fromJson(e)).toList();
  }

  Future<void> createPlan(Map<String, dynamic> body) =>
      _c.post('admin/plans', body);

  Future<void> togglePlan(String id, bool active) =>
      _c.patch('admin/plans/$id', {'is_active': active});

  Future<void> deletePlan(String id) => _c.delete('admin/plans/$id');

  // ── Appointments ─────────────────────────────────────────────────────────

  Future<List<AdminAppointment>> listAppointments({String? status, int page = 1}) async {
    final q = <String, String>{'page': '$page', 'limit': '20'};
    if (status != null && status.isNotEmpty) q['status'] = status;
    final res = await _c.get('admin/appointments', query: q);
    return (res['data'] as List).map((e) => AdminAppointment.fromJson(e)).toList();
  }

  // ── Service Zones ─────────────────────────────────────────────────────────

  Future<List<AdminZone>> listZones() async {
    final res = await _c.get('admin/zones');
    return (res['data'] as List).map((e) => AdminZone.fromJson(e)).toList();
  }

  Future<void> createZone(Map<String, dynamic> body) =>
      _c.post('admin/zones', body);

  Future<void> updateZone(String id, Map<String, dynamic> body) =>
      _c.put('admin/zones/$id', body);

  Future<void> deleteZone(String id) => _c.delete('admin/zones/$id');
}
