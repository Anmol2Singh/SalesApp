import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';
import 'package:salesapp/features/customer_app/shared/widgets/glass_card.dart';

import 'package:salesapp/features/customer_app/data/providers/app_providers.dart';

class AmcAvailScreen extends ConsumerStatefulWidget {
  const AmcAvailScreen({super.key});

  @override
  ConsumerState<AmcAvailScreen> createState() => _AmcAvailScreenState();
}

class _AmcAvailScreenState extends ConsumerState<AmcAvailScreen> {
  String? _submittingPackage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppColors.bgPrimary : AppColors.bgPrimaryLight;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.bgPrimary : Colors.white,
        elevation: 0.5,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimaryLight,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : AppColors.textPrimaryLight,
        ),
        title: Text(
          'Maintenance Contracts',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Secure Your Investment',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose an Annual Maintenance Contract to keep your IZYHEAT products running efficiently year round.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildAmcPackage(
              context: context,
              title: 'Standard AMC',
              price: '₹4,999 / year',
              color: AppColors.primary,
              features: [
                '2 Preventive Maintenance Visits',
                'Priority Phone Support',
                '10% Off on Spare Parts',
              ],
            ),
            const SizedBox(height: 16),
            _buildAmcPackage(
              context: context,
              title: 'Premium AMC',
              price: '₹8,999 / year',
              color: AppColors.accent,
              isPopular: true,
              features: [
                '4 Preventive Maintenance Visits',
                '24/7 Priority Support',
                'Free Labor on Repairs',
                '20% Off on Spare Parts',
                'Next-Day Service Guarantee',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmcPackage({
    required BuildContext context,
    required String title,
    required String price,
    required Color color,
    required List<String> features,
    bool isPopular = false,
  }) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPopular)
            Container(
              color: color,
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              child: const Text(
                'MOST POPULAR',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  price,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: color, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          f,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submittingPackage != null
                      ? null
                      : () async {
                          setState(() => _submittingPackage = title);
                          try {
                            await ref.read(customerRepositoryProvider).requestAmc(packageTitle: title);
                            ref.invalidate(activityLogsProvider);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✓ Request for $title submitted! Our service team will contact you shortly.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              context.pop();
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to submit AMC request: $e'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _submittingPackage = null);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Center(
                    child: _submittingPackage == title
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Request Package',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
