import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// OCEN Design System
/// Minimal, high-contrast black & white. No gradients. No bright colors.
class AppColors {
  AppColors._();

  // ── Core palette ─────────────────────────────────────────────────────────
  static const Color background     = Color(0xFFF4F4F6); // Page background
  static const Color cardDark       = Color(0xFF1A1A1A); // Featured dark card
  static const Color cardLight      = Color(0xFFFFFFFF); // Default white card
  static const Color cardSecondary  = Color(0xFFEFEFEF); // Soft gray card
  static const Color surface        = Color(0xFFFFFFFF);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFF1A1A1A);
  static const Color textSecondary  = Color(0xFF8A8A8A);
  static const Color textOnDark     = Color(0xFFFFFFFF);
  static const Color textHint       = Color(0xFFBBBBBB);

  // ── UI elements ───────────────────────────────────────────────────────────
  static const Color divider        = Color(0xFFE8E8E8);
  static const Color pillActive     = Color(0xFF1A1A1A); // Active pill/badge
  static const Color pillInactive   = Color(0xFFEFEFEF);
  static const Color timelineLine   = Color(0xFFE0E0E0);
  static const Color checkboxActive = Color(0xFF1A1A1A);

  // ── Semantic / status colors (muted for B&W palette) ─────────────────────
  static const Color error          = Color(0xFFC62828); // Deep red
  static const Color warning        = Color(0xFFBF360C); // Deep orange-red
  static const Color success        = Color(0xFF2E7D32); // Deep green

  // ── Convenience aliases ───────────────────────────────────────────────────
  static const Color primary        = Color(0xFF1A1A1A);
  static const Color accent         = Color(0xFF1A1A1A);
}

class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,

      // ── Colour scheme ────────────────────────────────────────────────────
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.cardDark,
        primary: AppColors.cardDark,
        onPrimary: Colors.white,
        secondary: AppColors.cardDark,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: const Color(0xFFC62828),
        brightness: Brightness.light,
      ),

      scaffoldBackgroundColor: AppColors.background,

      // ── AppBar ───────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      // ── Card ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        color: AppColors.cardLight,
        margin: EdgeInsets.zero,
        shadowColor: Colors.black12,
      ),

      // ── FAB ──────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.cardDark,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),

      // ── Elevated button ──────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cardDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Outlined button ──────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.divider, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Text button ──────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: AppColors.cardDark, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),

      // ── TabBar ───────────────────────────────────────────────────────────
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.cardDark,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),

      // ── Chip ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.pillInactive,
        labelStyle: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      // ── Checkbox ─────────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.checkboxActive
                : Colors.transparent),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: AppColors.divider, width: 1.5),
      ),

      // ── Divider ──────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ── Text ─────────────────────────────────────────────────────────────
      textTheme: const TextTheme(
        // Page title: "Today", "Lịch của tôi"
        headlineLarge: TextStyle(
          fontSize: 32, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary, letterSpacing: -0.5,
        ),
        // Section titles
        headlineMedium: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary, letterSpacing: -0.3,
        ),
        // Card title
        titleLarge: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        // Section label
        titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        // Body
        bodyLarge: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        // Subtitle / secondary body
        bodyMedium: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        // Time label, small tags
        bodySmall: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary, letterSpacing: 0.1,
        ),
        labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500,
          color: AppColors.textHint, letterSpacing: 0.4,
        ),
      ),
    );
  }
}
