import 'package:flutter/material.dart';

/// Scoped design tokens for Project Manager module converting shadcn / Tailwind CSS variables.
/// Does not mutate the global AppTheme, ensuring 100% isolation for existing screens.
class PmTokens extends ThemeExtension<PmTokens> {
  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color popover;
  final Color popoverForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color border;
  final Color input;
  final Color ring;
  final Color success;
  final Color successSurface;
  final Color warning;
  final Color warningSurface;
  final Color info;
  final Color infoSurface;

  // Radii
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radius2xl;

  const PmTokens({
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.popover,
    required this.popoverForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.border,
    required this.input,
    required this.ring,
    required this.success,
    required this.successSurface,
    required this.warning,
    required this.warningSurface,
    required this.info,
    required this.infoSurface,
    this.radiusSm = 6.0,
    this.radiusMd = 8.0,
    this.radiusLg = 12.0,
    this.radiusXl = 16.0,
    this.radius2xl = 24.0,
  });

  /// Factory for Light Theme (matches Source CSS variables)
  factory PmTokens.light() {
    return const PmTokens(
      background: Color(0xFFFFFFFF),
      foreground: Color(0xFF09090B),
      card: Color(0xFFFFFFFF),
      cardForeground: Color(0xFF09090B),
      popover: Color(0xFFFFFFFF),
      popoverForeground: Color(0xFF09090B),
      primary: Color(0xFF18181B),
      primaryForeground: Color(0xFFFAFAFA),
      secondary: Color(0xFFF4F4F5),
      secondaryForeground: Color(0xFF18181B),
      muted: Color(0xFFF4F4F5),
      mutedForeground: Color(0xFF71717A),
      accent: Color(0xFFF4F4F5),
      accentForeground: Color(0xFF18181B),
      destructive: Color(0xFFEF4444),
      destructiveForeground: Color(0xFFFAFAFA),
      border: Color(0xFFE4E4E7),
      input: Color(0xFFE4E4E7),
      ring: Color(0xFF18181B),
      success: Color(0xFF16A34A),
      successSurface: Color(0xFFF0FDF4),
      warning: Color(0xFFD97706),
      warningSurface: Color(0xFFFFFBEB),
      info: Color(0xFF2563EB),
      infoSurface: Color(0xFFEFF6FF),
    );
  }

  /// Factory for Dark Theme (matches Source .dark CSS variables)
  factory PmTokens.dark() {
    return const PmTokens(
      background: Color(0xFF09090B),
      foreground: Color(0xFFFAFAFA),
      card: Color(0xFF121215),
      cardForeground: Color(0xFFFAFAFA),
      popover: Color(0xFF121215),
      popoverForeground: Color(0xFFFAFAFA),
      primary: Color(0xFFFAFAFA),
      primaryForeground: Color(0xFF18181B),
      secondary: Color(0xFF27272A),
      secondaryForeground: Color(0xFFFAFAFA),
      muted: Color(0xFF27272A),
      mutedForeground: Color(0xFFA1A1AA),
      accent: Color(0xFF27272A),
      accentForeground: Color(0xFFFAFAFA),
      destructive: Color(0xFFEF4444),
      destructiveForeground: Color(0xFFFAFAFA),
      border: Color(0xFF27272A),
      input: Color(0xFF27272A),
      ring: Color(0xFFD4D4D8),
      success: Color(0xFF22C55E),
      successSurface: Color(0xFF052E16),
      warning: Color(0xFFF59E0B),
      warningSurface: Color(0xFF451A03),
      info: Color(0xFF3B82F6),
      infoSurface: Color(0xFF1E3A8A),
    );
  }

  @override
  ThemeExtension<PmTokens> copyWith({
    Color? background,
    Color? foreground,
    Color? card,
    Color? cardForeground,
    Color? popover,
    Color? popoverForeground,
    Color? primary,
    Color? primaryForeground,
    Color? secondary,
    Color? secondaryForeground,
    Color? muted,
    Color? mutedForeground,
    Color? accent,
    Color? accentForeground,
    Color? destructive,
    Color? destructiveForeground,
    Color? border,
    Color? input,
    Color? ring,
    Color? success,
    Color? successSurface,
    Color? warning,
    Color? warningSurface,
    Color? info,
    Color? infoSurface,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radius2xl,
  }) {
    return PmTokens(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      card: card ?? this.card,
      cardForeground: cardForeground ?? this.cardForeground,
      popover: popover ?? this.popover,
      popoverForeground: popoverForeground ?? this.popoverForeground,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      secondary: secondary ?? this.secondary,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      accent: accent ?? this.accent,
      accentForeground: accentForeground ?? this.accentForeground,
      destructive: destructive ?? this.destructive,
      destructiveForeground: destructiveForeground ?? this.destructiveForeground,
      border: border ?? this.border,
      input: input ?? this.input,
      ring: ring ?? this.ring,
      success: success ?? this.success,
      successSurface: successSurface ?? this.successSurface,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
      info: info ?? this.info,
      infoSurface: infoSurface ?? this.infoSurface,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radius2xl: radius2xl ?? this.radius2xl,
    );
  }

  @override
  ThemeExtension<PmTokens> lerp(covariant ThemeExtension<PmTokens>? other, double t) {
    if (other is! PmTokens) return this;
    return PmTokens(
      background: Color.lerp(background, other.background, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardForeground: Color.lerp(cardForeground, other.cardForeground, t)!,
      popover: Color.lerp(popover, other.popover, t)!,
      popoverForeground: Color.lerp(popoverForeground, other.popoverForeground, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryForeground: Color.lerp(primaryForeground, other.primaryForeground, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryForeground: Color.lerp(secondaryForeground, other.secondaryForeground, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentForeground: Color.lerp(accentForeground, other.accentForeground, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      destructiveForeground: Color.lerp(destructiveForeground, other.destructiveForeground, t)!,
      border: Color.lerp(border, other.border, t)!,
      input: Color.lerp(input, other.input, t)!,
      ring: Color.lerp(ring, other.ring, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      radiusSm: radiusSm + (other.radiusSm - radiusSm) * t,
      radiusMd: radiusMd + (other.radiusMd - radiusMd) * t,
      radiusLg: radiusLg + (other.radiusLg - radiusLg) * t,
      radiusXl: radiusXl + (other.radiusXl - radiusXl) * t,
      radius2xl: radius2xl + (other.radius2xl - radius2xl) * t,
    );
  }

  /// Helper getter on BuildContext for quick access: `context.pm`
  static PmTokens of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final extension = Theme.of(context).extension<PmTokens>();
    if (extension != null) return extension;
    return isDark ? PmTokens.dark() : PmTokens.light();
  }
}

extension PmTokensContextExt on BuildContext {
  PmTokens get pm => PmTokens.of(this);
}
