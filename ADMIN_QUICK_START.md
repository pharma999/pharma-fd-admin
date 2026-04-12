# Quick Start Guide - Admin System

## Getting Started

### 1. Initialize AdminController in main.dart

Add the AdminController initialization before running the app:

```dart
void main() {
  // Initialize GetX controller
  Get.put(AdminController());
  
  runApp(const MyApp());
}
```

### 2. Navigation Routes

Add these routes to your GetMaterialApp or routing configuration:

```dart
GetMaterialApp(
  routes: {
    '/admin-register': (context) => const AdminRegistrationPage(),
    '/admin-login': (context) => const AdminLoginPage(),
    '/admin-dashboard': (context) => const AdminDashboardPage(),
  },
  home: const AdminLoginPage(), // Start with login
)
```

### 3. Quick Testing

#### Test Admin Registration:
```
Navigate to: AdminRegistrationPage
Select: Hospital Admin or Super Admin
Fill in details:
- First Name: John
- Last Name: Doe
- Email: john@example.com
- Phone: +1234567890
- Password: Test@123
- Confirm Password: Test@123
```

#### Test Admin Login:
```
Navigate to: AdminLoginPage
Email: john@example.com
Password: Test@123
Click: Login
```

#### Test Hospital Management:
```
1. Go to Admin Dashboard
2. Bottom Navigation → Hospitals
3. Click + icon to add hospital
4. Fill hospital details
5. View hospital details and manage
```

#### Test Doctor Management:
```
1. Go to Admin Dashboard
2. Bottom Navigation → Doctors
3. Filter doctors by status (All/Verified/Pending/Blocked)
4. Click doctor card to view details
5. Approve/Reject pending doctors
6. Block/Unblock doctors
```

#### Test Notifications:
```
1. Go Admin Dashboard
2. Bottom Navigation → Notifications
3. Perform any action (approve, reject, block)
4. Check notifications list
5. Click to mark as read
```

## File Structure Summary

| File | Purpose |
|------|---------|
| `admin_model.dart` | Admin user data model |
| `notification_model.dart` | Notification system model |
| `admin_controller.dart` | Business logic & state management |
| `admin_login_page.dart` | Login UI |
| `admin_registration_page.dart` | Registration UI |
| `admin_dashboard_page.dart` | Main dashboard & home page |
| `hospital_management_page.dart` | Hospital CRUD operations |
| `doctor_management_page.dart` | Doctor approval/rejection/blocking |
| `notifications_page.dart` | Notification list & management |

## Key Features at a Glance

### For Super Admin:
✅ Register as Super Admin
✅ Add/Edit/View Hospitals
✅ Block/Unblock Hospitals
✅ Approve/Reject Doctors
✅ Block/Unblock Doctors
✅ View All Notifications
✅ Manage Permissions

### For Hospital Admin:
✅ Register as Hospital Admin (linked to hospital)
✅ View Hospital Doctors
✅ View Hospital Notifications
✅ Manage Hospital Staff

### Notification Features:
✅ Real-time notifications
✅ Mark as read
✅ Unread count badge
✅ Notification history
✅ Reason tracking for blocks/rejections

## Important Notes

1. **State Management**: Uses GetX - all changes are reactive
2. **Mock Data**: Currently uses mock implementation - integrate with backend as needed
3. **Validation**: Form validation included for registration and login
4. **Error Handling**: Error messages displayed via Get.snackbar()
5. **Responsive**: UI adapts to different screen sizes

## Next Actions

### Before Production:

1. **Backend Setup**:
   - Create API endpoints for registration, login, hospital/doctor management
   - Setup database schema
   - Implement authentication tokens

2. **Security**:
   - Add password hashing
   - Implement JWT token management
   - Add role-based access control

3. **Testing**:
   - Write unit tests for AdminController
   - Test all permission scenarios
   - Test notification system flow

4. **Deployment**:
   - Configure API endpoints for your backend
   - Setup environment variables
   - Test with real data

## Troubleshooting

### AdminController not found?
```dart
// Make sure AdminController is initialized in main.dart
Get.put(AdminController());
```

### GetX observables not updating?
```dart
// Use Obx wrapper for reactive widgets
Obx(() => Text(adminController.currentAdmin.value?.fullName ?? 'Guest'))
```

### Navigation not working?
```dart
// Check your GetMaterialApp routes/home configuration
// Use Get.to() or Get.toNamed() for navigation
```

## Common Operations

### Get Current Admin Info:
```dart
final admin = adminController.currentAdmin.value;
print(admin?.fullName);
```

### Check Admin Type:
```dart
if (adminController.isSuperAdmin()) {
  // Show super admin features
}
if (adminController.isHospitalAdmin()) {
  // Show hospital admin features
}
```

### Filter Operations:
```dart
// Get unverified doctors
final pending = adminController.doctors
    .where((d) => !d.isVerified)
    .toList();

// Get active hospitals
final active = adminController.hospitals
    .where((h) => h.isActive)
    .toList();
```

### Add Notification Listener:
```dart
@override
void initState() {
  super.initState();
  adminController.fetchNotifications();
}
```

---

**Happy Coding!** 🚀

For detailed documentation, see [ADMIN_SYSTEM_GUIDE.md](ADMIN_SYSTEM_GUIDE.md)
