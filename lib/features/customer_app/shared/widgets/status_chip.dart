import 'package:flutter/material.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final String status; // success, warning, danger, info
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const StatusChip({
    super.key,
    required this.label,
    required this.status,
    this.borderRadius = 8.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'success':
      case 'active':
      case 'confirmed':
      case 'completed':
        color = AppColors.success;
        break;
      case 'warning':
      case 'pending':
      case 'expiring_soon':
      case 'in_progress':
        color = AppColors.warning;
        break;
      case 'danger':
      case 'expired':
      case 'cancelled':
      case 'inactive':
        color = AppColors.danger;
        break;
      case 'info':
      default:
        color = AppColors.accent;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}
