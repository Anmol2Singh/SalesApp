// lib/features/installations/screens/assign_technician_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/installations_provider.dart';
import '../data/models/installation_model.dart';
import '../../complaints/providers/complaints_provider.dart'
    show availableTechniciansProvider;
import '../../complaints/data/models/complaint_model.dart' show TechnicianInfo;

class AssignInstallationTechnicianScreen extends ConsumerWidget {
  const AssignInstallationTechnicianScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installations = ref.watch(installationsProvider);
    final isLoading = ref.watch(installationsLoadingProvider);
    final profile = ref.watch(currentProfileProvider);
    final isMultiRole = (profile?.roles.length ?? 0) > 1;
    final pendingInstallations = installations
        .where((c) => c.status != 'closed' && c.status != 'resolved')
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Assign Installers',
          style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          if (isMultiRole)
            IconButton(
              icon: const Icon(Icons.engineering_outlined, color: Colors.white),
              tooltip: 'Manage Technicians',
              onPressed: () => context.push('/complaints/technicians'),
            ),
        ],
      ),
      body: isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (context, index) => _buildSkeletonCard(),
            )
          : pendingInstallations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 64, color: Color(0xFF10B981)),
                      const SizedBox(height: 12),
                      const Text(
                        'All installations allocated!',
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No pending jobs requiring technician allocation.',
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pendingInstallations.length,
                  itemBuilder: (context, index) {
                    final installation = pendingInstallations[index];
                    final techniciansAsync =
                        ref.watch(availableTechniciansProvider);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
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
                                  installation.ticketNumber,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11),
                                ),
                                backgroundColor: const Color(0xFF0284C7),
                                visualDensity: VisualDensity.compact,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: installation.priority == 'High Priority'
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  installation.priority,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        installation.priority == 'High Priority'
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            installation.title,
                            style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${installation.customerName} • ${installation.customerAddress}',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Colors.grey.shade600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Divider(height: 24),
                          techniciansAsync.when(
                            data: (technicians) => _buildTechnicianSelector(
                                context, ref, installation, technicians),
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text('Error loading technicians: $e'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildTechnicianSelector(
    BuildContext context,
    WidgetRef ref,
    Installation installation,
    List<TechnicianInfo> technicians,
  ) {
    TechnicianInfo? selectedTech;
    if (installation.technicianId != null) {
      try {
        selectedTech =
            technicians.firstWhere((t) => t.id == installation.technicianId);
      } catch (_) {
        if (installation.technicianName != null) {
          try {
            selectedTech = technicians
                .firstWhere((t) => t.name == installation.technicianName);
          } catch (_) {}
        }
      }
    }

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<TechnicianInfo>(
            value: selectedTech,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              hintText: 'Select Technician',
              hintStyle: const TextStyle(fontSize: 13),
            ),
            items: technicians.map((tech) {
              return DropdownMenuItem<TechnicianInfo>(
                value: tech,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.2),
                      child: Text(
                        tech.name.isNotEmpty ? tech.name[0] : '?',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0284C7)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(tech.name, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (tech) {
              if (tech != null) {
                ref
                    .read(installationsProvider.notifier)
                    .assignTechnician(installation.id, tech);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Assigned ${tech.name} to ${installation.ticketNumber}'),
                    backgroundColor: const Color(0xFF10B981),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
