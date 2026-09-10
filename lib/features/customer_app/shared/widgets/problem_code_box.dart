import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';
import 'package:salesapp/features/customer_app/shared/widgets/toast_service.dart';

class ProblemCodeBox extends StatelessWidget {
  final String code;

  const ProblemCodeBox({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: SelectableText(
              code,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                    letterSpacing: 1.2,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: AppColors.accent, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ToastService.show(context, 'Issue Code Copied!', type: ToastType.success);
            },
            tooltip: 'Copy to Clipboard',
          )
        ],
      ),
    );
  }
}
