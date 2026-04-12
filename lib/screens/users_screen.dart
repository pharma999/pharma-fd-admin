import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';
import '../models/models.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final ctrl = Get.find<AdminController>();
  final _searchCtrl = TextEditingController();
  final _roles = ['', 'PATIENT', 'DOCTOR', 'NURSE', 'CAREGIVER', 'HOSPITAL'];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    ctrl.fetchUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminUser> get _filtered {
    if (_searchQuery.isEmpty) return ctrl.users;
    final q = _searchQuery.toLowerCase();
    return ctrl.users.where((u) {
      return u.name.toLowerCase().contains(q) ||
          u.phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF26A69A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: ctrl.fetchUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search by name, phone or email…',
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
          // Role filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Obx(() => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _roles
                        .map((r) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(r.isEmpty ? 'All' : r,
                                    style: const TextStyle(fontSize: 12)),
                                selected: ctrl.userRoleFilter.value == r,
                                selectedColor:
                                    const Color(0xFF26A69A).withValues(alpha: 0.15),
                                checkmarkColor: const Color(0xFF26A69A),
                                onSelected: (_) {
                                  ctrl.userRoleFilter.value = r;
                                  ctrl.fetchUsers(role: r.isEmpty ? null : r);
                                },
                              ),
                            ))
                        .toList(),
                  ),
                )),
          ),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              if (ctrl.loadingUsers.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = _filtered;
              if (list.isEmpty) {
                return _EmptyState(
                  icon: Icons.people_outline,
                  title: _searchQuery.isNotEmpty
                      ? 'No users match "$_searchQuery"'
                      : 'No users found',
                  subtitle: _searchQuery.isNotEmpty
                      ? 'Try a different search term'
                      : 'Users will appear here once they register',
                );
              }
              return RefreshIndicator(
                onRefresh: ctrl.fetchUsers,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) =>
                      _UserTile(user: list[i], ctrl: ctrl),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final AdminUser user;
  final AdminController ctrl;
  const _UserTile({required this.user, required this.ctrl});

  Color get _roleColor {
    switch (user.role) {
      case 'DOCTOR':
        return Colors.purple;
      case 'NURSE':
        return Colors.teal;
      case 'HOSPITAL':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  void _confirmToggleBlock(BuildContext ctx) {
    final willBlock = !user.isBlocked;
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(willBlock ? 'Block User' : 'Unblock User'),
        content: Text(willBlock
            ? 'Block ${user.name.isEmpty ? user.phone : user.name}? They will not be able to log in.'
            : 'Unblock ${user.name.isEmpty ? user.phone : user.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ctrl.blockUser(user.id, willBlock);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: willBlock ? Colors.red : Colors.green),
            child: Text(willBlock ? 'Block' : 'Unblock',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: _roleColor.withValues(alpha: 0.15),
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            style: TextStyle(
                color: _roleColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(user.name.isEmpty ? user.phone : user.name,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.phone,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Row(children: [
              _badge(user.role, _roleColor),
              if (user.isBlocked) ...[
                const SizedBox(width: 6),
                _badge('BLOCKED', Colors.red),
              ],
            ]),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            user.isBlocked ? Icons.lock_open : Icons.lock,
            color: user.isBlocked ? Colors.green : Colors.red,
          ),
          tooltip: user.isBlocked ? 'Unblock' : 'Block',
          onPressed: () => _confirmToggleBlock(context),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold)),
      );
}

// ── Reusable empty state ───────────────────────────────────────────────────

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
