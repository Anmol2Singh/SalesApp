// lib/features/admin/screens/user_roles_editor_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/user_role.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'user_management_screen.dart';

class UserRolesEditorScreen extends ConsumerStatefulWidget {
  final Profile user;

  const UserRolesEditorScreen({super.key, required this.user});

  @override
  ConsumerState<UserRolesEditorScreen> createState() => _UserRolesEditorScreenState();
}

class _UserRolesEditorScreenState extends ConsumerState<UserRolesEditorScreen> {
  late List<UserRole> _selectedRoles;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedRoles = List.from(widget.user.roles);
  }

  Future<void> _saveRoles() async {
    if (_selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one role must be selected'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      
      // We store roles as an array of strings in supabase
      final rolesList = _selectedRoles.map((r) => r.value).toList();
      
      await supabase.from('profiles').update({
        'roles': rolesList,
        'role': rolesList.isNotEmpty ? rolesList.first : 'customer', // update legacy column as well
      }).eq('id', widget.user.id);
          
      ref.invalidate(usersListProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Roles updated successfully!'), backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentProfile = ref.watch(currentProfileProvider);
    final isCurrentAdmin = currentProfile?.roles.contains(UserRole.admin) == true ||
        currentProfile?.primaryRole == UserRole.admin;

    // Show available roles (excluding customer, and excluding admin if current user is not admin), sorted A->Z
    final availableRoles = UserRole.values
        .where((r) => r != UserRole.customer && (isCurrentAdmin || r != UserRole.admin))
        .toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Edit Roles: ${widget.user.fullName}'),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: availableRoles.length,
              itemBuilder: (context, index) {
                final role = availableRoles[index];
                final isSelected = _selectedRoles.contains(role);

                final hasAdmin = _selectedRoles.contains(UserRole.admin);
                final hasManager = _selectedRoles.contains(UserRole.manager);
                final hasSalesHead = _selectedRoles.contains(UserRole.salesHead);

                bool isDisabled = false;
                String subtitleText = 'ID: ${role.name}';

                if (hasAdmin && role != UserRole.admin) {
                  isDisabled = true;
                  subtitleText = 'Disabled (Admin has full access to all roles)';
                } else if (hasManager && role != UserRole.manager && role != UserRole.admin) {
                  isDisabled = true;
                  subtitleText = 'Disabled (Manager cannot be allotted other roles)';
                } else if (hasSalesHead && (role == UserRole.sales || role == UserRole.crmStaff)) {
                  isDisabled = true;
                  subtitleText = 'Disabled (Superseded by Sales Head)';
                }

                return CheckboxListTile(
                  title: Text(
                    role.displayName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      color: isDisabled ? Colors.grey.shade400 : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    subtitleText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: isDisabled ? Colors.grey.shade400 : AppColors.textSecondary,
                    ),
                  ),
                  value: isSelected,
                  activeColor: AppColors.primary,
                  onChanged: isDisabled
                      ? null
                      : (bool? checked) {
                          setState(() {
                            if (checked == true) {
                              if (role == UserRole.admin) {
                                // i) admin role: disable giving any other role, clear all others
                                _selectedRoles = [UserRole.admin];
                              } else if (role == UserRole.manager) {
                                // ii) manager role: disable rest all roles allotment
                                _selectedRoles = [UserRole.manager];
                              } else if (role == UserRole.salesHead) {
                                // iii) Sales Head role: disable sales executive & crm staff role, (uncheck if already allotted)
                                _selectedRoles.remove(UserRole.sales);
                                _selectedRoles.remove(UserRole.crmStaff);
                                _selectedRoles.add(UserRole.salesHead);
                              } else {
                                // If promoting to admin from anything, handled above
                                _selectedRoles.remove(UserRole.manager);
                                _selectedRoles.add(role);
                              }
                            } else {
                              _selectedRoles.remove(role);
                            }
                          });
                        },
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveRoles,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Save Roles', style: TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
