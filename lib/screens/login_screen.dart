import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ctrl = Get.find<AdminController>();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;

  // OTP resend countdown
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds <= 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) {
      ctrl.error.value = 'Enter a valid 10-digit phone number';
      return;
    }
    final ok = await ctrl.sendOtp(phone);
    if (ok) {
      setState(() => _otpSent = true);
      _startResendTimer();
    }
  }

  Future<void> _resendOtp() async {
    ctrl.error.value = '';
    final ok = await ctrl.sendOtp(_phoneCtrl.text.trim());
    if (ok) {
      _startResendTimer();
      Get.snackbar(
        'OTP Resent',
        'A new OTP has been sent to your phone',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );
    }
  }

  Future<void> _verify() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 4) {
      ctrl.error.value = 'Enter the OTP received via SMS';
      return;
    }
    final ok = await ctrl.verifyOtp(_phoneCtrl.text.trim(), otp);
    if (ok) Get.offAllNamed('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.admin_panel_settings,
                      size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text('Admin Panel',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const Text('Home Care Service',
                    style: TextStyle(fontSize: 13, color: Colors.white60)),
                const SizedBox(height: 36),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_otpSent) ...[
                        const Text('Phone Number',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          decoration: _inputDeco(
                              'e.g. 9876543210', Icons.phone)
                              .copyWith(counterText: ''),
                        ),
                        const SizedBox(height: 18),
                        Obx(() => FilledButton(
                              onPressed: ctrl.loadingAuth.value ? null : _sendOtp,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1A237E),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: ctrl.loadingAuth.value
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Text('Send OTP',
                                      style: TextStyle(fontSize: 15)),
                            )),
                      ] else ...[
                        Row(children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, size: 18),
                            onPressed: () {
                              ctrl.error.value = '';
                              _resendTimer?.cancel();
                              setState(() {
                                _otpSent = false;
                                _otpCtrl.clear();
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                                'OTP sent to +91 ${_phoneCtrl.text}',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600)),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _otpCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          autofocus: true,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 10),
                          decoration: _inputDeco(
                                  '— — — — — —', Icons.lock_outline)
                              .copyWith(counterText: ''),
                        ),
                        const SizedBox(height: 18),
                        Obx(() => FilledButton(
                              onPressed: ctrl.loadingAuth.value ? null : _verify,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1A237E),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: ctrl.loadingAuth.value
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Text('Verify & Login',
                                      style: TextStyle(fontSize: 15)),
                            )),
                        const SizedBox(height: 8),
                        // Resend OTP with countdown
                        StatefulBuilder(
                          builder: (_, ss) => TextButton(
                            onPressed: (_resendSeconds > 0 ||
                                    ctrl.loadingAuth.value)
                                ? null
                                : _resendOtp,
                            child: _resendSeconds > 0
                                ? Text(
                                    'Resend OTP in ${_resendSeconds}s',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 13),
                                  )
                                : const Text('Resend OTP',
                                    style: TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                      // Error message
                      Obx(() {
                        if (ctrl.error.value.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red.shade600, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(ctrl.error.value,
                                    style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 13)),
                              ),
                            ]),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                    'Only ADMIN / SUPER_ADMIN accounts can access this panel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      );
}
