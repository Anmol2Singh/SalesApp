// lib/features/complaints/screens/service_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/complaints_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/models/user_role.dart';

class ServiceHistoryScreen extends ConsumerWidget {
  const ServiceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Service History',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1B4B),
        elevation: 0,
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'No completed service records yet',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return GestureDetector(
                  onTap: () => context.push('/complaints/details/${item.id}'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
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
                          const Chip(
                            label: Text('RESOLVED', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                            backgroundColor: Color(0xFF10B981),
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
                      Text('Customer: ${item.customerName}'),
                      Text('Technician: ${item.technicianName ?? "Marcus Vance"}'),
                    ],
                  ), // Closes Column
                ), // Closes Container
              ); // Closes GestureDetector
            },
          ),
    );
  }
}
