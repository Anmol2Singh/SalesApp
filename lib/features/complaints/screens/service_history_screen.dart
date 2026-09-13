// lib/features/complaints/screens/service_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/complaints_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/models/user_role.dart';

class ServiceHistoryScreen extends ConsumerStatefulWidget {
  const ServiceHistoryScreen({super.key});

  @override
  ConsumerState<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends ConsumerState<ServiceHistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final complaints = ref.watch(complaintsProvider);
    final profile = ref.watch(currentProfileProvider);
    
    var history = complaints.where((c) => c.status == 'closed' || c.status == 'resolved').toList();
    
    final isTech = profile?.roles.contains(UserRole.technician) == true;
    final canViewAll = profile?.roles.contains(UserRole.admin) == true || 
                       profile?.roles.contains(UserRole.manager) == true || 
                       profile?.roles.contains(UserRole.serviceHead) == true;

    if (isTech && !canViewAll) {
      final pName = profile!.fullName.toLowerCase();
      history = history.where((c) {
        final tName = c.technicianName?.toLowerCase() ?? '';
        return tName.contains(pName) || pName.contains(tName) || c.technicianId == profile.id;
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
                (c.productName?.toLowerCase().contains(query) ?? false) ||
                (c.errorCode?.toLowerCase().contains(query) ?? false);
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back to Complaints Dashboard',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go('/complaints/dashboard');
            }
          },
        ),
        title: const Text(
          'Service History',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1B4B),
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
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6D28D9)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchController.clear()),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: filteredHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          history.isEmpty
                              ? 'No completed service records yet'
                              : 'No service records matching "$query"',
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      final item = filteredHistory[index];
                      final isClosed = item.status == 'closed';
                      return GestureDetector(
                        onTap: () => context.push('/complaints/details/${item.id}'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.ticketNumber,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                                  ),
                                  Chip(
                                    label: Text(
                                      isClosed ? 'CLOSED' : 'RESOLVED',
                                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: isClosed ? const Color(0xFF10B981) : const Color(0xFF6D28D9),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.title,
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text('Customer: ${item.customerName}', style: const TextStyle(fontSize: 13)),
                              Text('Technician: ${item.technicianName ?? "Unassigned"}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              if (item.productName != null && item.productName!.isNotEmpty)
                                Text('Product: ${item.productName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
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
