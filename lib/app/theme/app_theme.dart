import 'package:flutter/material.dart';

class PlanifyTheme {
  static const ink = Color(0xFF051B47);
  static const blue = Color(0xFF3B82F6);
  static const teal = Color(0xFF00D1B2);
  static const violet = Color(0xFF8B5CF6);
  static const cream = Color(0xFFFAF9F6);
  static const lavender = Color(0xFFEDE7FC);
  static const blueTint = Color(0xFFE6EEFF);
  static const tealTint = Color(0xFFDDF8F3);
  static const brandGradient = LinearGradient(colors: [blue, teal, violet]);
  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final foreground = dark ? cream : ink;
    final scheme = ColorScheme.fromSeed(seedColor: blue, brightness: brightness)
        .copyWith(
          primary: dark ? const Color(0xFF9BBEFF) : ink,
          onPrimary: dark ? ink : Colors.white,
          primaryContainer: dark ? const Color(0xFF19386B) : blueTint,
          onPrimaryContainer: dark ? cream : ink,
          secondary: dark ? teal : const Color(0xFF007E72),
          secondaryContainer: dark ? const Color(0xFF103E48) : tealTint,
          onSecondaryContainer: dark ? cream : ink,
          tertiary: violet,
          surface: dark ? const Color(0xFF0B2249) : cream,
          onSurface: foreground,
          onSurfaceVariant: dark
              ? const Color(0xFFBECBE1)
              : const Color(0xFF51617B),
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
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF061733) : cream,
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
        fillColor: dark ? const Color(0xFF102950) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 19,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFCFD8E7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF344B70) : const Color(0xFFCFD8E7),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: blue, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: dark ? const Color(0xFF9BBEFF) : ink,
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
        color: dark ? const Color(0xFF10264B) : Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? ink : Colors.white,
        indicatorColor: dark ? const Color(0xFF24467E) : blueTint,
      ),
      dividerTheme: DividerThemeData(
        space: 32,
        thickness: .6,
        color: dark ? const Color(0xFF344B70) : const Color(0xFFDDE3ED),
      ),
    );
  }
}
