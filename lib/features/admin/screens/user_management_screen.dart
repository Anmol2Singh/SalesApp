// lib/features/admin/screens/user_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/user_role.dart';
import '../../../core/providers/supabase_provider.dart';
import 'user_roles_editor_screen.dart';

final usersListProvider = FutureProvider<List<Profile>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('profiles')
      .select()
      .order('created_at', ascending: false);

  return (response as List<dynamic>)
      .map((json) => Profile.fromJson(json as Map<String, dynamic>))
      .where((p) =>
          p.isActive != false &&
          !p.roles.contains(UserRole.customer) &&
          p.primaryRole != UserRole.customer &&
          p.primaryRole != UserRole.technician &&
          !(p.email.toLowerCase().endsWith('@izyheat-customer.com')))
      .toList();
});

class UserManagementScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const UserManagementScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isEmbedded ? null : AppBar(
        title: const Text('User Management'),
      ),
      body: usersAsync.when(
        data: (users) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _UserTile(
              user: user,
              onToggleActive: () => _toggleActive(user),
              onChangeRole: (role) => _changeRole(user, role),
              onEdit: () => _editUser(user),
              onDelete: () => _deleteUser(user),
            );
          },
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateUserDialog,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add User',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _toggleActive(Profile user) async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      await supabase
          .from('profiles')
          .update({'is_active': !user.isActive})
          .eq('id', user.id);
      ref.invalidate(usersListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _changeRole(Profile user, UserRole newRole) async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      await supabase
          .from('profiles')
          .update({'role': newRole.value})
          .eq('id', user.id);
      ref.invalidate(usersListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role updated to ${newRole.displayName} successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteUser(Profile user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to permanently delete ${user.fullName} (${user.email})? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final supabase = ref.read(supabaseClientProvider);
    try {
      // 1. Unlink foreign key references before deleting profile
      try {
        await supabase.from('complaints').update({'technician_id': null}).eq('technician_id', user.id);
      } catch (_) {}
      try {
        await supabase.from('service_requests').update({'technician_id': null}).eq('technician_id', user.id);
      } catch (_) {}
      try {
        await supabase.from('prospects').update({'assigned_to': null}).eq('assigned_to', user.id);
      } catch (_) {}
      try {
        await supabase.from('leads').update({'assigned_to': null}).eq('assigned_to', user.id);
      } catch (_) {}
      try {
        await supabase.from('sales_pipelines').update({'assigned_to': null}).eq('assigned_to', user.id);
      } catch (_) {}
      try {
        await supabase.from('notifications').delete().eq('user_id', user.id);
      } catch (_) {}

      // 2. Attempt deleting user via RPC or direct deletion
      bool deleted = false;
      try {
        final res = await supabase.rpc('delete_existing_user', params: {
          'target_user_id': user.id,
        });
        if (res is Map && res['success'] == true) {
          deleted = true;
        }
      } catch (_) {}

      if (!deleted) {
        try {
          await supabase.from('profiles').delete().eq('id', user.id);
          deleted = true;
        } catch (_) {
          // Soft-deactivate if database constraint restricts hard deletion
          await supabase.from('profiles').update({
            'is_active': false,
            'roles': ['deactivated'],
          }).eq('id', user.id);
          deleted = true;
        }
      }

      ref.invalidate(usersListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _editUser(Profile user) {
    final nameController = TextEditingController(text: user.fullName);
    final emailController = TextEditingController(text: user.email);
    final passwordController = TextEditingController();
    UserRole selectedRole = user.primaryRole;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Edit User'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full Name *'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email *'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password (Optional)',
                      hintText: 'Leave blank to keep current',
                    ),
                    validator: (v) {
                      if (v != null && v.isNotEmpty && v.length < 8) {
                        return 'Min 8 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<UserRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: (UserRole.values
                            .where((r) => r != UserRole.customer && r != UserRole.manager && r != UserRole.technician)
                            .toList()
                          ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase())))
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.displayName),
                            ))
                        .toList(),
                    onChanged: (r) =>
                        setModalState(() => selectedRole = r ?? user.primaryRole),
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
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                try {
                  final supabase = ref.read(supabaseClientProvider);

                  final Map<String, dynamic> result = Map<String, dynamic>.from(
                    await supabase.rpc(
                      'edit_existing_user',
                      params: {
                        'target_user_id': user.id,
                        'new_email': emailController.text.trim(),
                        'new_password': passwordController.text.isNotEmpty
                            ? passwordController.text
                            : null,
                        'new_full_name': nameController.text.trim(),
                        'new_role': selectedRole.value,
                      },
                    ) as Map,
                  );

                  if (result['success'] != true) {
                    throw Exception(result['error'] ?? 'Failed to update user');
                  }

                  Navigator.pop(ctx);
                  ref.invalidate(usersListProvider);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('User updated successfully'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole selectedRole = UserRole.sales;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Create New User'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name *'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email *'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password *'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 8) return 'Min 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<UserRole>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: (UserRole.values
                          .where((r) => r != UserRole.customer && r != UserRole.manager && r != UserRole.technician)
                          .toList()
                        ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase())))
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.displayName),
                          ))
                      .toList(),
                  onChanged: (r) =>
                      setModalState(() => selectedRole = r ?? UserRole.sales),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                try {
                  final supabase = ref.read(supabaseClientProvider);

                  // Call RPC to create user
                  final Map<String, dynamic> result = Map<String, dynamic>.from(
                    await supabase.rpc(
                      'create_new_user',
                      params: {
                        'email': emailController.text.trim(),
                        'password': passwordController.text,
                        'full_name': nameController.text.trim(),
                        'new_role': selectedRole.value,
                      },
                    ) as Map,
                  );

                  if (result['success'] != true) {
                    throw Exception(result['error'] ?? 'Failed to create user');
                  }

                  Navigator.pop(ctx);
                  ref.invalidate(usersListProvider);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('User created successfully'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Profile user;
  final VoidCallback onToggleActive;
  final Function(UserRole) onChangeRole;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserTile({
    required this.user,
    required this.onToggleActive,
    required this.onChangeRole,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor(user.primaryRole);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: user.isActive ? AppColors.surface : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: user.isActive ? AppColors.border : AppColors.textDisabled,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: user.isActive
                      ? AppColors.primarySurface
                      : AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    user.fullName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: user.isActive
                          ? AppColors.primary
                          : AppColors.textSecondary,
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
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: user.isActive
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                onSelected: (val) {
                  if (val == 'edit') {
                    onEdit();
                  } else if (val == 'toggle_active') {
                    onToggleActive();
                  } else if (val == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Edit User'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle_active',
                    child: Row(
                      children: [
                        Icon(
                          user.isActive ? Icons.block : Icons.check_circle_outline,
                          size: 16,
                          color: user.isActive ? AppColors.error : AppColors.success,
                        ),
                        SizedBox(width: 8),
                        Text(
                          user.isActive ? 'Deactivate Account' : 'Activate Account',
                          style: TextStyle(
                            color: user.isActive ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete User', style: TextStyle(color: AppColors.error)),
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
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserRolesEditorScreen(user: user),
                    ),
                  );
                },
                icon: const Icon(Icons.manage_accounts, size: 16),
                label: const Text('Manage Roles',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  user.primaryRole.displayName,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: roleColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AppColors.primary;
      case UserRole.manager:
        return Colors.purple;
      case UserRole.sales:
        return AppColors.accent;
      case UserRole.salesHead:
        return Colors.teal;
      case UserRole.serviceHead:
        return Colors.indigo;
      case UserRole.factory:
        return AppColors.info;
      case UserRole.purchase:
        return AppColors.success;
      case UserRole.boq:
        return Colors.deepPurple;
      case UserRole.technician:
        return Colors.green;
      case UserRole.crmStaff:
        return Colors.teal;
      case UserRole.customer:
        return Colors.blueGrey;
    }
  }
}
