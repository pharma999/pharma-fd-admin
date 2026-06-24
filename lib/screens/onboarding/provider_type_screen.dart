import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_care_admin/core/token_storage.dart';

class ProviderTypeScreen extends StatelessWidget {
  const ProviderTypeScreen({super.key});

  Future<void> _choose(String type) async {
    await TokenStorage.saveProviderType(type);
    if (type == 'INDIVIDUAL') {
      Get.toNamed('/individual-profile');
    } else {
      Get.toNamed('/org-profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                const Icon(Icons.waving_hand, color: Colors.white70, size: 32),
                const SizedBox(height: 12),
                const Text(
                  "Choose how you\nwant to provide",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Select the type that best describes you",
                  style: TextStyle(fontSize: 15, color: Colors.white70),
                ),
                const SizedBox(height: 40),
                _TypeCard(
                  icon: Icons.person_outline_rounded,
                  title: 'Individual Service Provider',
                  subtitle:
                      'Nurse, caregiver, physiotherapist or any individual healthcare professional',
                  color: const Color(0xFF2563EB),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                  ),
                  features: const [
                    'Flexible working hours',
                    'Set your own rates',
                    'Build your profile',
                  ],
                  onTap: () => _choose('INDIVIDUAL'),
                ),
                const SizedBox(height: 20),
                _TypeCard(
                  icon: Icons.business_outlined,
                  title: 'Service Provider Organization',
                  subtitle:
                      'Agency, medical center, clinic or any healthcare organization',
                  color: const Color(0xFF7C3AED),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
                  ),
                  features: const [
                    'Manage your team',
                    'Bulk service offerings',
                    'Organization dashboard',
                  ],
                  onTap: () => _choose('ORGANIZATION'),
                ),
                const SizedBox(height: 32),
                Center(
                  child: TextButton(
                    onPressed: () async {
                      await TokenStorage.clearAll();
                      Get.offAllNamed('/phone');
                    },
                    child: const Text(
                      'Use a different account',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final LinearGradient gradient;
  final List<String> features;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.gradient,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child:
                        Icon(icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ...features.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: color, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              f,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Get Started',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
