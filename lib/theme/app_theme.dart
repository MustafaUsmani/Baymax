import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:crisis_link/theme/app_colors.dart';

/// Provides the single [ThemeData] used throughout CrisisLink.
///
/// Everything is Material 3, dark-first, and uses the brand palette defined in
/// [AppColors].
abstract final class AppTheme {
  // ────────────────────────────────────────────────────────────────────────
  // Colour Scheme
  // ────────────────────────────────────────────────────────────────────────

  static const ColorScheme _colorScheme = ColorScheme.dark(
    primary: AppColors.accentAmber,
    onPrimary: Colors.black,
    primaryContainer: Color(0xFF3D2E00),
    onPrimaryContainer: AppColors.accentAmber,
    secondary: AppColors.accentAmber,
    onSecondary: Colors.black,
    secondaryContainer: Color(0xFF3D2E00),
    onSecondaryContainer: AppColors.accentAmber,
    tertiary: AppColors.successTeal,
    onTertiary: Colors.black,
    tertiaryContainer: Color(0xFF003E3A),
    onTertiaryContainer: AppColors.successTeal,
    error: AppColors.emergencyRed,
    onError: Colors.white,
    errorContainer: Color(0xFF5C0D13),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: AppColors.secondarySurface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.cardBorder,
    outlineVariant: Color(0xFF1F1F3A),
    inverseSurface: Color(0xFFE0E0E0),
    onInverseSurface: AppColors.primaryBackground,
    inversePrimary: Color(0xFF6D4C00),
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: AppColors.accentAmber,
  );

  // ────────────────────────────────────────────────────────────────────────
  // Typography
  // ────────────────────────────────────────────────────────────────────────

  static TextTheme get _textTheme {
    final base = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: AppColors.textPrimary,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: AppColors.textPrimary,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: AppColors.textPrimary,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: AppColors.textSecondary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: AppColors.textSecondary,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.textSecondary,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.textSecondary,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Component Themes
  // ────────────────────────────────────────────────────────────────────────

  static final _cardTheme = CardThemeData(
    color: AppColors.cardBackground,
    elevation: 4,
    shadowColor: Colors.black54,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.cardBorder, width: 0.5),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  );

  static const _appBarTheme = AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
    iconTheme: IconThemeData(color: AppColors.textPrimary),
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
  );

  static final _bottomNavBarTheme = BottomNavigationBarThemeData(
    backgroundColor: AppColors.primaryBackground,
    selectedItemColor: AppColors.accentAmber,
    unselectedItemColor: AppColors.textSecondary,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
    selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
    unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400),
    showUnselectedLabels: true,
  );

  static final _navigationBarTheme = NavigationBarThemeData(
    backgroundColor: AppColors.primaryBackground,
    indicatorColor: AppColors.accentAmber.withValues(alpha: 0.15),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    height: 72,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(color: AppColors.accentAmber, size: 24);
      }
      return const IconThemeData(color: AppColors.textSecondary, size: 24);
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.accentAmber,
        );
      }
      return GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );
    }),
  );

  static final _inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.cardBackground,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.cardBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.cardBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.accentAmber, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.emergencyRed),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.emergencyRed, width: 1.5),
    ),
    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    errorStyle: const TextStyle(color: AppColors.emergencyRed, fontSize: 12),
    prefixIconColor: AppColors.textSecondary,
    suffixIconColor: AppColors.textSecondary,
  );

  static final _elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accentAmber,
      foregroundColor: Colors.black,
      disabledBackgroundColor: AppColors.accentAmber.withValues(alpha: 0.3),
      disabledForegroundColor: Colors.black45,
      elevation: 2,
      shadowColor: AppColors.accentAmber.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
  );

  static final _outlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.accentAmber,
      side: const BorderSide(color: AppColors.accentAmber),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  static final _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.accentAmber,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  static final _chipTheme = ChipThemeData(
    backgroundColor: AppColors.cardBackground,
    selectedColor: AppColors.accentAmber.withValues(alpha: 0.2),
    secondarySelectedColor: AppColors.accentAmber.withValues(alpha: 0.2),
    disabledColor: AppColors.cardBackground.withValues(alpha: 0.5),
    labelStyle: GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    secondaryLabelStyle: GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.accentAmber,
    ),
    side: const BorderSide(color: AppColors.cardBorder),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    showCheckmark: false,
  );

  static final _dialogTheme = DialogThemeData(
    backgroundColor: AppColors.secondarySurface,
    surfaceTintColor: Colors.transparent,
    elevation: 16,
    shadowColor: Colors.black87,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    contentTextStyle: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
  );

  static final _bottomSheetTheme = BottomSheetThemeData(
    backgroundColor: AppColors.secondarySurface,
    surfaceTintColor: Colors.transparent,
    modalBackgroundColor: AppColors.secondarySurface,
    elevation: 8,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    dragHandleColor: AppColors.textSecondary.withValues(alpha: 0.4),
    dragHandleSize: const Size(40, 4),
    showDragHandle: true,
  );

  static const _floatingActionButtonTheme = FloatingActionButtonThemeData(
    backgroundColor: AppColors.accentAmber,
    foregroundColor: Colors.black,
    elevation: 6,
    shape: CircleBorder(),
  );

  static const _iconTheme = IconThemeData(
    color: AppColors.textSecondary,
    size: 24,
  );

  static final _dividerTheme = DividerThemeData(
    color: AppColors.cardBorder.withValues(alpha: 0.5),
    thickness: 0.5,
    space: 1,
  );

  static const _tooltipTheme = TooltipThemeData(
    decoration: BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    textStyle: TextStyle(color: AppColors.textPrimary, fontSize: 12),
  );

  static final _snackBarTheme = SnackBarThemeData(
    backgroundColor: AppColors.cardBackground,
    contentTextStyle: GoogleFonts.inter(
      color: AppColors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  static const _tabBarTheme = TabBarThemeData(
    indicatorColor: AppColors.accentAmber,
    labelColor: AppColors.accentAmber,
    unselectedLabelColor: AppColors.textSecondary,
    indicatorSize: TabBarIndicatorSize.label,
    dividerColor: Colors.transparent,
  );

  static const _progressIndicatorTheme = ProgressIndicatorThemeData(
    color: AppColors.accentAmber,
    linearTrackColor: AppColors.cardBorder,
    circularTrackColor: AppColors.cardBorder,
  );

  static final _switchTheme = SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.accentAmber;
      return AppColors.textSecondary;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.accentAmber.withValues(alpha: 0.4);
      }
      return AppColors.cardBorder;
    }),
  );

  static final _checkboxTheme = CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.accentAmber;
      return Colors.transparent;
    }),
    checkColor: WidgetStateProperty.all(Colors.black),
    side: const BorderSide(color: AppColors.textSecondary, width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  );

  // ────────────────────────────────────────────────────────────────────────
  // Public Theme Getter
  // ────────────────────────────────────────────────────────────────────────

  /// The single dark [ThemeData] that the app passes to [MaterialApp.theme].
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: AppColors.primaryBackground,
      textTheme: _textTheme,
      cardTheme: _cardTheme,
      appBarTheme: _appBarTheme,
      bottomNavigationBarTheme: _bottomNavBarTheme,
      navigationBarTheme: _navigationBarTheme,
      inputDecorationTheme: _inputDecorationTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      chipTheme: _chipTheme,
      dialogTheme: _dialogTheme,
      bottomSheetTheme: _bottomSheetTheme,
      floatingActionButtonTheme: _floatingActionButtonTheme,
      iconTheme: _iconTheme,
      dividerTheme: _dividerTheme,
      tooltipTheme: _tooltipTheme,
      snackBarTheme: _snackBarTheme,
      tabBarTheme: _tabBarTheme,
      progressIndicatorTheme: _progressIndicatorTheme,
      switchTheme: _switchTheme,
      checkboxTheme: _checkboxTheme,
      splashColor: AppColors.accentAmber.withValues(alpha: 0.08),
      highlightColor: AppColors.accentAmber.withValues(alpha: 0.05),
    );
  }
}
