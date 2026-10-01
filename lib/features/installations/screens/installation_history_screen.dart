// lib/features/installations/screens/installation_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/installations_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/models/user_role.dart';

class InstallationHistoryScreen extends ConsumerStatefulWidget {
  const InstallationHistoryScreen({super.key});

  @override
  ConsumerState<InstallationHistoryScreen> createState() =>
      _InstallationHistoryScreenState();
}

class _InstallationHistoryScreenState
    extends ConsumerState<InstallationHistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final installations = ref.watch(installationsProvider);
    final profile = ref.watch(currentProfileProvider);

    var history = installations
        .where((c) => c.status == 'closed' || c.status == 'resolved')
        .toList();

    final isTech = profile?.roles.contains(UserRole.technician) == true;
    final canViewAll = profile?.roles.contains(UserRole.admin) == true ||
        profile?.roles.contains(UserRole.manager) == true ||
        profile?.roles.contains(UserRole.serviceHead) == true;

    if (isTech && !canViewAll) {
      final pName = profile!.fullName.toLowerCase();
      history = history.where((c) {
        final tName = c.technicianName?.toLowerCase() ?? '';
        return tName.contains(pName) ||
            pName.contains(tName) ||
            c.technicianId == profile.id;
      }).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    final filteredHistory = query.isEmpty
        ? history
        : history.where((c) {
            return c.ticketNumber.toLowerCase().contains(query) ||
                c.customerName.toLowerCase().contains(query) ||
                (c.technicianName?.toLowerCase().contains(query) ?? false) ||
                c.title.toLowerCase().contains(query) ||
                (c.productName?.toLowerCase().contains(query) ?? false);
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back to Dashboard',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go('/installations/dashboard');
            }
          },
        ),
        title: const Text(
          'Installation History',
          style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search ticket, customer, technician, product...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0284C7)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            setState(() => _searchController.clear()),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: filteredHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off_rounded,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No completed installations found',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      final item = filteredHistory[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE0F2FE),
                            child: Icon(Icons.done_all_rounded,
                                color: Color(0xFF0284C7)),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.ticketNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                ),
                              ),
                              const Text(
                                'COMPLETED',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Customer: ${item.customerName}'),
                              if (item.technicianName != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Technician: ${item.technicianName}',
                                  style: const TextStyle(
                                      color: Color(0xFF0284C7),
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                              if (item.productName != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Product: ${item.productName}',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ],
                          ),
                          onTap: () =>
                              context.push('/installations/details/${item.id}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
