// lib/features/complaints/screens/assign_technician_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/complaints_provider.dart';
import '../data/models/complaint_model.dart';

class AssignTechnicianScreen extends ConsumerWidget {
  const AssignTechnicianScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaints = ref.watch(complaintsProvider);
    final isLoading = ref.watch(complaintsLoadingProvider);
    final pendingComplaints = complaints.where((c) => c.status != 'closed' && c.status != 'resolved').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Assign Technicians',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1B4B),
        elevation: 0,
      ),
      body: isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (context, index) => _buildSkeletonCard(),
            )
          : pendingComplaints.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 64, color: Color(0xFF10B981)),
                      const SizedBox(height: 12),
                      const Text(
                        'All complaints have been dispatched!',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No pending tickets requiring technician allocation.',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pendingComplaints.length,
              itemBuilder: (context, index) {
                final complaint = pendingComplaints[index];
                final techniciansAsync = ref.watch(availableTechniciansProvider);
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Chip(
                            label: Text(
                              complaint.ticketNumber,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            backgroundColor: const Color(0xFF6D28D9),
                            visualDensity: VisualDensity.compact,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              complaint.priority,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        complaint.title,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customer: ${complaint.customerName} • ${complaint.customerPhone}',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        'Location: ${complaint.customerAddress}',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey),
                      ),
                      if (complaint.technicianName != null && complaint.technicianName!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6D28D9).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF6D28D9).withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_pin, size: 16, color: Color(0xFF6D28D9)),
                              const SizedBox(width: 6),
                              Text(
                                'Assigned to: ${complaint.technicianName}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6D28D9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Divider(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (complaint.technicianName != null && complaint.technicianName!.isNotEmpty)
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF6D28D9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(
                            (complaint.technicianName != null && complaint.technicianName!.isNotEmpty)
                                ? Icons.sync_alt
                                : Icons.person_add_alt_1_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: Text(
                            (complaint.technicianName != null && complaint.technicianName!.isNotEmpty)
                                ? 'Reassign Technician'
                                : 'Select Technician',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            _showAssignModal(context, ref, complaint, techniciansAsync);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _showAssignModal(BuildContext context, WidgetRef ref, Complaint complaint, AsyncValue<List<TechnicianInfo>> techniciansAsync) {
    final isReassign = complaint.technicianName != null && complaint.technicianName!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isReassign
                    ? 'Reassign Technician for ${complaint.ticketNumber}'
                    : 'Assign Technician for ${complaint.ticketNumber}',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                isReassign
                    ? 'Currently with ${complaint.technicianName}. Choose a replacement technician:'
                    : 'Available staff members from database',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              techniciansAsync.when(
                data: (allTechnicians) {
                  // Filter out the currently assigned technician
                  final technicians = allTechnicians.where((tech) => tech.name != complaint.technicianName).toList();
                  
                  if (technicians.isEmpty) {
                    return const Center(
                      child: Text('No available technicians at this time.'),
                    );
                  }
                  return Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: technicians.length,
                      itemBuilder: (context, idx) {
                        final tech = technicians[idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          
                          title: Text(tech.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${tech.status} • ${tech.distance}'),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D28D9)),
                            onPressed: () {
                              ref.read(complaintsProvider.notifier).assignTechnician(complaint.id, tech);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Ticket ${complaint.ticketNumber} assigned to ${tech.name}!'),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            },
                            child: const Text('Assign', style: TextStyle(color: Colors.white)),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9))),
                error: (e, _) => Text('Error loading technicians: $e'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
              Container(width: 80, height: 20, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6))),
              Container(width: 60, height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6))),
            ],
          ),
          const SizedBox(height: 12),
          Container(width: 180, height: 16, color: Colors.grey.shade200),
          const SizedBox(height: 8),
          Container(width: 140, height: 12, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Container(width: double.infinity, height: 38, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10))),
        ],
      ),
    );
  }
}
