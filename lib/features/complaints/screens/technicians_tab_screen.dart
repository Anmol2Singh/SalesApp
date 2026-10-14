import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/complaints_provider.dart';
import '../data/models/complaint_model.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/user_role.dart';
import '../../../features/auth/providers/auth_provider.dart';
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
          builder: (modalCtx, setModalState) {
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
                            
                            // 1. Create Supabase Auth user via RPC
                            final Map<String, dynamic> authResult = Map<String, dynamic>.from(
                              await supabase.rpc(
                                'create_new_user',
                                params: {
                                  'email': email,
                                  'password': pwd.isNotEmpty ? pwd : 'Password123!',
                                  'full_name': name,
                                  'new_role': 'technician',
                                },
                              ) as Map,
                            );

                            if (authResult['success'] != true) {
                              throw Exception(authResult['error'] ?? 'Failed to create Auth user');
                            }
                            
                            final newUserId = authResult['user_id'];
                            if (newUserId != null && phone.isNotEmpty) {
                              await supabase.from('profiles').update({'phone': phone}).eq('id', newUserId);
                            }

                            // 2. Ensure technicians table does not have duplicate rows with this email or id
                            try {
                              await supabase.from('technicians').delete().or('id.eq.$newUserId,email.ilike.$email');
                            } catch (_) {}

                            try {
                              await supabase.from('technicians').insert({
                                'id': newUserId,
                                'name': name,
                                'email': email,
                                'phone': phone,
                                'status': 'Available',
                                'rating': 4.9,
                                'active_tasks_count': 0,
                                if (pwd.isNotEmpty) 'password': pwd,
                              });
                            } catch (e) {
                              // Gracefully fallback if 'password' column does not exist
                              await supabase.from('technicians').insert({
                                'id': newUserId,
                                'name': name,
                                'email': email,
                                'phone': phone,
                                'status': 'Available',
                                'rating': 4.9,
                                'active_tasks_count': 0,
                              });
                            }

                            ref.invalidate(availableTechniciansProvider);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
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
                            if (ctx.mounted) {
                              setModalState(() => isSaving = false);
                            }
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
    final formKey = GlobalKey<FormState>();
    bool obscureNewPassword = true;
    bool showCurrentPassword = false;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return AlertDialog(
              title: const Text('Edit Technician'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Full Name *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: 'Enter mobile number',
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (tech.plainPassword != null && tech.plainPassword!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.key, size: 16, color: Color(0xFF475569)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Current Password',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      showCurrentPassword ? tech.plainPassword! : '••••••••',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  showCurrentPassword ? Icons.visibility_off : Icons.visibility,
                                  size: 18,
                                  color: const Color(0xFF475569),
                                ),
                                onPressed: () => setModalState(() => showCurrentPassword = !showCurrentPassword),
                                tooltip: showCurrentPassword ? 'Hide' : 'Show',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16, color: Color(0xFF475569)),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: tech.plainPassword!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Password copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                tooltip: 'Copy',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscureNewPassword,
                        decoration: InputDecoration(
                          labelText: 'New Password (Optional)',
                          hintText: 'Leave blank to keep current',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                              size: 18,
                            ),
                            onPressed: () => setModalState(() => obscureNewPassword = !obscureNewPassword),
                          ),
                        ),
                        validator: (v) {
                          if (v != null && v.isNotEmpty && v.length < 6) {
                            return 'Min 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: 'Technician',
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const [
                          DropdownMenuItem(
                            value: 'Technician',
                            child: Text('Technician'),
                          ),
                        ],
                        onChanged: null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          final name = nameController.text.trim();
                          final email = emailController.text.trim();
                          final phone = phoneController.text.trim();
                          final pwd = passwordController.text.trim();

                          setModalState(() => isSaving = true);
                          try {
                            final supabase = ref.read(supabaseClientProvider);

                            // 1. Update Auth user via RPC if editing an existing UUID
                            if (tech.id.isNotEmpty) {
                              try {
                                await supabase.rpc(
                                  'edit_existing_user',
                                  params: {
                                    'target_user_id': tech.id,
                                    'new_email': email,
                                    'new_password': pwd.isNotEmpty ? pwd : null,
                                    'new_full_name': name,
                                    'new_role': 'technician',
                                  },
                                );
                              } catch (_) {
                                // Ignore if they don't have an auth profile
                              }

                              // Update profiles table phone
                              try {
                                await supabase.from('profiles').update({
                                  'phone': phone.isNotEmpty ? phone : null,
                                }).eq('id', tech.id);
                              } catch (_) {}
                            }

                            // 2. Update technicians table
                            final updates = <String, dynamic>{
                              'name': name,
                              'email': email,
                              'phone': phone.isNotEmpty ? phone : null,
                            };
                            if (pwd.isNotEmpty) updates['password'] = pwd;

                            try {
                              if (tech.id.isNotEmpty) {
                                await supabase.from('technicians').update(updates).eq('id', tech.id);
                              } else {
                                await supabase.from('technicians').update(updates).eq('name', tech.name);
                              }
                            } catch (e) {
                              updates.remove('password');
                              if (tech.id.isNotEmpty) {
                                await supabase.from('technicians').update(updates).eq('id', tech.id);
                              } else {
                                await supabase.from('technicians').update(updates).eq('name', tech.name);
                              }
                            }

                            ref.invalidate(availableTechniciansProvider);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Technician updated successfully!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error updating technician: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          } finally {
                            if (ctx.mounted) {
                              setModalState(() => isSaving = false);
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save', style: TextStyle(color: Colors.white)),
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
          try {
            await supabase.from('profiles').update({'is_active': false}).eq('id', tech.id);
          } catch (_) {}
        }
        if (tech.email != null && tech.email!.isNotEmpty) {
          try {
            await supabase.from('technicians').delete().ilike('email', tech.email!);
            await supabase.from('profiles').update({'is_active': false}).ilike('email', tech.email!);
          } catch (_) {}
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
      floatingActionButton: isAdminOrManager
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF6D28D9),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Add Technician', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _showAddTechnicianDialog,
            )
          : null,
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
              // Search Bar matching Staff Users
              SizedBox(
                height: 42,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search technician name, phone, email...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _searchController.clear()),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    fillColor: AppColors.background,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
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
                        child: Text(
                          technicians.isEmpty
                              ? 'No technician accounts created yet. Click below to add your first technician.'
                              : 'No technicians found matching "$query"',
                          style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Inter'),
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Header matching Staff Users
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D28D9).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF6D28D9).withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6D28D9).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.engineering_outlined,
                                size: 16,
                                color: Color(0xFF6D28D9),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'TECHNICIANS',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: Color(0xFF6D28D9),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6D28D9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${filtered.length} Technicians',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Technician Cards matching Staff Users
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final tech = filtered[index];
                          final initial = tech.name.isNotEmpty ? tech.name.substring(0, 1).toUpperCase() : 'T';
                          final isAvailable = tech.status.toLowerCase().contains('available');
                          final statusColor = isAvailable ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6D28D9).withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF6D28D9),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tech.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${tech.phone != null && tech.phone!.isNotEmpty ? "${tech.phone} • " : ""}${tech.email ?? "No Email"}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          _TechnicianPasswordWidget(password: tech.plainPassword),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
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
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Status pill with colored indicator dot
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: statusColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            tech.status,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: statusColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Rating
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${tech.rating.toStringAsFixed(1)} Rating',
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
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

class _TechnicianPasswordWidget extends StatefulWidget {
  final String? password;
  const _TechnicianPasswordWidget({required this.password});

  @override
  State<_TechnicianPasswordWidget> createState() => _TechnicianPasswordWidgetState();
}

class _TechnicianPasswordWidgetState extends State<_TechnicianPasswordWidget> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.password == null || widget.password!.isEmpty) {
      return Row(
        children: [
          Icon(Icons.key_off_outlined, size: 12, color: Colors.grey.shade400),
          const SizedBox(width: 4),
          Text(
            'Password: not set',
            style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.key, size: 12, color: Color(0xFF4F46E5)),
          const SizedBox(width: 4),
          Text(
            'Pass: ',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            _revealed ? widget.password! : '••••••••',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => setState(() => _revealed = !_revealed),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(_revealed ? Icons.visibility_off : Icons.visibility,
                  size: 14, color: const Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 3),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.password!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password copied to clipboard'), duration: Duration(seconds: 2)),
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(2.0),
              child: Icon(Icons.copy, size: 13, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }
}
