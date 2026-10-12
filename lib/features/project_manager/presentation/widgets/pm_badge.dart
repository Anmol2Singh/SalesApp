import 'package:flutter/material.dart';
import '../theme/pm_tokens.dart';

enum PmBadgeVariant {
  defaultVariant,
  secondary,
  outline,
  destructive,
  success,
  warning,
  info,
}

class PmBadge extends StatelessWidget {
  final String label;
  final Widget? icon;
  final PmBadgeVariant variant;
  final EdgeInsetsGeometry padding;
  final double fontSize;

  const PmBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = PmBadgeVariant.defaultVariant,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final pm = context.pm;

    Color bg;
    Color fg;
    Border? border;

    switch (variant) {
      case PmBadgeVariant.defaultVariant:
        bg = pm.primary;
        fg = pm.primaryForeground;
        break;
      case PmBadgeVariant.secondary:
        bg = pm.secondary;
        fg = pm.secondaryForeground;
        break;
      case PmBadgeVariant.outline:
        bg = Colors.transparent;
        fg = pm.foreground;
        border = Border.all(color: pm.border);
        break;
      case PmBadgeVariant.destructive:
        bg = pm.destructive;
        fg = pm.destructiveForeground;
        break;
      case PmBadgeVariant.success:
        bg = pm.successSurface;
        fg = pm.success;
        border = Border.all(color: pm.success.withOpacity(0.3));
        break;
      case PmBadgeVariant.warning:
        bg = pm.warningSurface;
        fg = pm.warning;
        border = Border.all(color: pm.warning.withOpacity(0.3));
        break;
      case PmBadgeVariant.info:
        bg = pm.infoSurface;
        fg = pm.info;
        border = Border.all(color: pm.info.withOpacity(0.3));
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
