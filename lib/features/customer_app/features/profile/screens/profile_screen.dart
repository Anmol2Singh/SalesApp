import 'package:salesapp/features/auth/providers/auth_provider.dart' show authControllerProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';
import 'package:salesapp/features/customer_app/data/providers/app_providers.dart';
import 'package:salesapp/features/customer_app/shared/widgets/glass_card.dart';
import 'package:salesapp/features/customer_app/shared/widgets/toast_service.dart';
import 'package:salesapp/core/providers/theme_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _pushNotifications = true;
  bool _smsAlerts = true;
  bool _emailAlerts = false;
  int _defaultAddressIndex = 0;
  bool _hasInitializedAddresses = false;

  final List<String> _addresses = [];

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: const Text(
          'Log Out',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to log out of your customer portal?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authControllerProvider.notifier).signOut();
              if (mounted) {
                context.go('/login');
              }
            },
            child: const Text(
              'Log Out',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteAddress(int index) {
    setState(() {
      _addresses.removeAt(index);
    });
    ToastService.show(
      context,
      'Address deleted successfully.',
      type: ToastType.success,
    );
  }

  void _editAddress(int index) {
    final controller = TextEditingController(text: _addresses[index]);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: const Text(
          'Edit Saved Address',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter complete address...',
            hintStyle: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              final newAddr = controller.text.trim();
              if (newAddr.isNotEmpty) {
                setState(() {
                  _addresses[index] = newAddr;
                });
                Navigator.pop(context);
                ToastService.show(
                  context,
                  'Address updated successfully.',
                  type: ToastType.success,
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }



  void _addAddress() {
    // Show quick dialog to add address
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: const Text(
          'Add Saved Address',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter complete address...',
            hintStyle: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  _addresses.add(text);
                });
                Navigator.pop(context);
                ToastService.show(
                  context,
                  'Address added successfully!',
                  type: ToastType.success,
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final productsAsync = ref.watch(productsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgPrimary : AppColors.bgPrimaryLight,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/customer/dashboard'),
        ),
      ),
      body: profileAsync.when(
        data: (profile) {
          final name = profile['name'] ?? 'Jane Doe';
          final email = profile['email'] ?? 'jane.doe@example.com';
          final phone = profile['phone'] ?? '+91 99999 99999';
          final avatarUrl =
              profile['avatarUrl'] ??
              'https://api.dicebear.com/7.x/adventurer/svg?seed=Jane';

          if (!_hasInitializedAddresses) {
            final saved = (profile['savedAddresses'] as List?)?.whereType<String>().toList() ?? [];
            _addresses.addAll(saved);
            _hasInitializedAddresses = true;
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Profile Header
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 20,
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'C',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              phone,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.accent,
                        ),
                        onPressed: () {
                          ToastService.show(
                            context,
                            'Edit profile feature coming soon!',
                            type: ToastType.info,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Active AMC Card
                productsAsync.when(
                  data: (products) {
                    final amcProducts = products.where((p) => p.amcStatus == 'active').toList();
                    final hasAmc = amcProducts.isNotEmpty;
                    return GlassCard(
                      padding: const EdgeInsets.all(18),
                      borderRadius: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (hasAmc ? const Color(0xFF10B981) : Colors.amber).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  hasAmc ? Icons.verified_user : Icons.shield_outlined,
                                  color: hasAmc ? const Color(0xFF10B981) : Colors.amber,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hasAmc ? 'Active AMC Protection' : 'Annual Maintenance Contract',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      hasAmc
                                          ? 'Contract ${amcProducts.first.serialNumber}'
                                          : 'No active maintenance contract',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (hasAmc ? const Color(0xFF10B981) : Colors.grey).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  hasAmc ? 'ACTIVE' : 'NONE',
                                  style: TextStyle(
                                    color: hasAmc ? const Color(0xFF10B981) : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (hasAmc) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            ...amcProducts.map((p) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(p.productName, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text(
                                    p.amcExpiryDate != null ? 'Valid until ${DateFormat('dd MMM yyyy').format(p.amcExpiryDate!)}' : 'Active Contract',
                                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            )),
                          ] else ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.accent,
                                  side: const BorderSide(color: AppColors.accent),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.security, size: 16),
                                label: const Text('Avail AMC Contract'),
                                onPressed: () => context.push('/amc_avail'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),

                // 2. Saved Addresses
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saved Addresses',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.accent,
                      ),
                      onPressed: _addAddress,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_addresses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No saved addresses. Tap (+) to add.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  ...List.generate(_addresses.length, (idx) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: GlassCard(
                        padding: const EdgeInsets.all(14),
                        borderRadius: 14,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _addresses[idx],
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _defaultAddressIndex == idx ? Icons.star : Icons.star_border,
                                color: _defaultAddressIndex == idx ? AppColors.accent : AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() => _defaultAddressIndex = idx);
                                ToastService.show(
                                  context,
                                  'Default address updated.',
                                  type: ToastType.success,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: AppColors.accent,
                                size: 20,
                              ),
                              onPressed: () => _editAddress(idx),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.danger,
                                size: 20,
                              ),
                              onPressed: () => _deleteAddress(idx),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 24),

                // 3. Notification Preferences
                Text(
                  'Notification Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  borderRadius: 16,
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _pushNotifications,
                        title: Text(
                          'Push Notifications',
                          style: TextStyle(color: textColor, fontSize: 14),
                        ),
                        activeThumbColor: AppColors.accent,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) =>
                            setState(() => _pushNotifications = val),
                      ),
                      const Divider(color: AppColors.borderColor, height: 1),
                      SwitchListTile(
                        value: _smsAlerts,
                        title: Text(
                          'SMS Status Alerts',
                          style: TextStyle(color: textColor, fontSize: 14),
                        ),
                        activeThumbColor: AppColors.accent,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setState(() => _smsAlerts = val),
                      ),
                      const Divider(color: AppColors.borderColor, height: 1),
                      SwitchListTile(
                        value: _emailAlerts,
                        title: Text(
                          'Email Receipts & Reports',
                          style: TextStyle(color: textColor, fontSize: 14),
                        ),
                        activeThumbColor: AppColors.accent,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setState(() => _emailAlerts = val),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 4. App settings
                Text(
                  'App Preferences',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  borderRadius: 16,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'App Theme',
                          style: TextStyle(color: textColor, fontSize: 14),
                        ),
                        trailing: Consumer(
                          builder: (context, ref, child) {
                            final mode = ref.watch(appThemeModeProvider);
                            return DropdownButton<ThemeMode>(
                              value: mode,
                              dropdownColor: isDark ? AppColors.bgSecondary : AppColors.bgSecondaryLight,
                              underline: const SizedBox(),
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                fontFamily: 'Inter',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: ThemeMode.system,
                                  child: Text('System'),
                                ),
                                DropdownMenuItem(
                                  value: ThemeMode.light,
                                  child: Text('Light'),
                                ),
                                DropdownMenuItem(
                                  value: ThemeMode.dark,
                                  child: Text('Dark'),
                                ),
                              ],
                              onChanged: (newMode) {
                                if (newMode != null) {
                                  ref.read(appThemeModeProvider.notifier).updateThemeMode(newMode);
                                  ToastService.show(
                                    context,
                                    'Theme updated successfully.',
                                    type: ToastType.success,
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),

                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 5. About Details
                const Center(
                  child: Column(
                    children: [
                      Text(
                        'IZYHEAT Customer Portal v1.0.0',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Terms of Service • Privacy Policy',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 6. Logout
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.danger.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'Log Out Account',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _showLogoutDialog,
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
