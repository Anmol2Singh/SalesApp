// lib/features/complaints/screens/technicians_tab_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/complaints_provider.dart';
import '../data/models/complaint_model.dart';
import '../../../core/providers/supabase_provider.dart';

import '../../../core/models/user_role.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/router/app_router.dart';
import 'package:go_router/go_router.dart';

class TechniciansTabScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const TechniciansTabScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<TechniciansTabScreen> createState() => _TechniciansTabScreenState();
}

class _TechniciansTabScreenState extends ConsumerState<TechniciansTabScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authControllerProvider.notifier).signOut();
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddTechnicianDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.person_add, color: Color(0xFF6D28D9)),
                  SizedBox(width: 8),
                  Text('Add New Technician', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Technician Full Name *', prefixIcon: Icon(Icons.person)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email Address *', prefixIcon: Icon(Icons.email)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Mobile Phone', prefixIcon: Icon(Icons.phone)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D28D9)),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final email = emailController.text.trim();
                          final phone = phoneController.text.trim();
                          final pwd = passwordController.text.trim();

                          if (name.isEmpty || email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Name and email are required.')),
                            );
                            return;
                          }

                          setModalState(() => isSaving = true);
                          try {
                            final supabase = ref.read(supabaseClientProvider);
                            await supabase.from('technicians').insert({
                              'name': name,
                              'email': email,
                              'phone': phone,
                              'status': 'Available',
                              'rating': 4.9,
                              'active_tasks_count': 0,
                            });

                            try {
                              await supabase.from('profiles').insert({
                                'full_name': name,
                                'email': email,
                                'phone': phone,
                                'role': 'technician',
                                'roles': ['technician'],
                                'is_active': true,
                              });
                            } catch (_) {}

                            ref.invalidate(availableTechniciansProvider);
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Technician added successfully!'), backgroundColor: Color(0xFF10B981)),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error adding technician: $e'), backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            setModalState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Add Technician', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditTechnicianDialog(TechnicianInfo tech) {
    final nameController = TextEditingController(text: tech.name);
    final emailController = TextEditingController(text: tech.email ?? '');
    final phoneController = TextEditingController(text: tech.phone ?? '');
    final passwordController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.edit, color: Color(0xFF6D28D9)),
                  SizedBox(width: 8),
                  Text('Edit Technician', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Technician Full Name *', prefixIcon: Icon(Icons.person)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email Address *', prefixIcon: Icon(Icons.email)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Mobile Phone', prefixIcon: Icon(Icons.phone)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'New Password (Optional)', prefixIcon: Icon(Icons.lock_outline)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D28D9)),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final email = emailController.text.trim();
                          final phone = phoneController.text.trim();
                          final pwd = passwordController.text.trim();

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Name is required.')),
                            );
                            return;
                          }

                          setModalState(() => isSaving = true);
                          try {
                            final supabase = ref.read(supabaseClientProvider);
                            final updates = <String, dynamic>{
                              'name': name,
                              'email': email,
                              'phone': phone,
                            };
                            if (pwd.isNotEmpty) updates['password'] = pwd;

                            if (tech.id.isNotEmpty) {
                              await supabase.from('technicians').update(updates).eq('id', tech.id);
                            } else {
                              await supabase.from('technicians').update(updates).eq('name', tech.name);
                            }

                            ref.invalidate(availableTechniciansProvider);
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Technician updated successfully!'), backgroundColor: Color(0xFF10B981)),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error updating technician: $e'), backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            setModalState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteTechnician(TechnicianInfo tech) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Technician'),
        content: Text('Are you sure you want to delete ${tech.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final supabase = ref.read(supabaseClientProvider);
        if (tech.id.isNotEmpty) {
          await supabase.from('technicians').delete().eq('id', tech.id);
        } else {
          await supabase.from('technicians').delete().eq('name', tech.name);
        }
        ref.invalidate(availableTechniciansProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Technician deleted.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting technician: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final techniciansAsync = ref.watch(availableTechniciansProvider);
    final profile = ref.watch(currentProfileProvider);
    final isAdminOrManager = profile?.primaryRole == UserRole.admin || profile?.primaryRole == UserRole.manager;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.isEmbedded
          ? null
          : AppBar(
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
                'List of Technicians',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              backgroundColor: const Color(0xFF1E1B4B),
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.history_outlined, color: Colors.white),
                  tooltip: 'Service History',
                  onPressed: () => context.push('/complaints/history'),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: 'Sign Out',
                  onPressed: () => _showLogoutDialog(context, ref),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6D28D9),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Technician', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddTechnicianDialog,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(availableTechniciansProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search technician name, phone, email...',
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
              const SizedBox(height: 16),
              techniciansAsync.when(
                data: (technicians) {
                  final query = _searchController.text.trim().toLowerCase();
                  final filtered = query.isEmpty
                      ? technicians
                      : technicians.where((t) {
                          return t.name.toLowerCase().contains(query) ||
                              (t.phone?.toLowerCase().contains(query) ?? false) ||
                              (t.email?.toLowerCase().contains(query) ?? false);
                        }).toList();

                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(technicians.isEmpty
                            ? 'No technician accounts created yet. Click below to add your first technician.'
                            : 'No technicians found matching "$query"'),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final tech = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF6D28D9).withOpacity(0.1),
                              child: Text(
                                tech.name.isNotEmpty ? tech.name.substring(0, 1).toUpperCase() : 'T',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tech.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${tech.phone ?? "No Phone"} • ${tech.email ?? "No Email"}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Status: ${tech.status} • Rating: ${tech.rating}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showEditTechnicianDialog(tech);
                                } else if (val == 'delete') {
                                  _deleteTechnician(tech);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 16),
                                      SizedBox(width: 8),
                                      Text('Edit Technician'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9))),
                error: (e, _) => Center(child: Text('Error loading technicians: $e')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
