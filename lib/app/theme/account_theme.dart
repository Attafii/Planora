import 'package:flutter/material.dart';

class PlanifyTheme {
  static const ink = Color(0xFF193530);
  static const blue = Color(0xFF227F6D);
  static const teal = Color(0xFF78DFB7);
  static const violet = Color(0xFFC98851);
  static const cream = Color(0xFFF7F7EE);
  static const lavender = Color(0xFFF5EADF);
  static const blueTint = Color(0xFFDDF1E5);
  static const tealTint = Color(0xFFE4F3E6);
  static const brandGradient = LinearGradient(colors: [blue, teal, violet]);
  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final foreground = dark ? cream : ink;
    final scheme = ColorScheme.fromSeed(seedColor: blue, brightness: brightness)
        .copyWith(
          primary: dark ? const Color(0xFF93E3BA) : ink,
          onPrimary: dark ? ink : Colors.white,
          primaryContainer: dark ? const Color(0xFF244B40) : blueTint,
          onPrimaryContainer: dark ? cream : ink,
          secondary: dark ? teal : const Color(0xFF216C59),
          secondaryContainer: dark ? const Color(0xFF214B3D) : tealTint,
          onSecondaryContainer: dark ? cream : ink,
          tertiary: violet,
          surface: dark ? const Color(0xFF192C27) : cream,
          onSurface: foreground,
          onSurfaceVariant: dark
              ? const Color(0xFFB5CDC1)
              : const Color(0xFF4B6559),
        );
    final body = ThemeData(brightness: brightness).textTheme.apply(
      fontFamily: 'Inter',
      bodyColor: foreground,
      displayColor: foreground,
    );
    TextStyle display(TextStyle? style) => style!.copyWith(
      fontFamily: 'Manrope',
      fontWeight: FontWeight.w700,
      letterSpacing: -.8,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF11211C) : cream,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
      ),
      scaffoldBackgroundColor: dark ? const Color(0xFF11211C) : cream,
      fontFamily: 'Inter',
      textTheme: body.copyWith(
        displayLarge: display(body.displayLarge),
        displayMedium: display(body.displayMedium),
        displaySmall: display(body.displaySmall),
        headlineLarge: display(body.headlineLarge),
        headlineMedium: display(body.headlineMedium),
        headlineSmall: display(body.headlineSmall),
        titleLarge: display(body.titleLarge),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF213832) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 19,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFC7D8CA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF3B554A) : const Color(0xFFC7D8CA),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: blue, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: dark ? const Color(0xFF93E3BA) : ink,
          foregroundColor: dark ? ink : Colors.white,
          minimumSize: const Size(48, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF1C322B) : Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? ink : Colors.white,
        indicatorColor: dark ? const Color(0xFF2D5547) : blueTint,
      ),
      dividerTheme: DividerThemeData(
        space: 32,
        thickness: .6,
        color: dark ? const Color(0xFF3B554A) : const Color(0xFFD8E3D7),
      ),
    );
  }
}
