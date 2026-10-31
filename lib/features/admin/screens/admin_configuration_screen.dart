import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/app_config_provider.dart';

class AdminConfigurationScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const AdminConfigurationScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<AdminConfigurationScreen> createState() => _AdminConfigurationScreenState();
}

class _AdminConfigurationScreenState extends ConsumerState<AdminConfigurationScreen> {
  String _selectedAutoLock = 'first_product';

  @override
  void initState() {
    super.initState();
    final config = ref.read(appConfigProvider);
    _selectedAutoLock = config.autoLockMode;
  }

  Future<void> _handleToggleLock(bool currentUnlocked) async {
    if (currentUnlocked) {
      // Locking requires no password, lock immediately
      try {
        await ref.read(appConfigProvider.notifier).setProductAddLock(
          unlock: false,
          autoLockMode: _selectedAutoLock,
        );
        ref.invalidate(appConfigAuditProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product additions are now LOCKED globally.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating lock: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    } else {
      // Unlocking requires confirmation modal with password or explicit typed "UNLOCK"
      final confirmed = await _showUnlockConfirmationDialog();
      if (confirmed == true) {
        try {
          await ref.read(appConfigProvider.notifier).setProductAddLock(
            unlock: true,
            autoLockMode: _selectedAutoLock,
          );
          ref.invalidate(appConfigAuditProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Product additions are now UNLOCKED.'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error unlocking product additions: $e'), backgroundColor: AppColors.error),
            );
          }
        }
      }
    }
  }

  Future<bool?> _showUnlockConfirmationDialog() async {
    final textController = TextEditingController();
    bool isPasswordMode = false;
    bool obscureText = true;
    String errorMessage = '';

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
                  SizedBox(width: 8),
                  Text('Confirm Unlock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Unlocking product additions allows new products to be added to the company catalog. To prevent accidental unlocks, please verify:',
                    style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Type UNLOCK'),
                        selected: !isPasswordMode,
                        onSelected: (val) {
                          setDialogState(() {
                            isPasswordMode = false;
                            errorMessage = '';
                            textController.clear();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Admin Password'),
                        selected: isPasswordMode,
                        onSelected: (val) {
                          setDialogState(() {
                            isPasswordMode = true;
                            errorMessage = '';
                            textController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    obscureText: isPasswordMode && obscureText,
                    decoration: InputDecoration(
                      labelText: isPasswordMode ? 'Enter Admin Password' : 'Type "UNLOCK" to confirm',
                      hintText: isPasswordMode ? '••••••••' : 'UNLOCK',
                      suffixIcon: isPasswordMode
                          ? IconButton(
                              icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setDialogState(() => obscureText = !obscureText),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      errorText: errorMessage.isNotEmpty ? errorMessage : null,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final input = textController.text.trim();
                    if (!isPasswordMode) {
                      if (input == 'UNLOCK') {
                        Navigator.pop(ctx, true);
                      } else {
                        setDialogState(() => errorMessage = 'Please type "UNLOCK" exactly');
                      }
                    } else {
                      if (input.isEmpty) {
                        setDialogState(() => errorMessage = 'Password cannot be empty');
                        return;
                      }
                      // Verify password against current user
                      try {
                        final supabase = ref.read(supabaseClientProvider);
                        final email = supabase.auth.currentUser?.email;
                        if (email != null) {
                          final res = await supabase.auth.signInWithPassword(
                            email: email,
                            password: input,
                          );
                          if (res.user != null) {
                            if (ctx.mounted) Navigator.pop(ctx, true);
                            return;
                          }
                        }
                      } catch (e) {
                        setDialogState(() => errorMessage = 'Invalid password: $e');
                      }
                    }
                  },
                  child: const Text('Confirm & Unlock', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final auditAsync = ref.watch(appConfigAuditProvider);
    final isUnlocked = config.isProductAddUnlocked;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.adminDashboard);
                  }
                },
              ),
              title: const Text('System Configuration'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () {
                    ref.read(appConfigProvider.notifier).fetchConfig();
                    ref.invalidate(appConfigAuditProvider);
                  },
                ),
              ],
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings_suggest, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Global System Controls',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Operational controls, feature switches, and security locks',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isEmbedded)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                    tooltip: 'Refresh',
                    onPressed: () {
                      ref.read(appConfigProvider.notifier).fetchConfig();
                      ref.invalidate(appConfigAuditProvider);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Product Addition Lock Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isUnlocked ? AppColors.success.withValues(alpha: 0.4) : AppColors.error.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Status Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isUnlocked
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isUnlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                            color: isUnlocked ? AppColors.success : AppColors.error,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Product Addition Lock',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isUnlocked
                                      ? AppColors.success.withValues(alpha: 0.12)
                                      : AppColors.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isUnlocked
                                        ? AppColors.success.withValues(alpha: 0.3)
                                        : AppColors.error.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isUnlocked ? Icons.check_circle : Icons.do_not_disturb_on,
                                      size: 13,
                                      color: isUnlocked ? AppColors.success : AppColors.error,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        isUnlocked
                                            ? 'UNLOCKED (Additions enabled)'
                                            : 'LOCKED (Additions disabled)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: isUnlocked ? AppColors.success : AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Toggle Switch
                        Switch(
                          value: isUnlocked,
                          activeColor: AppColors.success,
                          inactiveThumbColor: AppColors.error,
                          onChanged: config.isLoading ? null : (_) => _handleToggleLock(isUnlocked),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Helper Explanation
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isUnlocked
                                  ? 'Product creation is currently active. Authorized administrators can add new products in the Catalog or Inventory screen.'
                                  : 'When locked, nobody (including admins) can add new products from any screen. Existing products can still be viewed, edited, and selected in quotations.',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Auto-lock options
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        const Text(
                          'Auto-lock: ',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedAutoLock,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  color: AppColors.textPrimary,
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'first_product', child: Text('Re-lock after 1 added', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: '15m', child: Text('Re-lock after 15 mins', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: '1h', child: Text('Re-lock after 1 hour', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: '4h', child: Text('Re-lock after 4 hours', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'manual', child: Text('Manual only (Never)', overflow: TextOverflow.ellipsis)),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedAutoLock = val);
                                    if (isUnlocked) {
                                      ref.read(appConfigProvider.notifier).setProductAddLock(
                                        unlock: true,
                                        autoLockMode: val,
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Audit History Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.history, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Recent Lock Changes (Audit Log)',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    auditAsync.when(
                      data: (logs) {
                        if (logs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No audit history recorded yet.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ),
                          );
                        }

                        final df = DateFormat('dd MMM yyyy, hh:mm a');

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: logs.length,
                          separatorBuilder: (_, __) => const Divider(height: 12, color: AppColors.border),
                          itemBuilder: (context, idx) {
                            final log = logs[idx];
                            final newVal = log['new_value'];
                            final isUnlock = newVal == true || newVal == 'true';
                            final dtStr = log['changed_at'] as String?;
                            final dt = dtStr != null ? DateTime.tryParse(dtStr) : null;
                            final changer = (log['changer'] is Map ? log['changer']['full_name'] : null) ?? 'Admin';
                            final reason = log['reason'] ?? 'Mode: ${log['auto_lock_mode'] ?? 'manual'}';

                            return Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isUnlock
                                        ? AppColors.success.withValues(alpha: 0.1)
                                        : AppColors.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isUnlock ? 'UNLOCKED' : 'LOCKED',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isUnlock ? AppColors.success : AppColors.error,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'By $changer • $reason',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (dt != null)
                                        Text(
                                          df.format(dt),
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      )),
                      error: (e, _) => Center(child: Text('Error loading audit log: $e', style: const TextStyle(color: AppColors.error))),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

