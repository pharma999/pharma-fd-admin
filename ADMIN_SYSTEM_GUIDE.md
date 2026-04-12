# Admin System Documentation

## Overview

This Flutter application implements a comprehensive hierarchical admin system with the following roles:

- **Super Admin**: Manages all hospitals, doctors, and can block/unblock them
- **Hospital Admin**: Manages a single hospital and its doctors/staff
- **Doctors**: Can be registered by hospital or individually
- **System**: Notification system for all admin actions

## Project Structure

```
lib/
├── Models/
│   ├── admin_model.dart          # Admin user model
│   ├── hospital_model.dart       # Hospital model
│   ├── doctor_model.dart         # Doctor model
│   ├── notification_model.dart   # Notification system
│   └── user_model.dart
├── Controller/
│   ├── admin_controller.dart     # Admin business logic
│   ├── hospital_controller.dart
│   ├── doctor_controller.dart
│   └── ...
├── Pages/
│   ├── AdminLogin/
│   │   └── admin_login_page.dart
│   ├── AdminRegistration/
│   │   └── admin_registration_page.dart
│   ├── AdminDashboard/
│   │   ├── admin_dashboard_page.dart
│   │   ├── HospitalManagement/
│   │   │   └── hospital_management_page.dart
│   │   ├── DoctorManagement/
│   │   │   └── doctor_management_page.dart
│   │   └── Notifications/
│   │       └── notifications_page.dart
│   └── ...
└── main.dart
```

## Features Implemented

### 1. Admin Authentication

#### Registration (`AdminRegistrationPage`)
- Register as Hospital Admin or Super Admin
- Validate email, phone, and password
- Store admin credentials securely

**Location**: [lib/Pages/AdminRegistration/admin_registration_page.dart](lib/Pages/AdminRegistration/admin_registration_page.dart)

#### Login (`AdminLoginPage`)
- Secure login with email and password
- Remember me functionality
- Forgot password option

**Location**: [lib/Pages/AdminLogin/admin_login_page.dart](lib/Pages/AdminLogin/admin_login_page.dart)

### 2. Admin Dashboard

Main dashboard after login showing:

- **Quick Overview Stats**:
  - Total hospitals (Super Admin only)
  - Total doctors
  - Pending approvals
  - Blocked doctors

- **Management Menu**:
  - Hospital Management
  - Doctor Management
  - Notifications
  - Admin Settings

- **Account Information**: Display current admin details

**Location**: [lib/Pages/AdminDashboard/admin_dashboard_page.dart](lib/Pages/AdminDashboard/admin_dashboard_page.dart)

### 3. Hospital Management

#### Super Admin Only Features:

**Add Hospital**
```dart
Hospital(
  name: 'Hospital Name',
  email: 'hospital@example.com',
  phone: '+1234567890',
  address: 'Hospital Address',
  city: 'City Name',
  state: 'State Name',
  zipCode: 'ZIP Code',
  country: 'Country',
  totalBeds: 100,
  registrationNumber: 'REG123',
  licenseNumber: 'LIC123'
)
```

**Block/Unblock Hospitals**
- Super admin can block hospitals with a reason
- Sends notification to hospital admin
- Hospital marked as inactive

**View Hospital Details**
- Complete hospital information
- Available beds status
- Action buttons for block/unblock

**Location**: [lib/Pages/AdminDashboard/HospitalManagement/hospital_management_page.dart](lib/Pages/AdminDashboard/HospitalManagement/hospital_management_page.dart)

### 4. Doctor Management

#### Super Admin Features:

**Approve/Reject Doctors**
- View pending doctor registrations
- Approve with verification
- Reject with reason notification

**Block/Unblock Doctors**
- Block doctors for policy violations
- Send notification with block reason
- Track blocked doctors

**Filter Doctors By Status:**
- All doctors
- Verified doctors
- Pending approvals
- Blocked doctors

#### Features:

- View doctor details (license, specialization, experience)
- Filter by verification status
- Approve/reject pending registrations
- Block/unblock verified doctors

**Location**: [lib/Pages/AdminDashboard/DoctorManagement/doctor_management_page.dart](lib/Pages/AdminDashboard/DoctorManagement/doctor_management_page.dart)

### 5. Notification System

#### Notification Types:

1. **Hospital Blocked** - Sent when super admin blocks a hospital
2. **Doctor Blocked** - Sent when doctor is blocked
3. **Registration Approved** - Sent when doctor registration is approved
4. **Registration Rejected** - Sent when doctor registration is rejected with reason
5. **System Alert** - General system notifications

#### Features:

- View all notifications
- Mark as read
- Unread notification badge on dashboard
- Notification details with timestamps
- Block reasons stored in metadata

**Location**: [lib/Pages/AdminDashboard/Notifications/notifications_page.dart](lib/Pages/AdminDashboard/Notifications/notifications_page.dart)

### 6. Admin Controller

Centralized business logic for all admin operations.

**Key Methods:**

```dart
// Authentication
Future<bool> registerAdmin({...})
Future<bool> loginAdmin({...})
void logout()

// Hospital Management
Future<bool> addHospital(Hospital hospital)
Future<bool> updateHospital(Hospital hospital)
Future<bool> blockHospital(String hospitalId, {required String reason})
Future<bool> unblockHospital(String hospitalId)
Future<void> fetchHospitals()

// Doctor Management
Future<bool> approveDoctor(String doctorId)
Future<bool> rejectDoctor(String doctorId, {required String reason})
Future<bool> blockDoctor(String doctorId, {required String reason})
Future<void> fetchDoctors()

// Notifications
Future<void> fetchNotifications()
Future<bool> markNotificationAsRead(String notificationId)
void updateUnreadCount()
```

**Location**: [lib/Controller/admin_controller.dart](lib/Controller/admin_controller.dart)

## Models

### Admin Model
```dart
class Admin {
  String id;
  String firstName, lastName, email, phone;
  String adminType; // 'super_admin' or 'hospital_admin'
  String? hospitalId;
  bool isActive, isVerified;
  String password;
  List<String> permissions;
  bool isBlocked;
  String? blockReason;
}
```

**Location**: [lib/Models/admin_model.dart](lib/Models/admin_model.dart)

### Notification Model
```dart
class Notification {
  String id;
  String title, message;
  String type; // 'hospital_blocked', 'doctor_blocked', etc.
  String? recipientId, senderId;
  String? hospitalId, doctorId;
  bool isRead;
  DateTime createdAt, readAt;
  Map<String, dynamic>? metadata; // reasons, etc.
}
```

**Location**: [lib/Models/notification_model.dart](lib/Models/notification_model.dart)

## Usage Examples

### 1. Register as Admin

```dart
await adminController.registerAdmin(
  firstName: 'John',
  lastName: 'Admin',
  email: 'john@hospital.com',
  phone: '+1234567890',
  password: 'SecurePass123',
  confirmPassword: 'SecurePass123',
  adminType: 'hospital_admin',
  hospitalId: 'hospital_id_123',
);
```

### 2. Add a Hospital (Super Admin)

```dart
final hospital = Hospital(
  name: 'City Hospital',
  email: 'contact@cityhospital.com',
  phone: '+1234567890',
  address: '123 Main St',
  city: 'New York',
  state: 'NY',
  zipCode: '10001',
  country: 'USA',
  totalBeds: 150,
  isActive: true,
);

await adminController.addHospital(hospital);
```

### 3. Approve a Doctor

```dart
await adminController.approveDoctor('doctor_id_123');
```

### 4. Block a Hospital

```dart
await adminController.blockHospital(
  'hospital_id_123',
  reason: 'Non-compliance with regulations',
);
```

### 5. Get Pending Doctors

```dart
var pendingDoctors = adminController.doctors
    .where((doctor) => !doctor.isVerified)
    .toList();
```

## State Management (GetX)

The app uses GetX for reactive state management:

```dart
// Observable properties
final adminController = Get.find<AdminController>();

Obx(() {
  // Reactive UI updates
  print(adminController.currentAdmin.value?.fullName);
  print(adminController.hospitals.length);
});
```

## Permissions System

### Super Admin Permissions:
- `manage_hospitals`
- `manage_doctors`
- `manage_admins`
- `block_hospital`
- `block_doctor`
- `approve_doctor`
- `view_notifications`

### Hospital Admin Permissions:
- `manage_doctors`
- `manage_staff`
- `view_notifications`

## Next Steps for Development

1. **Backend Integration**:
   - Replace mock API calls with real backend endpoints
   - Implement authentication tokens (JWT)
   - Setup database persistence

2. **Additional Features**:
   - Export reports (PDF/Excel)
   - Advanced filtering and search
   - Bulk operations (approve multiple doctors)
   - Admin activity logs
   - Hospital performance metrics

3. **Super Admin App**:
   - Create separate super admin-only application
   - Real-time dashboard with charts
   - Analytics and insights
   - Advanced hospital/doctor management

4. **Security**:
   - Implement secure password hashing
   - Two-factor authentication
   - Role-based access control (RBAC)
   - Audit logs

5. **UI/UX Improvements**:
   - Add loading states and error handling
   - Implement pagination for large lists
   - Add search and advanced filters
   - Create reusable widget components

## API Integration Notes

Currently, all operations use mock data. To integrate with your backend:

1. Update `AdminController` methods to make HTTP requests
2. Add API endpoints in separate service class
3. Implement proper error handling and validation
4. Store auth tokens in `SharedPreferences`

Example structure:

```dart
class AdminService {
  final String baseUrl = 'https://your-api.com/api';
  
  Future<AdminResponse> registerAdmin(AdminRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/register'),
      body: jsonEncode(request.toJson()),
    );
    return AdminResponse.fromJson(jsonDecode(response.body));
  }
}
```

## Testing

Recommended test cases:

- Admin registration validation
- Login authentication flow
- Hospital CRUD operations
- Doctor approval/rejection workflow
- Notification system
- Permission-based access control
- Block/unblock functionality

## Support

For questions or issues with this admin system:

1. Check the model documentation
2. Review controller methods
3. Examine UI components for implementation examples
4. Refer to GetX documentation for state management

---

**Version**: 1.0.0  
**Last Updated**: April 2026  
**Author**: Development Team
