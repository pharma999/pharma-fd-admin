/// Centralized API endpoint constants for the Admin panel.
/// All path segments are relative to [ApiConfig.baseUrl].
class AdminRoutes {
  AdminRoutes._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String sendOtp    = 'auth/send-otp';
  static const String verifyOtp  = 'auth/verify-otp';

  // ── Analytics ─────────────────────────────────────────────────────────────
  static const String analytics  = 'admin/analytics';

  // ── Users ─────────────────────────────────────────────────────────────────
  static const String users               = 'admin/users';
  static String       userBlock(String id) => 'admin/users/$id/block';

  // ── Doctors ───────────────────────────────────────────────────────────────
  static const String doctors               = 'admin/doctors';
  static String       doctorApproval(String id) => 'admin/doctors/$id/approval';

  // ── Nurses ────────────────────────────────────────────────────────────────
  static const String nurses               = 'admin/nurses';
  static String       nurseApproval(String id) => 'admin/nurses/$id/approval';

  // ── Hospitals ─────────────────────────────────────────────────────────────
  static const String hospitals               = 'admin/hospitals';
  static String       hospitalApproval(String id) => 'admin/hospitals/$id/approval';

  // ── Bookings ──────────────────────────────────────────────────────────────
  static const String bookings                  = 'admin/bookings';
  static String       bookingStatus(String id)  => 'admin/bookings/$id/status';

  // ── Appointments ──────────────────────────────────────────────────────────
  static const String appointments = 'admin/appointments';

  // ── Emergencies ───────────────────────────────────────────────────────────
  static const String activeEmergencies           = 'admin/emergencies/active';
  static String       emergencyStatus(String id)  => 'admin/emergencies/$id/status';
  static String       emergencyDetail(String id)  => 'admin/emergencies/$id';

  // ── Support Tickets ───────────────────────────────────────────────────────
  static const String tickets              = 'admin/support';
  static String       ticket(String id)    => 'admin/support/$id';

  // ── Subscription Plans ────────────────────────────────────────────────────
  static const String plans             = 'admin/plans';
  static String       plan(String id)   => 'admin/plans/$id';
  static String       planToggle(String id) => 'admin/plans/$id/toggle';
  static const String subscriptions     = 'admin/subscriptions';

  // ── Service Zones ─────────────────────────────────────────────────────────
  static const String zones           = 'admin/zones';
  static String       zone(String id) => 'admin/zones/$id';

  // ── Professionals ─────────────────────────────────────────────────────────
  static const String professionals               = 'admin/professionals';
  static String       professional(String id)     => 'admin/professionals/$id';

  // ── Services & Categories (read — created by super admin) ─────────────────
  static const String categories      = 'categories';
  static const String services        = 'services';
  static String       categoryCreate  = 'admin/categories';
  static String       serviceCreate   = 'admin/services';
  static String       serviceUpdate(String id) => 'admin/services/$id';

  // ── Promo Codes ───────────────────────────────────────────────────────────
  static const String promoCodes           = 'admin/promo-codes';
  static String       promoCode(String id) => 'admin/promo-codes/$id';

  // ── Payouts ───────────────────────────────────────────────────────────────
  static const String payouts              = 'admin/payouts';
  static String       payout(String id)    => 'admin/payouts/$id';

  // ── Banners ───────────────────────────────────────────────────────────────
  static const String banners              = 'admin/banners';
  static String       banner(String id)    => 'admin/banners/$id';

  // ── Disputes ──────────────────────────────────────────────────────────────
  static const String disputes             = 'admin/disputes';
  static String       dispute(String id)   => 'admin/disputes/$id';

  // ── Manual Booking Assignment ─────────────────────────────────────────────
  static String bookingAssign(String id) => 'admin/bookings/$id/assign';

  // ── WebSocket ─────────────────────────────────────────────────────────────
  /// Pass ?token=JWT&rooms=admin:emergencies
  static const String ws = 'ws';
}
