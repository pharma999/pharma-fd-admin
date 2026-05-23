import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_care_admin/core/api_client.dart';
import 'package:home_care_admin/core/api_config.dart';
import 'package:home_care_admin/core/token_storage.dart';

class VerificationStatusScreen extends StatefulWidget {
  const VerificationStatusScreen({super.key});

  @override
  State<VerificationStatusScreen> createState() =>
      _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen>
    with TickerProviderStateMixin {
  String _status = 'PENDING';
  String _rejectionReason = '';
  bool _isLoading = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  WebSocket? _ws;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initStatus();
    _connectWebSocket();
    // Poll every 30 s as fallback in case WS is not connected
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_status == 'PENDING') _fetchStatus();
    });
  }

  // Seed from cache immediately, then fetch fresh from server
  Future<void> _initStatus() async {
    final cached = await TokenStorage.getApprovalStatus();
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() {
        _status = cached;
        if (cached != 'PENDING') _isLoading = false;
      });
      if (cached == 'APPROVED') {
        _isLoading = false;
        return; // Already approved — no need to fetch
      }
    }
    await _fetchStatus();
  }

  // ── HTTP fetch ─────────────────────────────────────────────────────────────

  Future<void> _fetchStatus() async {
    try {
      String? nurseId = await TokenStorage.getNurseId();

      Map<String, dynamic> result;
      if (nurseId != null && nurseId.isNotEmpty) {
        result = await ApiClient.get('/nurses/$nurseId');
      } else {
        // Fallback: find by current user's JWT
        result = await ApiClient.get('/nurses/me');
        // Cache the nurseId for future use
        final d = result['data'] as Map<String, dynamic>? ?? result;
        final id = d['nurse_id'] as String? ?? '';
        if (id.isNotEmpty) await TokenStorage.saveNurseId(id);
      }

      final raw = result['data'] ?? result;
      final data = raw is Map<String, dynamic> ? raw : result;
      final status = data['approval_status'] as String? ?? 'PENDING';
      final reason = data['rejection_reason'] as String? ?? '';
      _applyStatus(status, reason);
      await TokenStorage.saveApprovalStatus(status);
    } catch (e) {
      debugPrint('[STATUS] fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── WebSocket ──────────────────────────────────────────────────────────────

  Future<void> _connectWebSocket() async {
    if (_disposed) return;
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) return;

      final base = ApiConfig.baseUrl; // e.g. http://10.0.2.2:8080/api
      final wsBase = base
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://')
          .replaceAll('/api', '');
      final uri = '$wsBase/api/ws?token=${Uri.encodeComponent(token)}';

      _ws = await WebSocket.connect(uri)
          .timeout(const Duration(seconds: 10));

      if (_disposed) {
        _ws?.close();
        return;
      }

      _ws!.listen(
        _onWsMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: false,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onWsMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      if (msg['type'] == 'provider_approval') {
        final payload = msg['payload'];
        final Map<String, dynamic> p = payload is String
            ? jsonDecode(payload) as Map<String, dynamic>
            : Map<String, dynamic>.from(payload as Map);
        final newStatus = p['approval_status'] as String? ?? '';
        if (newStatus.isNotEmpty) {
          _applyStatus(newStatus, '');
          TokenStorage.saveApprovalStatus(newStatus);
        }
      }
    } catch (_) {}
  }

  void _applyStatus(String status, String reason) {
    if (!mounted) return;
    setState(() {
      _status = status;
      if (reason.isNotEmpty) _rejectionReason = reason;
    });
    if (status == 'APPROVED') {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) Get.offAllNamed('/main');
      });
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_disposed && _status == 'PENDING') _connectWebSocket();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _ws?.close();
    _pollTimer?.cancel();
    _reconnectTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    _buildStatusCard(),
                    const SizedBox(height: 32),
                    _buildStepsCard(),
                    const SizedBox(height: 32),
                    _buildActions(),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _isLoading = true);
                        _fetchStatus();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh Status'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                      ),
                    ),
                    if (_status == 'PENDING')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _ws != null
                                    ? Colors.green
                                    : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _ws != null
                                  ? 'Live — will update automatically'
                                  : 'Polling every 30s',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isApproved = _status == 'APPROVED';
    final isRejected = _status == 'REJECTED';

    Color bgColor;
    Color iconBg;
    Color iconColor;
    IconData icon;
    String title;
    String subtitle;

    if (isApproved) {
      bgColor = const Color(0xFFF0FDF4);
      iconBg = const Color(0xFFDCFCE7);
      iconColor = const Color(0xFF16A34A);
      icon = Icons.check_circle_rounded;
      title = 'Account Approved!';
      subtitle =
          'Congratulations! Your account has been verified. You can now accept bookings and start earning.';
    } else if (isRejected) {
      bgColor = const Color(0xFFFFF1F2);
      iconBg = const Color(0xFFFFE4E6);
      iconColor = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
      title = 'Verification Rejected';
      subtitle =
          'Unfortunately, your application was not approved. Please review the reason below and resubmit.';
    } else {
      bgColor = const Color(0xFFEFF6FF);
      iconBg = const Color(0xFFDBEAFE);
      iconColor = const Color(0xFF2563EB);
      icon = Icons.access_time_rounded;
      title = 'Under Review';
      subtitle =
          'Your application is being reviewed by our team. This typically takes 1-3 business days.';
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isApproved
              ? const Color(0xFFBBF7D0)
              : isRejected
                  ? const Color(0xFFFECACA)
                  : const Color(0xFFBFDBFE),
        ),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          ScaleTransition(
            scale: !isApproved && !isRejected
                ? _pulseAnimation
                : const AlwaysStoppedAnimation(1.0),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: iconColor),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF374151),
              height: 1.5,
            ),
          ),
          if (isRejected && _rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rejection Reason:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _rejectionReason,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF374151)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepsCard() {
    final steps = [
      _Step('Registration', 'Basic information submitted',
          Icons.how_to_reg_rounded, true),
      _Step('Document Upload', 'Identity & qualification documents',
          Icons.upload_file_rounded, true),
      _Step('Verification', 'Our team reviews your application',
          Icons.verified_user_rounded, _status == 'APPROVED'),
      _Step('Approval', 'Account activated for bookings',
          Icons.check_circle_rounded, _status == 'APPROVED'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Registration Progress',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: step.done
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        step.done ? Icons.check : step.icon,
                        size: 16,
                        color: step.done
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                    if (i < steps.length - 1)
                      Container(
                        width: 2,
                        height: 32,
                        color: step.done
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFE2E8F0),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: i < steps.length - 1 ? 24 : 0, top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: step.done
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                        Text(
                          step.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActions() {
    if (_status == 'APPROVED') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => Get.offAllNamed('/main'),
          icon: const Icon(Icons.dashboard_rounded),
          label: const Text(
            'Go to Dashboard',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    if (_status == 'REJECTED') {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Get.toNamed('/individual-profile'),
              icon: const Icon(Icons.edit_rounded),
              label: const Text(
                'Edit Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Get.toNamed('/doc-upload'),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Re-upload Documents'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF2563EB)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    }

    // PENDING
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await TokenStorage.clearAll();
          Get.offAllNamed('/phone');
        },
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sign Out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF64748B),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _Step {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool done;
  _Step(this.title, this.subtitle, this.icon, this.done);
}
