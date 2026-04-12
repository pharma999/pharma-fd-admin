import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controllers/admin_controller.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/approvals_screen.dart';
import 'screens/users_screen.dart';
import 'screens/bookings_screen.dart';
import 'screens/emergencies_screen.dart';
import 'screens/tickets_screen.dart';
import 'screens/plans_screen.dart';
import 'screens/zones_screen.dart';
import 'screens/appointments_screen.dart';
import 'screens/emergency_map_screen.dart';
import 'core/token_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Home Care Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00897B)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(elevation: 0),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      initialBinding: BindingsBuilder(() {
        Get.put(AdminController());
      }),
      initialRoute: '/splash',
      getPages: [
        GetPage(name: '/splash', page: () => const _SplashPage()),
        GetPage(name: '/login', page: () => const LoginScreen()),
        GetPage(name: '/dashboard', page: () => const DashboardScreen()),
        GetPage(name: '/approvals', page: () => const ApprovalsScreen()),
        GetPage(name: '/users', page: () => const UsersScreen()),
        GetPage(name: '/bookings', page: () => const BookingsScreen()),
        GetPage(name: '/emergencies', page: () => const EmergenciesScreen()),
        GetPage(name: '/tickets', page: () => const TicketsScreen()),
        GetPage(name: '/plans', page: () => const PlansScreen()),
        GetPage(name: '/zones', page: () => const ZonesScreen()),
        GetPage(name: '/appointments', page: () => const AppointmentsScreen()),
        GetPage(name: '/emergency-map', page: () => const EmergencyMapScreen()),
      ],
    );
  }
}

class _SplashPage extends StatefulWidget {
  const _SplashPage();
  @override
  State<_SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<_SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 800));
    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      Get.offAllNamed('/dashboard');
    } else {
      Get.offAllNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF00897B),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.admin_panel_settings, size: 80, color: Colors.white),
            SizedBox(height: 16),
            Text('Home Care Admin',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
