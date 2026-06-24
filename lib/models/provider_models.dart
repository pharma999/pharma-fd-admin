class ProviderProfile {
  final String id;
  final String userId;
  final String name;
  final String category;
  final String approvalStatus;
  final String qualification;
  final String serviceArea;
  final String shiftAvailability;
  final double hourlyRate;
  final double dailyRate;
  final double rating;
  final int yearsOfExperience;
  final int totalReviews;
  final bool isAvailable;
  final bool emergencyCapable;
  final bool isBlocked;
  final String imageUrl;
  final String phone;

  ProviderProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.approvalStatus,
    required this.qualification,
    required this.serviceArea,
    required this.shiftAvailability,
    required this.hourlyRate,
    required this.dailyRate,
    required this.rating,
    required this.yearsOfExperience,
    required this.totalReviews,
    required this.isAvailable,
    required this.emergencyCapable,
    this.isBlocked = false,
    required this.imageUrl,
    required this.phone,
  });

  factory ProviderProfile.fromJson(Map<String, dynamic> j) => ProviderProfile(
        id: j['id'] ?? j['_id'] ?? '',
        userId: j['user_id'] ?? '',
        name: j['name'] ?? '',
        category: j['category'] ?? '',
        approvalStatus: j['approval_status'] ?? 'PENDING',
        qualification: j['qualification'] ?? '',
        serviceArea: j['service_area'] ?? '',
        shiftAvailability: j['shift_availability'] ?? '',
        hourlyRate: (j['hourly_rate'] ?? 0).toDouble(),
        dailyRate: j['daily_rate'] != null
            ? (j['daily_rate']).toDouble()
            : 0.0,
        rating: (j['rating'] ?? 0).toDouble(),
        yearsOfExperience: j['years_of_experience'] ?? 0,
        totalReviews: j['total_reviews'] ?? 0,
        isAvailable: j['is_available'] ?? j['available'] ?? false,
        emergencyCapable: j['emergency_capable'] ?? false,
        isBlocked: j['is_blocked'] ?? false,
        imageUrl: j['image_url'] ?? j['profile_image'] ?? '',
        phone: j['phone_number'] ?? j['phone'] ?? '',
      );
}

class ProviderBooking {
  final String id;
  final String serviceName;
  final String status;
  final String scheduledAt;
  final String customerName;
  final String address;
  final double totalAmount;
  final String customerPhone;
  final String notes;
  final double? customerLat;
  final double? customerLng;

  ProviderBooking({
    required this.id,
    required this.serviceName,
    required this.status,
    required this.scheduledAt,
    required this.customerName,
    required this.address,
    required this.totalAmount,
    required this.customerPhone,
    required this.notes,
    this.customerLat,
    this.customerLng,
  });

  bool get isPending => status == 'PENDING' || status == 'ASSIGNED';
  bool get isAccepted => status == 'ACCEPTED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isCompleted => status == 'COMPLETED';
  bool get isRejected => status == 'REJECTED' || status == 'EXPIRED';
  bool get hasLocation => customerLat != null && customerLng != null;

  factory ProviderBooking.fromJson(Map<String, dynamic> j) {
    double? lat, lng;
    final latRaw = j['patient_latitude'] ?? j['latitude'];
    final lngRaw = j['patient_longitude'] ?? j['longitude'];
    if (latRaw != null) lat = double.tryParse(latRaw.toString());
    if (lngRaw != null) lng = double.tryParse(lngRaw.toString());
    return ProviderBooking(
      id: j['booking_id'] ?? j['id'] ?? j['_id'] ?? '',
      serviceName: j['service_name'] ?? 'Healthcare Service',
      status: j['status'] ?? 'PENDING',
      scheduledAt: j['scheduled_at'] ?? '',
      customerName: j['customer_name'] ?? j['patient_name'] ?? 'Customer',
      address: j['address'] ?? j['patient_address'] ?? '',
      totalAmount: (j['total_amount'] ?? 0).toDouble(),
      customerPhone: j['customer_phone'] ?? j['patient_phone'] ?? '',
      notes: j['notes'] ?? '',
      customerLat: lat,
      customerLng: lng,
    );
  }
}

class ProviderEarnings {
  final double totalEarned;
  final double monthEarned;
  final int totalCompleted;
  final int platformFeePct;

  ProviderEarnings({
    required this.totalEarned,
    required this.monthEarned,
    required this.totalCompleted,
    required this.platformFeePct,
  });

  factory ProviderEarnings.fromJson(Map<String, dynamic> j) => ProviderEarnings(
        totalEarned: (j['total_earned'] ?? 0).toDouble(),
        monthEarned: (j['month_earned'] ?? 0).toDouble(),
        totalCompleted: j['total_completed'] ?? 0,
        platformFeePct: j['platform_fee_pct'] ?? j['platform_fee_percent'] ?? 0,
      );
}

class ProviderNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String refId;
  final String createdAt;
  final bool isRead;

  ProviderNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.refId,
    required this.createdAt,
    required this.isRead,
  });

  factory ProviderNotification.fromJson(Map<String, dynamic> j) =>
      ProviderNotification(
        id: j['id'] ?? j['_id'] ?? '',
        title: j['title'] ?? '',
        body: j['body'] ?? j['message'] ?? '',
        type: j['type'] ?? '',
        refId: j['ref_id'] ?? '',
        createdAt: j['created_at'] ?? '',
        isRead: j['is_read'] ?? j['read'] ?? false,
      );
}

class WalletTransaction {
  final String id;
  final String type;
  final String description;
  final String createdAt;
  final double amount;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.description,
    required this.createdAt,
    required this.amount,
  });

  bool get isCredit => type == 'CREDIT';

  factory WalletTransaction.fromJson(Map<String, dynamic> j) =>
      WalletTransaction(
        id: j['id'] ?? j['_id'] ?? '',
        type: j['type'] ?? 'DEBIT',
        description: j['description'] ?? '',
        createdAt: j['created_at'] ?? '',
        amount: (j['amount'] ?? 0).toDouble(),
      );
}

class WalletInfo {
  final double balance;
  final List<WalletTransaction> transactions;

  WalletInfo({required this.balance, required this.transactions});
}
