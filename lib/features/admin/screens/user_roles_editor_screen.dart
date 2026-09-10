// lib/features/admin/screens/user_roles_editor_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/user_role.dart';
import '../../../core/providers/supabase_provider.dart';
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
    // Show all available roles
    final availableRoles = UserRole.values.where((r) => r != UserRole.customer).toList();

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
                return CheckboxListTile(
                  title: Text(
                    role.displayName,
                    style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('ID: ${role.name}', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary)),
                  value: isSelected,
                  activeColor: AppColors.primary,
                  onChanged: (bool? checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedRoles.add(role);
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
