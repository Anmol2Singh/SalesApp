import 'package:flutter/material.dart';
import '../theme/pm_tokens.dart';

enum PmButtonVariant {
  defaultVariant,
  secondary,
  outline,
  ghost,
  destructive,
}

enum PmButtonSize {
  sm,
  md,
  lg,
  icon,
}

class PmButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final PmButtonVariant variant;
  final PmButtonSize size;
  final bool isLoading;
  final double? width;

  const PmButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = PmButtonVariant.defaultVariant,
    this.size = PmButtonSize.md,
    this.isLoading = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final pm = context.pm;

    Color bg;
    Color fg;
    Border? border;

    switch (variant) {
      case PmButtonVariant.defaultVariant:
        bg = pm.primary;
        fg = pm.primaryForeground;
        break;
      case PmButtonVariant.secondary:
        bg = pm.secondary;
        fg = pm.secondaryForeground;
        break;
      case PmButtonVariant.outline:
        bg = Colors.transparent;
        fg = pm.foreground;
        border = Border.all(color: pm.border);
        break;
      case PmButtonVariant.ghost:
        bg = Colors.transparent;
        fg = pm.foreground;
        break;
      case PmButtonVariant.destructive:
        bg = pm.destructive;
        fg = pm.destructiveForeground;
        break;
    }

    double height;
    EdgeInsetsGeometry padding;
    double radius = pm.radiusMd;

    switch (size) {
      case PmButtonSize.sm:
        height = 36;
        padding = const EdgeInsets.symmetric(horizontal: 12);
        radius = pm.radiusSm;
        break;
      case PmButtonSize.md:
        height = 42;
        padding = const EdgeInsets.symmetric(horizontal: 16);
        break;
      case PmButtonSize.lg:
        height = 48;
        padding = const EdgeInsets.symmetric(horizontal: 24);
        radius = pm.radiusLg;
        break;
      case PmButtonSize.icon:
        height = 38;
        padding = EdgeInsets.zero;
        radius = 9999;
        break;
    }

    return SizedBox(
      height: height,
      width: size == PmButtonSize.icon ? height : width,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              border: border,
              borderRadius: BorderRadius.circular(radius),
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  )
                : DefaultTextStyle(
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: size == PmButtonSize.sm ? 12 : 14,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                    child: child,
                  ),
          ),
        ),
      ),
    );
  }
}
