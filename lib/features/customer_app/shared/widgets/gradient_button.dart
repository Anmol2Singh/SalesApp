import 'package:flutter/material.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final Widget? icon;
  final double height;
  final double borderRadius;
  final List<Color>? gradientColors;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.icon,
    this.height = 54.0,
    this.borderRadius = 16.0,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? [AppColors.primary, AppColors.accent];
    final isEnabled = onTap != null && !isLoading;

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: isEnabled
            ? LinearGradient(
                colors: colors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: isEnabled ? null : AppColors.bgSecondary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: colors.first.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                )
              ]
            : null,
        border: isEnabled
            ? null
            : Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        icon!,
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isEnabled
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
