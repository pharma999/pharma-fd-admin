import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_care_admin/core/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class ProviderService {
  final String id;
  final String title;
  final String category;
  final double basePrice;
  final String duration;
  bool isActive;
  ServiceOffer? activeOffer;

  ProviderService({
    required this.id,
    required this.title,
    required this.category,
    required this.basePrice,
    required this.duration,
    this.isActive = true,
    this.activeOffer,
  });

  factory ProviderService.fromJson(Map<String, dynamic> j,
      {String categoryName = ''}) =>
      ProviderService(
        id: j['service_id']?.toString() ??
            j['id']?.toString() ??
            j['_id']?.toString() ??
            '',
        title: j['title']?.toString() ?? j['name']?.toString() ?? 'Service',
        category: categoryName.isNotEmpty
            ? categoryName
            : j['category_name']?.toString() ??
              j['category']?.toString() ??
              j['category_id']?.toString() ??
              '',
        basePrice: (j['base_price'] ?? j['price'] ?? 0).toDouble(),
        duration: () {
          final d = j['duration'];
          if (d == null || d == 0) return '';
          return '$d min';
        }(),
        isActive: j['is_active'] ?? true,
        activeOffer: j['offer'] != null
            ? ServiceOffer.fromJson(j['offer'])
            : null,
      );
}

class ServiceOffer {
  final String id;
  final String title;
  final int discountPct;
  final String validUntil;
  bool isActive;

  ServiceOffer({
    required this.id,
    required this.title,
    required this.discountPct,
    required this.validUntil,
    this.isActive = true,
  });

  factory ServiceOffer.fromJson(Map<String, dynamic> j) => ServiceOffer(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        discountPct: j['discount_pct'] ?? j['discount_percent'] ?? 0,
        validUntil: j['valid_until'] ?? '',
        isActive: j['is_active'] ?? true,
      );

  double discountedPrice(double basePrice) =>
      basePrice * (1 - discountPct / 100);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ProviderServicesScreen extends StatefulWidget {
  const ProviderServicesScreen({super.key});

  @override
  State<ProviderServicesScreen> createState() => _ProviderServicesScreenState();
}

class _ProviderServicesScreenState extends State<ProviderServicesScreen> {
  final List<ProviderService> _services = [];
  bool _isLoading = true;
  String _filter = 'All'; // All | Active | Offer

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    // Provider starts with empty offered-services list.
    // They use "Add Service" to pick from admin-created services.
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleService(ProviderService svc) async {
    final prev = svc.isActive;
    setState(() => svc.isActive = !prev);
    try {
      await ApiClient.patch('/provider/services/${svc.id}/toggle', {
        'is_active': svc.isActive,
      });
      Get.snackbar(
        svc.isActive ? 'Service Activated' : 'Service Deactivated',
        '"${svc.title}" is now ${svc.isActive ? 'visible' : 'hidden'} to customers.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor:
            svc.isActive ? Colors.green.shade100 : Colors.orange.shade100,
        colorText:
            svc.isActive ? Colors.green.shade900 : Colors.orange.shade900,
        duration: const Duration(seconds: 2),
      );
    } catch (_) {
      setState(() => svc.isActive = prev);
      Get.snackbar('Error', 'Failed to update service status.',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  List<ProviderService> get _filtered {
    switch (_filter) {
      case 'Active':
        return _services.where((s) => s.isActive).toList();
      case 'Offer':
        return _services.where((s) => s.activeOffer != null).toList();
      default:
        return _services;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildAppBar()],
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)))
            : RefreshIndicator(
                onRefresh: _loadServices,
                color: const Color(0xFF2563EB),
                child: _filtered.isEmpty
                    ? _buildEmpty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) => _ServiceCard(
                          service: _filtered[i],
                          onToggle: () => _toggleService(_filtered[i]),
                          onAddOffer: () => _showOfferSheet(_filtered[i]),
                          onRemoveOffer: () => _removeOffer(_filtered[i]),
                        ),
                      ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddServiceSheet,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Service',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF2563EB),
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E40AF), Color(0xFF2563EB), Color(0xFF3B82F6)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('My Services',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                '${_services.length} service${_services.length == 1 ? '' : 's'} · ${_services.where((s) => s.activeOffer != null).length} with offers',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Active', 'Offer'].map((f) {
                    final selected = _filter == f;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            color: selected
                                ? const Color(0xFF2563EB)
                                : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medical_services_outlined,
                size: 52, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 20),
          const Text('No services yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          Text(
            _filter == 'All'
                ? 'Tap "Add Service" to list your first service.'
                : 'No services match this filter.',
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Add service bottom sheet ───────────────────────────────────────────────

  // Fetches all services created by admin, filters out already-added ones
  Future<List<Map<String, dynamic>>> _fetchAdminServices() async {
    try {
      final results = await Future.wait([
        ApiClient.get('/services').catchError((_) => <String, dynamic>{}),
        ApiClient.get('/categories').catchError((_) => <String, dynamic>{}),
      ]);

      final svcRaw = results[0]['data'] ?? results[0]['services'] ?? [];
      final catRaw = results[1]['data'] ?? results[1]['categories'] ?? [];

      // Build category id → name map
      final catMap = <String, String>{};
      if (catRaw is List) {
        for (final c in catRaw) {
          if (c is Map) {
            final id = c['category_id']?.toString() ??
                c['id']?.toString() ?? c['_id']?.toString() ?? '';
            final name = c['name']?.toString() ?? '';
            if (id.isNotEmpty && name.isNotEmpty) catMap[id] = name;
          }
        }
      }

      final all = (svcRaw is List ? svcRaw : <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map((s) {
            // Embed category name so _AddServiceSheet can show it
            final catId = s['category_id']?.toString() ?? '';
            return <String, dynamic>{
              ...s,
              '_category_name': catMap[catId] ?? catId,
            };
          })
          .toList();

      // Filter out services the provider already has
      final existingIds = _services.map((s) => s.id).toSet();
      return all.where((s) {
        final id = s['service_id']?.toString() ??
            s['id']?.toString() ??
            s['_id']?.toString() ??
            '';
        return id.isNotEmpty && !existingIds.contains(id);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void _showAddServiceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddServiceSheet(
        fetchServices: _fetchAdminServices,
        onServiceAdded: (svc) {
          setState(() => _services.add(svc));
          Get.snackbar(
            'Service Added',
            '"${svc.title}" is now in your services list.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade100,
            colorText: Colors.green.shade900,
          );
        },
      ),
    );
  }

  // ── Offer bottom sheet ─────────────────────────────────────────────────────

  void _showOfferSheet(ProviderService svc) {
    final titleCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    DateTime validUntil = DateTime.now().add(const Duration(days: 7));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          final pct = int.tryParse(discountCtrl.text.trim()) ?? 0;
          final hasPreview = pct > 0 && svc.basePrice > 0;

          return Padding(
            // Lifts sheet above keyboard
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              // SingleChildScrollView ensures submit is always reachable
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.local_offer_rounded,
                              color: Colors.orange.shade700, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Create Offer',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B))),
                              Text(svc.title,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Offer title field
                    TextField(
                      controller: titleCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Offer Title',
                        hintText: 'e.g. Diwali Special, Weekend Deal',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      onChanged: (_) => setModal(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Discount field
                    TextField(
                      controller: discountCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Discount (%)',
                        hintText: '10',
                        suffixText: '%',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      onChanged: (_) => setModal(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Date picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: validUntil,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setModal(() => validUntil = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 18, color: Color(0xFF64748B)),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Valid Until',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8))),
                                Text(
                                  '${validUntil.day}/${validUntil.month}/${validUntil.year}',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.chevron_right,
                                color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),

                    // Live price preview — updates on every keystroke
                    if (hasPreview) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: Colors.green, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Customer pays ₹${(svc.basePrice * (1 - pct / 100)).toStringAsFixed(0)} instead of ₹${svc.basePrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF166534),
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Submit button — always visible, always reachable
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (titleCtrl.text.trim().isEmpty) {
                            setModal(() {});
                            Get.snackbar('Missing Title',
                                'Please enter an offer title.',
                                snackPosition: SnackPosition.BOTTOM);
                            return;
                          }
                          if (pct <= 0 || pct > 90) {
                            Get.snackbar('Invalid Discount',
                                'Discount must be between 1% and 90%.',
                                snackPosition: SnackPosition.BOTTOM);
                            return;
                          }
                          Navigator.pop(ctx);
                          try {
                            await ApiClient.post(
                                '/provider/services/${svc.id}/offer', {
                              'title': titleCtrl.text.trim(),
                              'discount_pct': pct,
                              'valid_until': validUntil.toIso8601String(),
                            });
                            await _loadServices();
                            Get.snackbar('Offer Created',
                                '$pct% off applied to "${svc.title}".',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.green.shade100,
                                colorText: Colors.green.shade900);
                          } catch (_) {
                            // Optimistic local update when API not ready
                            setState(() {
                              svc.activeOffer = ServiceOffer(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                title: titleCtrl.text.trim(),
                                discountPct: pct,
                                validUntil: validUntil.toIso8601String(),
                              );
                            });
                            Get.snackbar('Offer Applied',
                                '$pct% off applied to "${svc.title}".',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.green.shade100,
                                colorText: Colors.green.shade900);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_offer_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Create Offer',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _removeOffer(ProviderService svc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Offer'),
        content: Text(
            'Remove the offer from "${svc.title}"? Customers will see the full price again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient.delete(
          '/provider/services/${svc.id}/offer/${svc.activeOffer?.id}');
    } catch (_) {}
    setState(() => svc.activeOffer = null);
    Get.snackbar('Offer Removed', 'Offer has been removed from "${svc.title}".',
        snackPosition: SnackPosition.BOTTOM);
  }

}

// ── Service card ──────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final ProviderService service;
  final VoidCallback onToggle;
  final VoidCallback onAddOffer;
  final VoidCallback onRemoveOffer;

  const _ServiceCard({
    required this.service,
    required this.onToggle,
    required this.onAddOffer,
    required this.onRemoveOffer,
  });

  @override
  Widget build(BuildContext context) {
    final hasOffer = service.activeOffer != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasOffer
              ? Colors.orange.shade200
              : const Color(0xFFE2E8F0),
          width: hasOffer ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.medical_services_outlined,
                      color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 12),
                // Title + category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B))),
                      const SizedBox(height: 2),
                      Text(service.category,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                // Active toggle
                Switch(
                  value: service.isActive,
                  onChanged: (_) => onToggle(),
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF2563EB),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFCBD5E1),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),

          // ── Price row ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                if (hasOffer) ...[
                  Text(
                    '₹${service.activeOffer!.discountedPrice(service.basePrice).toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₹${service.basePrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                        decoration: TextDecoration.lineThrough),
                  ),
                ] else
                  Text(
                    '₹${service.basePrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B)),
                  ),
                const Spacer(),
                if (service.duration.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.schedule_outlined,
                          size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(service.duration,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
              ],
            ),
          ),

          // ── Active offer banner ─────────────────────────────────────────
          if (hasOffer) ...[
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_offer_rounded,
                      color: Colors.orange.shade700, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${service.activeOffer!.discountPct}% OFF · ${service.activeOffer!.title}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800),
                    ),
                  ),
                  GestureDetector(
                    onTap: onRemoveOffer,
                    child: Icon(Icons.close_rounded,
                        size: 16, color: Colors.orange.shade700),
                  ),
                ],
              ),
            ),
          ],

          // ── Action buttons ──────────────────────────────────────────────
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _ActionBtn(
                  icon: Icons.local_offer_outlined,
                  label: hasOffer ? 'Edit Offer' : 'Add Offer',
                  color: Colors.orange.shade700,
                  onTap: onAddOffer,
                ),
                const SizedBox(width: 4),
                _ActionBtn(
                  icon: Icons.bar_chart_rounded,
                  label: 'Stats',
                  color: const Color(0xFF7C3AED),
                  onTap: () => _showStatsSheet(context),
                ),
                const SizedBox(width: 4),
                _ActionBtn(
                  icon: service.isActive
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  label: service.isActive ? 'Hide' : 'Show',
                  color: service.isActive
                      ? const Color(0xFF64748B)
                      : const Color(0xFF16A34A),
                  onTap: onToggle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStatsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Stats — ${service.title}',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 20),
            Row(
              children: [
                _StatPill('Total Bookings', '—', const Color(0xFF2563EB)),
                const SizedBox(width: 12),
                _StatPill('This Month', '—', const Color(0xFF16A34A)),
                const SizedBox(width: 12),
                _StatPill('Revenue', '—', const Color(0xFFEA580C)),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Detailed analytics will appear here once you start receiving bookings for this service.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: Icon(icon, size: 15, color: color),
        label: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF64748B)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Add Service Sheet — picks from admin-created services ─────────────────────

class _AddServiceSheet extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() fetchServices;
  final void Function(ProviderService svc) onServiceAdded;

  const _AddServiceSheet({
    required this.fetchServices,
    required this.onServiceAdded,
  });

  @override
  State<_AddServiceSheet> createState() => _AddServiceSheetState();
}

class _AddServiceSheetState extends State<_AddServiceSheet> {
  List<Map<String, dynamic>> _available = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _search = '';
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.fetchServices();
    if (mounted) {
      setState(() {
        _available = list;
        _filtered = list;
        _loading = false;
      });
    }
  }

  void _onSearch(String q) {
    setState(() {
      _search = q;
      _filtered = q.isEmpty
          ? _available
          : _available
              .where((s) =>
                  (s['title'] ?? '').toLowerCase().contains(q.toLowerCase()) ||
                  (s['category'] ?? '').toLowerCase().contains(q.toLowerCase()))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Add a Service',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose from services created by the admin.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  TextField(
                    onChanged: _onSearch,
                    decoration: InputDecoration(
                      hintText: 'Search services...',
                      prefixIcon: const Icon(Icons.search, size: 20,
                          color: Color(0xFF2563EB)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // List
            Flexible(
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                            color: Color(0xFF2563EB)),
                      ),
                    )
                  : _filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.medical_services_outlined,
                                  size: 52, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                _search.isNotEmpty
                                    ? 'No services match "$_search"'
                                    : 'All available services have been added.\nAsk your admin to create more.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0xFF64748B), fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final svc = _filtered[i];
                            final isSelected = _selected == svc;
                            final title = svc['title']?.toString() ??
                                svc['name']?.toString() ??
                                'Service ${i + 1}';
                            final catName =
                                svc['_category_name']?.toString() ?? '';
                            final price =
                                (svc['base_price'] ?? svc['price'] ?? 0)
                                    .toDouble();
                            final dur = svc['duration'] ?? 0;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selected = isSelected ? null : svc),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFEFF6FF)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFE2E8F0),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Checkbox-style indicator
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? const Color(0xFF2563EB)
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF2563EB)
                                              : Colors.grey.shade400,
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check,
                                              color: Colors.white, size: 14)
                                          : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Service name — always visible
                                          Text(
                                            title,
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected
                                                    ? const Color(0xFF2563EB)
                                                    : const Color(0xFF1E293B)),
                                          ),
                                          if (catName.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(catName,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF64748B))),
                                          ],
                                          const SizedBox(height: 4),
                                          Text(
                                            [
                                              if (price > 0)
                                                '₹${price.toStringAsFixed(0)}',
                                              if (dur > 0) '$dur min',
                                            ].join('  ·  '),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle_rounded,
                                          color: Color(0xFF2563EB), size: 22),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Submit button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _selected == null
                      ? null
                      : () {
                          final s = _selected!;
                          final id = s['service_id']?.toString() ??
                              s['id']?.toString() ??
                              s['_id']?.toString() ??
                              '';
                          final price =
                              (s['base_price'] ?? s['price'] ?? 0).toDouble();
                          final dur = s['duration'] ?? 0;
                          final catName = s['_category_name']?.toString() ??
                              s['category_name']?.toString() ??
                              s['category_id']?.toString() ??
                              '';
                          final newSvc = ProviderService(
                            id: id,
                            title: s['title']?.toString() ?? '',
                            category: catName,
                            basePrice: price,
                            duration: dur > 0 ? '$dur min' : '',
                            isActive: true,
                          );
                          Navigator.pop(context);
                          widget.onServiceAdded(newSvc);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _selected == null
                        ? 'Select a service above'
                        : 'Add "${_selected!['title']}"',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
