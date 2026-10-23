import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/user_role.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import 'user_roles_editor_screen.dart';

final usersListProvider = FutureProvider<List<Profile>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('profiles')
      .select()
      .order('created_at', ascending: false);

  final rawProfiles = (response as List<dynamic>)
      .map((json) => Profile.fromJson(json as Map<String, dynamic>))
      .toList();

  // Cache all staff profiles to local storage for quick access in reports
  try {
    final prefs = await SharedPreferences.getInstance();
    final staffOnly = rawProfiles.where((p) => !p.roles.contains(UserRole.customer) && p.primaryRole != UserRole.customer).toList();
    await prefs.setString('cached_staff_profiles_v1', jsonEncode(staffOnly.map((p) => p.toJson()).toList()));
  } catch (_) {}

  return rawProfiles
      .where((p) =>
          p.isActive != false &&
          p.deletedAt == null &&
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
  UserRole? _selectedRoleFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showRoleSearchDialog(List<Profile> allUsers) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        String roleSearchText = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final availableRoles = UserRole.values
                .where((r) => r != UserRole.customer && r != UserRole.technician)
                .toList()
              ..sort((a, b) => a.displayName.compareTo(b.displayName));

            final filteredRoles = availableRoles.where((r) {
              return r.displayName.toLowerCase().contains(roleSearchText.toLowerCase());
            }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Role Filter',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      if (_selectedRoleFilter != null)
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedRoleFilter = null);
                            Navigator.pop(dialogCtx);
                          },
                          child: const Text('Clear', style: TextStyle(color: AppColors.error, fontSize: 13)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search role name...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) {
                      setDialogState(() => roleSearchText = val.trim());
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 340,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      selected: _selectedRoleFilter == null,
                      selectedTileColor: AppColors.primary.withOpacity(0.1),
                      leading: Icon(
                        Icons.people_alt_outlined,
                        color: _selectedRoleFilter == null ? AppColors.primary : AppColors.textSecondary,
                        size: 20,
                      ),
                      title: Text(
                        'All Staff Roles (${allUsers.length})',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: _selectedRoleFilter == null ? FontWeight.bold : FontWeight.w500,
                          color: _selectedRoleFilter == null ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: _selectedRoleFilter == null
                          ? const Icon(Icons.check, color: AppColors.primary, size: 20)
                          : null,
                      onTap: () {
                        setState(() => _selectedRoleFilter = null);
                        Navigator.pop(dialogCtx);
                      },
                    ),
                    const Divider(height: 8),
                    ...filteredRoles.map((role) {
                      final count = allUsers
                          .where((u) => u.primaryRole == role || u.roles.contains(role))
                          .length;
                      final isSelected = _selectedRoleFilter == role;
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        selected: isSelected,
                        selectedTileColor: AppColors.primary.withOpacity(0.1),
                        leading: Icon(
                          Icons.shield_outlined,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          size: 20,
                        ),
                        title: Text(
                          role.displayName,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppColors.primary,
                            ),
                          ),
                        ),
                        onTap: () {
                          setState(() => _selectedRoleFilter = role);
                          Navigator.pop(dialogCtx);
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
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
      case UserRole.installation:
        return const Color(0xFF0284C7);
      case UserRole.accounts:
        return const Color(0xFF005CE6);
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings_outlined;
      case UserRole.manager:
        return Icons.manage_accounts_outlined;
      case UserRole.sales:
        return Icons.trending_up_outlined;
      case UserRole.salesHead:
        return Icons.leaderboard_outlined;
      case UserRole.serviceHead:
        return Icons.headset_mic_outlined;
      case UserRole.factory:
        return Icons.precision_manufacturing_outlined;
      case UserRole.purchase:
        return Icons.shopping_cart_outlined;
      case UserRole.boq:
        return Icons.calculate_outlined;
      case UserRole.technician:
        return Icons.engineering_outlined;
      case UserRole.crmStaff:
        return Icons.support_agent_outlined;
      case UserRole.customer:
        return Icons.person_outline;
      case UserRole.installation:
        return Icons.build_circle_outlined;
      case UserRole.accounts:
        return Icons.account_balance_wallet_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider);
    final currentProfile = ref.watch(currentProfileProvider);
    final isCurrentAdmin =
        currentProfile?.roles.contains(UserRole.admin) == true ||
            currentProfile?.primaryRole == UserRole.admin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('User Management'),
            ),
      body: usersAsync.when(
        data: (users) {
          final filteredUsers = users.where((u) {
            final matchesRole = _selectedRoleFilter == null ||
                u.primaryRole == _selectedRoleFilter ||
                u.roles.contains(_selectedRoleFilter);
            final query = _searchQuery.toLowerCase();
            final matchesSearch = query.isEmpty ||
                u.fullName.toLowerCase().contains(query) ||
                u.email.toLowerCase().contains(query) ||
                u.roles.any((r) => r.displayName.toLowerCase().contains(query));
            return matchesRole && matchesSearch;
          }).toList();

          return Column(
            children: [
              // Search & Role Filter Header Bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8)),
                ),
                child: Row(
                  children: [
                    // Search User TextField
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 42,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search user by name, email...',
                            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
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
                          onChanged: (val) {
                            setState(() => _searchQuery = val.trim());
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Searchable Role Dropdown Button
                    InkWell(
                      onTap: () => _showRoleSearchDialog(users),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: _selectedRoleFilter != null
                              ? AppColors.primary.withOpacity(0.12)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedRoleFilter != null
                                ? AppColors.primary
                                : AppColors.border,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_list_rounded,
                              size: 18,
                              color: _selectedRoleFilter != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                _selectedRoleFilter == null
                                    ? 'Filter by Role'
                                    : _selectedRoleFilter!.displayName,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: _selectedRoleFilter != null
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: _selectedRoleFilter != null
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (_selectedRoleFilter != null) ...[
                              InkWell(
                                onTap: () => setState(() => _selectedRoleFilter = null),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 2.0),
                                  child: Icon(Icons.close, size: 16, color: AppColors.primary),
                                ),
                              ),
                            ] else
                              const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Filtered & Grouped User List
              Expanded(
                child: filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_search, size: 48, color: AppColors.textDisabled),
                            const SizedBox(height: 12),
                            Text(
                              _selectedRoleFilter != null
                                  ? 'No users found with role "${_selectedRoleFilter?.displayName}"'
                                  : 'No users found matching your search',
                              style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Inter'),
                            ),
                            if (_selectedRoleFilter != null || _searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _selectedRoleFilter = null;
                                    _searchQuery = '';
                                  });
                                },
                                child: const Text('Reset Filters'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : () {
                        // Group filtered users by primaryRole
                        final Map<UserRole, List<Profile>> groupedUsers = {};
                        for (final u in filteredUsers) {
                          groupedUsers.putIfAbsent(u.primaryRole, () => []).add(u);
                        }

                        // Order groups logically or alphabetically
                        final sortedRoles = groupedUsers.keys.toList()
                          ..sort((a, b) => a.displayName.compareTo(b.displayName));

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: sortedRoles.length,
                          itemBuilder: (context, groupIndex) {
                            final role = sortedRoles[groupIndex];
                            final roleUsers = groupedUsers[role]!;
                            final roleColor = _getRoleColor(role);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Role Group Header
                                Container(
                                  margin: EdgeInsets.only(top: groupIndex == 0 ? 4 : 16, bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: roleColor.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: roleColor.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _getRoleIcon(role),
                                          size: 16,
                                          color: roleColor,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          role.displayName.toUpperCase(),
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                            color: roleColor,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: roleColor,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${roleUsers.length} ${roleUsers.length == 1 ? "User" : "Users"}',
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

                                // Role Users Cards
                                ...roleUsers.map((user) => _UserTile(
                                      user: user,
                                      onToggleActive: () => _toggleActive(user),
                                      onChangeRole: (newRole) => _changeRole(user, newRole),
                                      onEdit: () => _editUser(user, isCurrentAdmin),
                                      onDelete: () => _deleteUser(user),
                                    )),
                              ],
                            );
                          },
                        );
                      }(),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateUserDialog(isCurrentAdmin),
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
          .update({'is_active': !user.isActive}).eq('id', user.id);
      ref.invalidate(usersListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _changeRole(Profile user, UserRole newRole) async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      await supabase
          .from('profiles')
          .update({'role': newRole.value}).eq('id', user.id);
      ref.invalidate(usersListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Role updated to ${newRole.displayName} successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteUser(Profile user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Are you sure you want to permanently delete ${user.fullName} (${user.email})? This action cannot be undone.'),
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
        await supabase
            .from('complaints')
            .update({'technician_id': null}).eq('technician_id', user.id);
      } catch (_) {}
      try {
        await supabase
            .from('service_requests')
            .update({'technician_id': null}).eq('technician_id', user.id);
      } catch (_) {}
      try {
        await supabase
            .from('prospects')
            .update({'assigned_to': null}).eq('assigned_to', user.id);
      } catch (_) {}
      try {
        await supabase
            .from('leads')
            .update({'assigned_to': null}).eq('assigned_to', user.id);
      } catch (_) {}
      try {
        await supabase
            .from('sales_pipelines')
            .update({'assigned_to': null}).eq('assigned_to', user.id);
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
            'deleted_at': DateTime.now().toIso8601String(),
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

  void _editUser(Profile user, bool isCurrentAdmin) {
    final nameController = TextEditingController(text: user.fullName);
    final emailController = TextEditingController(text: user.email);
    final phoneController = TextEditingController(text: user.phone ?? '');
    final passwordController = TextEditingController();
    UserRole selectedRole = user.primaryRole;
    final formKey = GlobalKey<FormState>();
    bool obscureNewPassword = true;
    bool showCurrentPassword = false;

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
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'Enter mobile number',
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (user.plainPassword != null &&
                      user.plainPassword!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.key,
                              size: 16, color: Color(0xFF475569)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Current Password',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.bold)),
                                Text(
                                  showCurrentPassword
                                      ? user.plainPassword!
                                      : '••••••••',
                                  style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                                showCurrentPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 18,
                                color: const Color(0xFF475569)),
                            onPressed: () => setModalState(() =>
                                showCurrentPassword = !showCurrentPassword),
                            tooltip: showCurrentPassword ? 'Hide' : 'Show',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy,
                                size: 16, color: Color(0xFF475569)),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: user.plainPassword!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Password copied to clipboard'),
                                    duration: Duration(seconds: 2)),
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
                            obscureNewPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 18),
                        onPressed: () => setModalState(
                            () => obscureNewPassword = !obscureNewPassword),
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
                  DropdownButtonFormField<UserRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: (UserRole.values
                            .where((r) =>
                                r != UserRole.customer &&
                                (isCurrentAdmin || r != UserRole.admin))
                            .toList()
                          ..sort((a, b) => a.displayName
                              .toLowerCase()
                              .compareTo(b.displayName.toLowerCase())))
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.displayName),
                            ))
                        .toList(),
                    onChanged: (r) => setModalState(
                        () => selectedRole = r ?? user.primaryRole),
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

                  // Update phone and password in profiles table
                  final updatedPhone = phoneController.text.trim();
                  final newPwd = passwordController.text.trim();
                  final profileUpdates = <String, dynamic>{
                    'phone': updatedPhone.isNotEmpty ? updatedPhone : null,
                  };
                  if (newPwd.isNotEmpty) {
                    profileUpdates['password'] = newPwd;
                    profileUpdates['plain_password'] = newPwd;
                  }
                  await supabase
                      .from('profiles')
                      .update(profileUpdates)
                      .eq('id', user.id);

                  if (ctx.mounted) Navigator.pop(ctx);
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

  void _showCreateUserDialog(bool isCurrentAdmin) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole selectedRole = UserRole.sales;
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;

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
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email *'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18),
                      onPressed: () => setModalState(
                          () => obscurePassword = !obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<UserRole>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: (UserRole.values
                          .where((r) =>
                              r != UserRole.customer &&
                              (isCurrentAdmin || r != UserRole.admin))
                          .toList()
                        ..sort((a, b) => a.displayName
                            .toLowerCase()
                            .compareTo(b.displayName.toLowerCase())))
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
                  final cleanEmail = emailController.text.trim().toLowerCase();
                  final cleanPassword = passwordController.text;
                  final cleanName = nameController.text.trim();
                  final cleanPhone = phoneController.text.trim();

                  String? newUserId;

                  // 1. Register with GoTrue native client
                  try {
                    final tempClient = SupabaseClient(
                      AppConfig.supabaseUrl,
                      AppConfig.supabaseAnonKey,
                      authOptions: const FlutterAuthClientOptions(
                        authFlowType: AuthFlowType.implicit,
                      ),
                    );
                    final signUpRes = await tempClient.auth.signUp(
                      email: cleanEmail,
                      password: cleanPassword,
                      data: {
                        'full_name': cleanName,
                        'role': selectedRole.value,
                      },
                    );
                    newUserId = signUpRes.user?.id;
                  } catch (signUpErr) {
                    debugPrint('GoTrue signUp note: $signUpErr');
                  }

                  // 2. Call RPC create_new_user to ensure permissions and database integrity
                  try {
                    final Map<String, dynamic> result = Map<String, dynamic>.from(
                      await supabase.rpc(
                        'create_new_user',
                        params: {
                          'email': cleanEmail,
                          'password': cleanPassword,
                          'full_name': cleanName,
                          'new_role': selectedRole.value,
                        },
                      ) as Map,
                    );
                    if (result['user_id'] != null) {
                      newUserId = result['user_id']?.toString();
                    }
                  } catch (rpcErr) {
                    debugPrint('create_new_user RPC note: $rpcErr');
                  }

                  // 3. Ensure profiles table row has the new role, full name, phone and is active
                  try {
                    final pRes = await supabase.from('profiles').select().ilike('email', cleanEmail).maybeSingle();
                    if (pRes != null) {
                      await supabase.from('profiles').update({
                        'full_name': cleanName,
                        'role': selectedRole.value,
                        'roles': [selectedRole.value],
                        'is_active': true,
                        'deleted_at': null,
                        'password': cleanPassword,
                        'plain_password': cleanPassword,
                        if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
                        'updated_at': DateTime.now().toIso8601String(),
                      }).eq('id', pRes['id']);
                    } else if (newUserId != null) {
                      await supabase.from('profiles').insert({
                        'id': newUserId,
                        'email': cleanEmail,
                        'full_name': cleanName,
                        'role': selectedRole.value,
                        'roles': [selectedRole.value],
                        'is_active': true,
                        'password': cleanPassword,
                        'plain_password': cleanPassword,
                        if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
                        'created_at': DateTime.now().toIso8601String(),
                        'updated_at': DateTime.now().toIso8601String(),
                      });
                    }
                  } catch (pErr) {
                    debugPrint('Profile update note: $pErr');
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
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
                    const SizedBox(height: 4),
                    _UserPasswordWidget(password: user.plainPassword),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 20, color: AppColors.textSecondary),
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
                          user.isActive
                              ? Icons.block
                              : Icons.check_circle_outline,
                          size: 16,
                          color: user.isActive
                              ? AppColors.error
                              : AppColors.success,
                        ),
                        SizedBox(width: 8),
                        Text(
                          user.isActive
                              ? 'Deactivate Account'
                              : 'Activate Account',
                          style: TextStyle(
                            color: user.isActive
                                ? AppColors.error
                                : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 16, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete User',
                            style: TextStyle(color: AppColors.error)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
      case UserRole.installation:
        return const Color(0xFF0284C7);
      case UserRole.accounts:
        return const Color(0xFF005CE6);
    }
  }
}

class _UserPasswordWidget extends StatefulWidget {
  final String? password;
  const _UserPasswordWidget({required this.password});

  @override
  State<_UserPasswordWidget> createState() => _UserPasswordWidgetState();
}

class _UserPasswordWidgetState extends State<_UserPasswordWidget> {
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
            style: TextStyle(
                fontFamily: 'Inter', fontSize: 11, color: Colors.grey.shade500),
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
                fontWeight: FontWeight.w600),
          ),
          Text(
            _revealed ? widget.password! : '••••••••',
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A)),
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
                const SnackBar(
                    content: Text('Password copied to clipboard'),
                    duration: Duration(seconds: 2)),
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
