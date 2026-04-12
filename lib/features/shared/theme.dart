import 'package:flutter/material.dart';

const kPurple400 = Color(0xFF7F77DD);
const kPurple600 = Color(0xFF534AB7);
const kPurple800 = Color(0xFF3C3489);
const kSurface = Color(0xFF1A1A2E);
const kSurface2 = Color(0xFF12122A);
const kSurface3 = Color(0xFF2A2A45);
const kTextPrimary = Color(0xFFF7F3FF);
const kTextMuted = Color(0xFFA8A4C6);

ThemeData voxaTheme() {
  final scheme = const ColorScheme.dark(
    primary: kPurple400,
    secondary: kPurple600,
    surface: kSurface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kSurface,
    cardColor: kSurface3,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: kSurface3,
      behavior: SnackBarBehavior.floating,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: kTextPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: kTextPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: kTextPrimary,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: kTextPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: kTextMuted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface3,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
