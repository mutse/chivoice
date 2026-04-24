import 'package:flutter/material.dart';

import '../settings/settings_provider.dart';

const kPaper = Color(0xFFF8F2E6);
const kPaperDeep = Color(0xFFF1E7D7);
const kPaperLine = Color(0xFFE0D2BC);
const kInk = Color(0xFF223025);
const kInkSoft = Color(0xFF687465);
const kPanel = Color(0xFFFFFCF6);
const kWash = Color(0x66C8D3BE);

ThemeData voxaTheme(AppSkin skin) {
  final primary = Color(skin.primaryValue);
  final secondary = Color(skin.secondaryValue);
  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.light,
    primary: primary,
    secondary: secondary,
    surface: kPaper,
    onSurface: kInk,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kPaper,
    cardColor: kPanel,
    dividerColor: kPaperLine,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: kInk,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamilyFallback: ['Noto Serif SC', 'Songti SC', 'serif'],
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: kInk,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: primary,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontFamilyFallback: ['Noto Serif SC', 'Songti SC', 'serif'],
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: kInk,
      ),
      headlineMedium: TextStyle(
        fontFamilyFallback: ['Noto Serif SC', 'Songti SC', 'serif'],
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: kInk,
      ),
      titleMedium: TextStyle(
        fontFamilyFallback: ['Noto Serif SC', 'Songti SC', 'serif'],
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: kInk,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.7, color: kInk),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: kInkSoft),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: kInkSoft),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.84),
      hintStyle: const TextStyle(color: kInkSoft),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: kPaperLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: kPaperLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: primary, width: 1.4),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.82),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kInk,
        side: const BorderSide(color: kPaperLine),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return kPaperLine;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary;
        }
        return kPaperLine;
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      inactiveTrackColor: kPaperLine,
      thumbColor: primary,
      overlayColor: primary.withValues(alpha: 0.18),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: Colors.transparent,
      indicatorColor: secondary.withValues(alpha: 0.3),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.selected)
            ? primary
            : kInkSoft;
        return IconThemeData(color: color);
      }),
    ),
  );
}
