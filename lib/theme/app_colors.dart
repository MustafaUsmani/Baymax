import 'package:flutter/material.dart';

/// Centralised colour palette for the CrisisLink application.
///
/// Every colour is declared as a `static const` so it can be referenced
/// anywhere without instantiation and is compile-time constant-safe.
abstract final class AppColors {
  // ── Brand Primaries ──────────────────────────────────────────────────────

  /// Deep navy – used as the main background / scaffold colour.
  static const Color primaryBackground = Color(0xFF0D1B2A);

  /// Slightly lighter navy – used for surfaces, sheets, dialogs.
  static const Color secondarySurface = Color(0xFF1A1A2E);

  /// Amber accent – CTA buttons, selected nav items, highlights.
  static const Color accentAmber = Color(0xFFF5A623);

  /// Emergency red – destructive actions, critical severity badges.
  static const Color emergencyRed = Color(0xFFE63946);

  /// Teal – success states, low-severity badges, positive feedback.
  static const Color successTeal = Color(0xFF2EC4B6);

  // ── Text ─────────────────────────────────────────────────────────────────

  /// Primary text colour (white on dark backgrounds).
  static const Color textPrimary = Colors.white;

  /// Secondary / muted text colour.
  static const Color textSecondary = Color(0xFFB0B0B0);

  // ── Cards ────────────────────────────────────────────────────────────────

  /// Card fill colour – a rich dark blue that sits above the background.
  static const Color cardBackground = Color(0xFF16213E);

  /// Subtle border for cards and dividers.
  static const Color cardBorder = Color(0xFF2A2A4A);

  // ── Shimmer / Skeleton Loading ───────────────────────────────────────────

  /// Base colour for shimmer placeholders.
  static const Color shimmerBase = Color(0xFF1A1A2E);

  /// Highlight sweep colour for shimmer placeholders.
  static const Color shimmerHighlight = Color(0xFF2A2A4A);

  // ── Gradients ────────────────────────────────────────────────────────────

  /// Start colour for the primary vertical gradient.
  static const Color gradientStart = Color(0xFF0D1B2A);

  /// End colour for the primary vertical gradient.
  static const Color gradientEnd = Color(0xFF1A1A2E);

  // ── Convenience Gradient Objects ─────────────────────────────────────────

  /// Standard top-to-bottom background gradient.
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientStart, gradientEnd],
  );

  /// Horizontal accent gradient (amber → teal) for hero elements.
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentAmber, successTeal],
  );

  /// Overlay gradient used on images / maps so text remains legible.
  static LinearGradient get overlayGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          primaryBackground.withValues(alpha: 0.85),
        ],
      );
}
