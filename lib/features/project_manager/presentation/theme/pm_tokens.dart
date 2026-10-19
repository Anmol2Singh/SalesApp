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

  // Dedicated UI colors for matching Project Manager tables & highlights
  final Color paymentCellBg;
  final Color paymentCellText;
  final Color materialCellBg;
  final Color tableHeaderBg;

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
    this.paymentCellBg = const Color(0xFFF0FDF4),
    this.paymentCellText = const Color(0xFF16A34A),
    this.materialCellBg = const Color(0xFFFEFCE8),
    this.tableHeaderBg = const Color(0xFFF8FAFC),
    this.radiusSm = 6.0,
    this.radiusMd = 8.0,
    this.radiusLg = 12.0,
    this.radiusXl = 16.0,
    this.radius2xl = 24.0,
  });

  /// Factory for Light Theme (matches the live web app screenshot)
  factory PmTokens.light() {
    return const PmTokens(
      background: Color(0xFFF8FAFC), // Slate-50 clean enterprise backdrop matching rest of app
      foreground: Color(0xFF0F172A), // Slate-900 primary text
      card: Color(0xFFFFFFFF), // Pure white cards
      cardForeground: Color(0xFF0F172A),
      popover: Color(0xFFFFFFFF),
      popoverForeground: Color(0xFF0F172A),
      primary: Color(0xFF2563EB), // Enterprise royal blue matching app branding
      primaryForeground: Color(0xFFFFFFFF),
      secondary: Color(0xFFF1F5F9), // Slate-100 pill background
      secondaryForeground: Color(0xFF0F172A),
      muted: Color(0xFFF8FAFC),
      mutedForeground: Color(0xFF64748B), // Slate-500
      accent: Color(0xFFEFF6FF), // Blue-50
      accentForeground: Color(0xFF005CE6),
      destructive: Color(0xFFEF4444),
      destructiveForeground: Color(0xFFFFFFFF),
      border: Color(0xFFE2E8F0), // Slate-200
      input: Color(0xFFF8FAFC), // Slate-50 field bg
      ring: Color(0xFF005CE6),
      success: Color(0xFF16A34A), // Green-600
      successSurface: Color(0xFFDCFCE7), // Green-100
      warning: Color(0xFFD97706),
      warningSurface: Color(0xFFFEF3C7),
      info: Color(0xFF0284C7), // Sky-600
      infoSurface: Color(0xFFE0F2FE), // Sky-100
      paymentCellBg: Color(0xFFF0FDF4), // Pale green cell background
      paymentCellText: Color(0xFF16A34A), // Green payment text
      materialCellBg: Color(0xFFFEFCE8), // Light cream yellow material cell bg
      tableHeaderBg: Color(0xFFF8FAFC), // Header row background
    );
  }

  /// Factory for Dark Theme
  factory PmTokens.dark() {
    return const PmTokens(
      background: Color(0xFF0A0F1D),
      foreground: Color(0xFFF8FAFC),
      card: Color(0xFF111827),
      cardForeground: Color(0xFFF8FAFC),
      popover: Color(0xFF111827),
      popoverForeground: Color(0xFFF8FAFC),
      primary: Color(0xFF3B82F6),
      primaryForeground: Color(0xFFFFFFFF),
      secondary: Color(0xFF1E293B),
      secondaryForeground: Color(0xFFF8FAFC),
      muted: Color(0xFF1E293B),
      mutedForeground: Color(0xFF94A3B8),
      accent: Color(0xFF1E3A8A),
      accentForeground: Color(0xFF93C5FD),
      destructive: Color(0xFFEF4444),
      destructiveForeground: Color(0xFFFFFFFF),
      border: Color(0xFF334155),
      input: Color(0xFF1E293B),
      ring: Color(0xFF3B82F6),
      success: Color(0xFF22C55E),
      successSurface: Color(0xFF052E16),
      warning: Color(0xFFF59E0B),
      warningSurface: Color(0xFF451A03),
      info: Color(0xFF38BDF8),
      infoSurface: Color(0xFF082F49),
      paymentCellBg: Color(0xFF064E3B),
      paymentCellText: Color(0xFF4ADE80),
      materialCellBg: Color(0xFF451A03),
      tableHeaderBg: Color(0xFF0F172A),
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
    Color? paymentCellBg,
    Color? paymentCellText,
    Color? materialCellBg,
    Color? tableHeaderBg,
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
      paymentCellBg: paymentCellBg ?? this.paymentCellBg,
      paymentCellText: paymentCellText ?? this.paymentCellText,
      materialCellBg: materialCellBg ?? this.materialCellBg,
      tableHeaderBg: tableHeaderBg ?? this.tableHeaderBg,
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
      paymentCellBg: Color.lerp(paymentCellBg, other.paymentCellBg, t)!,
      paymentCellText: Color.lerp(paymentCellText, other.paymentCellText, t)!,
      materialCellBg: Color.lerp(materialCellBg, other.materialCellBg, t)!,
      tableHeaderBg: Color.lerp(tableHeaderBg, other.tableHeaderBg, t)!,
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
