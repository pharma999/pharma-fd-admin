import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';
import '../models/models.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final ctrl = Get.find<AdminController>();
  String _filter = '';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    ctrl.fetchBookings();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminBooking> get _filtered {
    var list = ctrl.bookings.toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((b) =>
              b.serviceName.toLowerCase().contains(q) ||
              b.id.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Bookings',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFEF6C00),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: ctrl.fetchBookings,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search by service or booking ID…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          // Status filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['', 'PENDING', 'ACCEPTED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s.isEmpty ? 'All' : s,
                                style: const TextStyle(fontSize: 12)),
                            selected: _filter == s,
                            selectedColor:
                                const Color(0xFFEF6C00).withValues(alpha: 0.15),
                            onSelected: (_) {
                              setState(() => _filter = s);
                              ctrl.fetchBookings(status: s.isEmpty ? null : s);
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              if (ctrl.loadingBookings.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = _filtered;
              if (list.isEmpty) {
                return _EmptyState(
                  icon: Icons.bookmark_border,
                  title: _searchQuery.isNotEmpty
                      ? 'No bookings match "$_searchQuery"'
                      : _filter.isNotEmpty
                          ? 'No $_filter bookings'
                          : 'No bookings yet',
                  subtitle: 'Bookings will appear here once placed',
                );
              }
              return RefreshIndicator(
                onRefresh: ctrl.fetchBookings,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) =>
                      _BookingTile(b: list[i], ctrl: ctrl),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  final AdminBooking b;
  final AdminController ctrl;
  const _BookingTile({required this.b, required this.ctrl});

  Color _statusColor(String s) {
    switch (s) {
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'ACCEPTED':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _confirmAction(BuildContext ctx, String label, Color color,
      String newStatus) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('$label Booking'),
        content: Text(
            'Mark "${b.serviceName}" as $newStatus?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ctrl.updateBooking(b.id, newStatus);
            },
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: Text(label,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Text(b.serviceName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14))),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(b.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(b.status,
                    style: TextStyle(
                        fontSize: 11,
                        color: _statusColor(b.status),
                        fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 4),
            Text('₹${b.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF6C00))),
            Text(
                'Scheduled: ${b.scheduledAt.length > 10 ? b.scheduledAt.substring(0, 10) : b.scheduledAt}',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
            Text('ID: ${b.id.length > 8 ? b.id.substring(0, 8) : b.id}…',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade400)),
            if (b.isActive) ...[
              const SizedBox(height: 10),
              Row(children: [
                _Btn('Accept', Colors.green,
                    () => ctrl.updateBooking(b.id, 'ACCEPTED')),
                const SizedBox(width: 8),
                _Btn('Complete', Colors.blue,
                    () => ctrl.updateBooking(b.id, 'COMPLETED')),
                const SizedBox(width: 8),
                _Btn('Cancel', Colors.red,
                    () => _confirmAction(
                        context, 'Cancel', Colors.red, 'CANCELLED')),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Btn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}
