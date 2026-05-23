import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_care_admin/screens/splash_screen.dart';
import 'package:home_care_admin/screens/auth/phone_screen.dart';
import 'package:home_care_admin/screens/auth/otp_screen.dart';
import 'package:home_care_admin/screens/onboarding/provider_type_screen.dart';
import 'package:home_care_admin/screens/onboarding/individual_profile_screen.dart';
import 'package:home_care_admin/screens/onboarding/org_profile_screen.dart';
import 'package:home_care_admin/screens/onboarding/document_upload_screen.dart';
import 'package:home_care_admin/screens/onboarding/verification_status_screen.dart';
import 'package:home_care_admin/screens/main/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderApp());
}

class ProviderApp extends StatelessWidget {
  const ProviderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'HomeCare Provider',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1E293B),
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      initialRoute: '/splash',
      getPages: [
        GetPage(name: '/splash', page: () => const SplashScreen()),
        GetPage(name: '/phone', page: () => const PhoneScreen()),
        GetPage(name: '/otp', page: () => const OtpScreen()),
        GetPage(
            name: '/provider-type', page: () => const ProviderTypeScreen()),
        GetPage(
            name: '/individual-profile',
            page: () => const IndividualProfileScreen()),
        GetPage(name: '/org-profile', page: () => const OrgProfileScreen()),
        GetPage(
            name: '/doc-upload',
            page: () => const DocumentUploadScreen()),
        GetPage(
            name: '/verification',
            page: () => const VerificationStatusScreen()),
        GetPage(name: '/main', page: () => const MainShell()),
      ],
    );
  }
}
