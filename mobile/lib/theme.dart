import 'package:flutter/material.dart';

/// Premium Indian palette:
/// deep maroon, heritage gold, ivory silk, peacock teal.
class AppColors {
  static const maroon = Color(0xFF6D1B2D); // primary - deep kumkum maroon
  static const maroonDark = Color(0xFF4E1220);
  static const gold = Color(0xFFC99A3C); // heritage gold
  static const goldLight = Color(0xFFE8CE93);
  static const ivory = Color(0xFFFAF4E8); // ivory silk background
  static const cream = Color(0xFFFFFBF2);
  static const peacock = Color(0xFF14655A); // peacock teal
  static const textDark = Color(0xFF2B1B12); // deep brown text
  static const textMuted = Color(0xFF6B5A4E);
  static const danger = Color(0xFFA8322D);
}

/// Elderly-friendly sizing: large fonts, 56px touch targets, high contrast.
ThemeData buildAppTheme() {
  const textTheme = TextTheme(
    displaySmall: TextStyle(
        fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textDark),
    headlineMedium: TextStyle(
        fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark),
    titleLarge: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textDark),
    titleMedium: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textDark),
    bodyLarge: TextStyle(fontSize: 19, color: AppColors.textDark, height: 1.4),
    bodyMedium: TextStyle(fontSize: 17, color: AppColors.textDark, height: 1.4),
    labelLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.ivory,
    colorScheme: const ColorScheme.light(
      primary: AppColors.maroon,
      onPrimary: Colors.white,
      secondary: AppColors.gold,
      onSecondary: AppColors.textDark,
      tertiary: AppColors.peacock,
      surface: AppColors.cream,
      onSurface: AppColors.textDark,
      error: AppColors.danger,
    ),
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.maroon,
      foregroundColor: Colors.white,
      centerTitle: true,
      titleTextStyle: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(60),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.maroon,
        minimumSize: const Size.fromHeight(60),
        side: const BorderSide(color: AppColors.maroon, width: 2),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.peacock,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      labelStyle: const TextStyle(fontSize: 18, color: AppColors.textMuted),
      hintStyle: const TextStyle(fontSize: 18, color: AppColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.gold),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.maroon, width: 2.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cream,
      elevation: 2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.goldLight, width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 16,
      titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textDark),
      subtitleTextStyle: TextStyle(fontSize: 16, color: AppColors.textMuted),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cream,
      titleTextStyle: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
      contentTextStyle:
          const TextStyle(fontSize: 18, color: AppColors.textDark, height: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.textDark,
      contentTextStyle: TextStyle(fontSize: 18, color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.gold,
      foregroundColor: AppColors.textDark,
      extendedTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
    ),
  );
}
