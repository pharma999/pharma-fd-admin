import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';
import '../models/models.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});
  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final ctrl = Get.find<AdminController>();

  @override
  void initState() {
    super.initState();
    ctrl.fetchTickets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Tickets',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF7B1FA2),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Obx(() => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['', 'OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED']
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(s.isEmpty ? 'All' : s),
                                selected: ctrl.ticketFilter.value == s,
                                onSelected: (_) {
                                  ctrl.ticketFilter.value = s;
                                  ctrl.fetchTickets(status: s.isEmpty ? null : s);
                                },
                              ),
                            ))
                        .toList(),
                  ),
                )),
          ),
          Expanded(
            child: Obx(() {
              if (ctrl.loadingTickets.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (ctrl.tickets.isEmpty) {
                return const Center(child: Text('No tickets'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: ctrl.tickets.length,
                itemBuilder: (_, i) =>
                    _TicketCard(t: ctrl.tickets[i], ctrl: ctrl),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final AdminTicket t;
  final AdminController ctrl;
  const _TicketCard({required this.t, required this.ctrl});

  Color _priorityColor(String p) {
    switch (p) {
      case 'CRITICAL': return Colors.red;
      case 'HIGH': return Colors.orange;
      case 'MEDIUM': return Colors.amber.shade700;
      default: return Colors.grey;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'OPEN': return Colors.blue;
      case 'IN_PROGRESS': return Colors.orange;
      case 'RESOLVED': return Colors.green;
      default: return Colors.grey;
    }
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
              Expanded(child: Text(t.subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _priorityColor(t.priority).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(t.priority, style: TextStyle(fontSize: 10, color: _priorityColor(t.priority), fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 4),
            Text('${t.userName} • ${t.userPhone}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text('Category: ${t.category}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 6),
            Text(t.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(t.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(t.status, style: TextStyle(fontSize: 11, color: _statusColor(t.status), fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              if (t.isOpen)
                TextButton(
                  onPressed: () => _resolveDialog(context),
                  child: const Text('Resolve', style: TextStyle(color: Color(0xFF7B1FA2))),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  void _resolveDialog(BuildContext ctx) {
    final resCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Resolve Ticket'),
        content: TextField(
          controller: resCtrl,
          decoration: const InputDecoration(hintText: 'Resolution note...', border: OutlineInputBorder()),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ctrl.resolveTicket(t.id, resCtrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
  }
}
