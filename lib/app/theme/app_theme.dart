// Hallmark · pre-emit critique: P4 H4 E4 S5 R5 V4
import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.ink).copyWith(
      primary: AppColors.ink,
      secondary: AppColors.violet,
      surface: AppColors.surface,
      error: AppColors.error,
      onSurface: AppColors.ink,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.paper,
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 36,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: AppColors.ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: AppColors.ink),
        bodySmall: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 32),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.tint,
      ),
    );
  }
}
