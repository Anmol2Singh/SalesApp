// lib/features/quotation_generator/ui/widgets/live_summary_card.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/price_calculator.dart';

class LiveSummaryCard extends StatelessWidget {
  final int subtotal;
  final double gstPercent;
  final int gstAmount;
  final int grandTotal;
  final bool hasBuyback;
  final int buybackAmount;
  final int netPayable;
  final VoidCallback onPreview;
  final VoidCallback onSaveDraft;
  final bool isSaving;

  const LiveSummaryCard({
    super.key,
    required this.subtotal,
    required this.gstPercent,
    required this.gstAmount,
    required this.grandTotal,
    this.hasBuyback = false,
    this.buybackAmount = 0,
    int? netPayable,
    required this.onPreview,
    required this.onSaveDraft,
    this.isSaving = false,
  }) : netPayable = netPayable ?? (hasBuyback ? (grandTotal - buybackAmount) : grandTotal);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayFinal = hasBuyback ? netPayable : grandTotal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sub Total: ${PriceCalculator.formatIndianCurrency(subtotal)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'GST (${gstPercent.toStringAsFixed(gstPercent.truncateToDouble() == gstPercent ? 0 : 1)}%): ${PriceCalculator.formatIndianCurrency(gstAmount)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (hasBuyback)
                      Text(
                        'Buyback: -${PriceCalculator.formatIndianCurrency(buybackAmount)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      hasBuyback ? 'Net Payable' : 'Total Amount',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      PriceCalculator.formatIndianCurrency(displayFinal),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: isSaving ? null : onSaveDraft,
                    icon: isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined, size: 16),
                    label: Text(isSaving ? 'Saving...' : 'Save Draft'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: onPreview,
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('Preview PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
