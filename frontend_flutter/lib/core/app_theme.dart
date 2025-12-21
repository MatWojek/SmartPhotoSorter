import 'package:flutter/material.dart';
import 'theme.dart';

ThemeData classicLightTheme() {
  final scheme = ColorScheme.light(
    primary: ClassicStyle.blue,
    onPrimary: Colors.white,
    secondary: ClassicStyle.medium_blue,
    onSecondary: Colors.white,
    tertiary: ClassicStyle.light_blue,
    onTertiary: Colors.black,
    surface: Colors.white,
    onSurface: Colors.black87,
    error: Colors.red.shade700,
    onError: Colors.white,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(elevation: 0),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary),
      ),
    ),
    dividerColor: scheme.secondary.withOpacity(0.2),
  );
}

ThemeData classicDarkTheme() {
  final surface = const Color(0xFF121212);
  final background = const Color(0xFF0E0E12);
  final scheme = ColorScheme.dark(
    primary: ClassicStyle.navy,
    onPrimary: ClassicStyle.new_white,
    secondary: ClassicStyle.violet,
    onSecondary: ClassicStyle.new_white,
    surface: surface,
    onSurface: ClassicStyle.new_white,
    error: Colors.red.shade400,
    onError: ClassicStyle.new_white,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(elevation: 0),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.onSurface),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.onSurface),
      ),
    ),
    dividerColor: scheme.onSurface,
  );
}
