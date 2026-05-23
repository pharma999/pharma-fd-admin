// ── Real-time ambulance position ──────────────────────────────────────────────

class AmbulancePosition {
  final double latitude;
  final double longitude;
  const AmbulancePosition(this.latitude, this.longitude);
}

// ── Analytics ─────────────────────────────────────────────────────────────────

class AdminAnalytics {
  final int totalUsers;
  final int totalBookings;
  final int activeEmergencies;
  final int pendingApprovals;
  final double totalRevenue;
  final int openTickets;
  final int totalDoctors;
  final int totalNurses;
  final int totalHospitals;
  final int totalAppointments;

  AdminAnalytics({
    required this.totalUsers,
    required this.totalBookings,
    required this.activeEmergencies,
    required this.pendingApprovals,
    required this.totalRevenue,
    required this.openTickets,
    required this.totalDoctors,
    required this.totalNurses,
    required this.totalHospitals,
    required this.totalAppointments,
  });

  factory AdminAnalytics.fromJson(Map<String, dynamic> j) => AdminAnalytics(
    totalUsers: j['total_users'] ?? 0,
    totalBookings: j['total_bookings'] ?? 0,
    activeEmergencies: j['active_emergencies'] ?? 0,
    pendingApprovals: j['pending_approvals'] ?? 0,
    totalRevenue: (j['total_revenue'] ?? 0).toDouble(),
    openTickets: j['open_tickets'] ?? 0,
    totalDoctors: j['total_doctors'] ?? 0,
    totalNurses: j['total_nurses'] ?? 0,
    totalHospitals: j['total_hospitals'] ?? 0,
    totalAppointments: j['total_appointments'] ?? 0,
  );
}

// ── Users ──────────────────────────────────────────────────────────────────────

class AdminUser {
  final String id;
  final String name;
  final String phone;
  final String role;
  final bool isBlocked;
  final String status;

  AdminUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.isBlocked,
    required this.status,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
    id: j['user_id'] ?? j['id'] ?? j['_id'] ?? '',
    name: j['name'] ?? '',
    phone: j['phone_number'] ?? j['phone'] ?? '',
    role: j['role'] ?? 'PATIENT',
    isBlocked: j['block_status'] == 'BLOCKED' || j['is_blocked'] == true,
    status: j['status'] ?? 'ACTIVE',
  );
}

// ── Doctors ───────────────────────────────────────────────────────────────────

class AdminDoctor {
  final String id;
  final String name;
  final String specialty;
  final String approvalStatus;
  final String licenseNumber;
  final String phone;
  final int experience;
  final double consultationFee;
  final double rating;

  AdminDoctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.approvalStatus,
    required this.licenseNumber,
    required this.phone,
    required this.experience,
    required this.consultationFee,
    required this.rating,
  });

  factory AdminDoctor.fromJson(Map<String, dynamic> j) => AdminDoctor(
    id: j['id'] ?? j['_id'] ?? '',
    name: j['name'] ?? '',
    specialty: j['specialty'] ?? '',
    approvalStatus: j['approval_status'] ?? 'PENDING',
    licenseNumber: j['license_number'] ?? '',
    phone: j['phone_number'] ?? j['phone'] ?? '',
    experience: j['experience'] ?? 0,
    consultationFee: (j['consultation_fee'] ?? 0).toDouble(),
    rating: (j['rating'] ?? 0).toDouble(),
  );
}

// ── Nurses ────────────────────────────────────────────────────────────────────

class AdminNurse {
  final String id;
  final String name;
  final String approvalStatus;
  final String phone;
  final String certification;
  final String category;
  final int experience;
  final double hourlyRate;
  final double rating;

  AdminNurse({
    required this.id,
    required this.name,
    required this.approvalStatus,
    required this.phone,
    required this.certification,
    required this.category,
    required this.experience,
    required this.hourlyRate,
    required this.rating,
  });

  factory AdminNurse.fromJson(Map<String, dynamic> j) => AdminNurse(
    id: j['id'] ?? j['_id'] ?? '',
    name: j['name'] ?? '',
    approvalStatus: j['approval_status'] ?? 'PENDING',
    phone: j['phone_number'] ?? j['phone'] ?? '',
    certification: j['certification'] ?? '',
    category: j['category'] ?? '',
    experience: j['experience'] ?? 0,
    hourlyRate: (j['hourly_rate'] ?? 0).toDouble(),
    rating: (j['rating'] ?? 0).toDouble(),
  );
}

// ── Bookings ──────────────────────────────────────────────────────────────────

class AdminBooking {
  final String id;
  final String serviceName;
  final double totalAmount;
  final String status;
  final String scheduledAt;

  AdminBooking({
    required this.id,
    required this.serviceName,
    required this.totalAmount,
    required this.status,
    required this.scheduledAt,
  });

  bool get isActive => status == 'PENDING' || status == 'ACCEPTED';

  factory AdminBooking.fromJson(Map<String, dynamic> j) => AdminBooking(
    id: j['id'] ?? j['_id'] ?? '',
    serviceName: j['service_name'] ?? 'Unknown Service',
    totalAmount: (j['total_amount'] ?? 0).toDouble(),
    status: j['status'] ?? 'PENDING',
    scheduledAt: j['scheduled_at'] ?? '',
  );
}

// ── Emergencies ────────────────────────────────────────────────────────────────

class AdminEmergency {
  final String id;
  final String? description;
  final String? address;
  final String status;
  final String priority;
  final String createdAt;
  final double? latitude;
  final double? longitude;
  final String? patientName;
  final String? emergencyType;
  final String? ambulanceId;

  AdminEmergency({
    required this.id,
    this.description,
    this.address,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.patientName,
    this.emergencyType,
    this.ambulanceId,
  });

  bool get hasLocation => latitude != null && longitude != null;

  factory AdminEmergency.fromJson(Map<String, dynamic> j) => AdminEmergency(
    id: j['id'] ?? j['_id'] ?? '',
    description: j['description'] ?? j['symptom_description'],
    address: j['address'] ?? j['patient_address'],
    status: j['status'] ?? 'TRIGGERED',
    priority: j['priority'] ?? 'HIGH',
    createdAt: j['created_at'] ?? '',
    latitude: _toDouble(j['patient_latitude'] ?? j['latitude']),
    longitude: _toDouble(j['patient_longitude'] ?? j['longitude']),
    patientName: j['patient_name'],
    emergencyType: j['emergency_type'],
    ambulanceId: j['ambulance_id'],
  );

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

// ── Support Tickets ───────────────────────────────────────────────────────────

class AdminTicket {
  final String id;
  final String subject;
  final String description;
  final String userName;
  final String userPhone;
  final String status;
  final String priority;
  final String category;

  AdminTicket({
    required this.id,
    required this.subject,
    required this.description,
    required this.userName,
    required this.userPhone,
    required this.status,
    required this.priority,
    required this.category,
  });

  bool get isOpen => status == 'OPEN' || status == 'IN_PROGRESS';

  factory AdminTicket.fromJson(Map<String, dynamic> j) => AdminTicket(
    id: j['id'] ?? j['_id'] ?? '',
    subject: j['subject'] ?? '',
    description: j['description'] ?? '',
    userName: j['user_name'] ?? '',
    userPhone: j['user_phone'] ?? '',
    status: j['status'] ?? 'OPEN',
    priority: j['priority'] ?? 'LOW',
    category: j['category'] ?? 'GENERAL',
  );
}

// ── Subscription Plans ────────────────────────────────────────────────────────

class AdminPlan {
  final String id;
  final String name;
  final String description;
  final double price;
  final String duration;
  final List<String> features;
  final int maxBookings;
  final int maxFamilyMembers;
  final bool isActive;

  AdminPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.duration,
    required this.features,
    required this.maxBookings,
    required this.maxFamilyMembers,
    required this.isActive,
  });

  factory AdminPlan.fromJson(Map<String, dynamic> j) => AdminPlan(
    id: j['id'] ?? j['_id'] ?? '',
    name: j['name'] ?? '',
    description: j['description'] ?? '',
    price: (j['price'] ?? 0).toDouble(),
    duration: j['duration'] ?? 'MONTHLY',
    features: List<String>.from(j['features'] ?? []),
    maxBookings: j['max_bookings'] ?? 10,
    maxFamilyMembers: j['max_family_members'] ?? 5,
    isActive: j['is_active'] ?? true,
  );
}

// ── Appointments ──────────────────────────────────────────────────────────────

class AdminAppointment {
  final String id;
  final String patientUserId;
  final String doctorId;
  final String serviceId;
  final String appointmentType;
  final String status;
  final String scheduledAt;
  final double totalAmount;
  final String paymentStatus;
  final String notes;
  final String createdAt;

  AdminAppointment({
    required this.id,
    required this.patientUserId,
    required this.doctorId,
    required this.serviceId,
    required this.appointmentType,
    required this.status,
    required this.scheduledAt,
    required this.totalAmount,
    required this.paymentStatus,
    required this.notes,
    required this.createdAt,
  });

  bool get isActive =>
      status == 'PENDING' || status == 'CONFIRMED' || status == 'IN_PROGRESS';

  factory AdminAppointment.fromJson(Map<String, dynamic> j) => AdminAppointment(
    id: j['id'] ?? j['_id'] ?? '',
    patientUserId: j['patient_user_id'] ?? '',
    doctorId: j['doctor_id'] ?? '',
    serviceId: j['service_id'] ?? '',
    appointmentType: j['appointment_type'] ?? '',
    status: j['status'] ?? 'PENDING',
    scheduledAt: j['scheduled_at'] ?? '',
    totalAmount: (j['total_amount'] ?? 0).toDouble(),
    paymentStatus: j['payment_status'] ?? 'PENDING',
    notes: j['notes'] ?? '',
    createdAt: j['created_at'] ?? '',
  );
}

// ── Professionals ─────────────────────────────────────────────────────────────

class AdminProfessional {
  final String id;
  final String name;
  final String role;
  final String serviceName;
  final String zoneId;
  final String zoneName;
  final String bio;
  final String qualification;
  final double rating;
  final bool isAvailable;
  final int yearsExperience;
  final int estimatedDuration;
  final double hourlyRate;
  final String availableTimeStart;
  final String availableTimeEnd;
  final String imageUrl;

  AdminProfessional({
    required this.id,
    required this.name,
    required this.role,
    required this.serviceName,
    required this.zoneId,
    required this.zoneName,
    required this.bio,
    required this.qualification,
    required this.rating,
    required this.isAvailable,
    required this.yearsExperience,
    required this.estimatedDuration,
    required this.hourlyRate,
    required this.availableTimeStart,
    required this.availableTimeEnd,
    required this.imageUrl,
  });

  factory AdminProfessional.fromJson(Map<String, dynamic> j) => AdminProfessional(
    id: j['id'] ?? j['_id'] ?? '',
    name: j['name'] ?? '',
    role: j['role'] ?? '',
    serviceName: j['service_name'] ?? '',
    zoneId: j['zone_id'] ?? '',
    zoneName: j['zone_name'] ?? '',
    bio: j['bio'] ?? '',
    qualification: j['qualification'] ?? '',
    rating: (j['rating'] ?? 0).toDouble(),
    isAvailable: j['available'] ?? j['is_available'] ?? true,
    yearsExperience: j['years_experience'] ?? j['years_of_experience'] ?? 0,
    estimatedDuration: j['estimated_duration'] ?? 30,
    hourlyRate: (j['hourly_rate'] ?? 0).toDouble(),
    availableTimeStart: j['available_time_start'] ?? '',
    availableTimeEnd: j['available_time_end'] ?? '',
    imageUrl: j['image_url'] ?? '',
  );
}

// ── Promo Codes ───────────────────────────────────────────────────────────────

class AdminPromoCode {
  final String id;
  final String code;
  final String description;
  final String discountType;
  final double discountValue;
  final double minOrderAmount;
  final double maxDiscount;
  final int usageLimit;
  final int usedCount;
  final bool isActive;
  final String? expiresAt;

  AdminPromoCode({
    required this.id,
    required this.code,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    required this.maxDiscount,
    required this.usageLimit,
    required this.usedCount,
    required this.isActive,
    this.expiresAt,
  });

  factory AdminPromoCode.fromJson(Map<String, dynamic> j) => AdminPromoCode(
    id: j['promo_id'] ?? j['id'] ?? '',
    code: j['code'] ?? '',
    description: j['description'] ?? '',
    discountType: j['discount_type'] ?? 'FLAT',
    discountValue: (j['discount_value'] ?? 0).toDouble(),
    minOrderAmount: (j['min_order_amount'] ?? 0).toDouble(),
    maxDiscount: (j['max_discount'] ?? 0).toDouble(),
    usageLimit: j['usage_limit'] ?? 0,
    usedCount: j['used_count'] ?? 0,
    isActive: j['is_active'] ?? true,
    expiresAt: j['expires_at'],
  );
}

// ── Payouts ──────────────────────────────────────────────────────────────────

class AdminPayout {
  final String id;
  final String professionalId;
  final String userId;
  final double amount;
  final String status;
  final String notes;
  final String createdAt;

  AdminPayout({
    required this.id,
    required this.professionalId,
    required this.userId,
    required this.amount,
    required this.status,
    required this.notes,
    required this.createdAt,
  });

  factory AdminPayout.fromJson(Map<String, dynamic> j) => AdminPayout(
    id: j['payout_id'] ?? j['id'] ?? '',
    professionalId: j['professional_id'] ?? '',
    userId: j['user_id'] ?? '',
    amount: (j['amount'] ?? 0).toDouble(),
    status: j['status'] ?? 'PENDING',
    notes: j['notes'] ?? '',
    createdAt: j['created_at'] ?? '',
  );
}

// ── Banners ──────────────────────────────────────────────────────────────────

class AdminBanner {
  final String id;
  final String title;
  final String imageUrl;
  final String linkUrl;
  final bool isActive;
  final int sortOrder;

  AdminBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.linkUrl,
    required this.isActive,
    required this.sortOrder,
  });

  factory AdminBanner.fromJson(Map<String, dynamic> j) => AdminBanner(
    id: j['banner_id'] ?? j['id'] ?? '',
    title: j['title'] ?? '',
    imageUrl: j['image_url'] ?? '',
    linkUrl: j['link_url'] ?? '',
    isActive: j['is_active'] ?? true,
    sortOrder: j['sort_order'] ?? 0,
  );
}

// ── Disputes ─────────────────────────────────────────────────────────────────

class AdminDispute {
  final String id;
  final String bookingId;
  final String raisedBy;
  final String description;
  final String status;
  final String resolution;
  final String createdAt;

  AdminDispute({
    required this.id,
    required this.bookingId,
    required this.raisedBy,
    required this.description,
    required this.status,
    required this.resolution,
    required this.createdAt,
  });

  factory AdminDispute.fromJson(Map<String, dynamic> j) => AdminDispute(
    id: j['dispute_id'] ?? j['id'] ?? '',
    bookingId: j['booking_id'] ?? '',
    raisedBy: j['raised_by'] ?? '',
    description: j['description'] ?? '',
    status: j['status'] ?? 'OPEN',
    resolution: j['resolution'] ?? '',
    createdAt: j['created_at'] ?? '',
  );
}

// ── Service Zones ─────────────────────────────────────────────────────────────

class AdminZone {
  final String id;
  final String name;
  final String city;
  final String state;
  final List<String> pinCodes;
  final String status;

  AdminZone({
    required this.id,
    required this.name,
    required this.city,
    required this.state,
    required this.pinCodes,
    required this.status,
  });

  factory AdminZone.fromJson(Map<String, dynamic> j) => AdminZone(
    id: j['id'] ?? j['_id'] ?? '',
    name: j['name'] ?? '',
    city: j['city'] ?? '',
    state: j['state'] ?? '',
    pinCodes: List<String>.from(j['pin_codes'] ?? []),
    status: j['status'] ?? 'ACTIVE',
  );
}
