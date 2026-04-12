import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';
import '../models/models.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final ctrl = Get.find<AdminController>();

  @override
  void initState() {
    super.initState();
    ctrl.fetchPlans();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Plans',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF00897B),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _createDialog(context),
          ),
        ],
      ),
      body: Obx(() {
        if (ctrl.loadingPlans.value) return const Center(child: CircularProgressIndicator());
        if (ctrl.plans.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.card_membership, size: 60, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('No plans yet'),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => _createDialog(context), child: const Text('Create Plan')),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ctrl.plans.length,
          itemBuilder: (_, i) => _PlanCard(plan: ctrl.plans[i], ctrl: ctrl),
        );
      }),
    );
  }

  void _createDialog(BuildContext ctx) {
    final nameC = TextEditingController();
    final descC = TextEditingController();
    final priceC = TextEditingController();
    final bookC = TextEditingController(text: '10');
    final famC = TextEditingController(text: '5');
    String dur = 'MONTHLY';

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (_, ss) => AlertDialog(
          title: const Text('New Subscription Plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(nameC, 'Plan Name'),
                _field(descC, 'Description'),
                _field(priceC, 'Price (₹)', num: true),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: dur,
                  decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()),
                  items: ['MONTHLY', 'QUARTERLY', 'YEARLY'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => ss(() => dur = v!),
                ),
                const SizedBox(height: 8),
                _field(bookC, 'Max Bookings', num: true),
                _field(famC, 'Max Family Members', num: true),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                ctrl.createPlan({
                  'name': nameC.text,
                  'description': descC.text,
                  'price': double.tryParse(priceC.text) ?? 0,
                  'duration': dur,
                  'max_bookings': int.tryParse(bookC.text) ?? 10,
                  'max_family_members': int.tryParse(famC.text) ?? 5,
                });
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool num = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          keyboardType: num ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );
}

class _PlanCard extends StatelessWidget {
  final AdminPlan plan;
  final AdminController ctrl;
  const _PlanCard({required this.plan, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              Switch(
                value: plan.isActive,
                onChanged: (v) => ctrl.togglePlan(plan.id, v),
              ),
            ]),
            Text('₹${plan.price.toInt()} / ${plan.duration}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF00897B))),
            if (plan.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(plan.description, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            if (plan.features.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: plan.features.map((f) => Chip(
                  label: Text(f, style: const TextStyle(fontSize: 11)),
                  backgroundColor: const Color(0xFF00897B).withValues(alpha: 0.08),
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.bookmark, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${plan.maxBookings} bookings', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(width: 12),
              const Icon(Icons.family_restroom, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${plan.maxFamilyMembers} family', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => ctrl.deletePlan(plan.id),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
