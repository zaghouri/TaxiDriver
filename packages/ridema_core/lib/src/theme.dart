import 'package:flutter/material.dart';

import '../brand.dart';

/// Minimum height of every tappable control (Material asks for 48; we use 56 for
/// cheap phones, gloves, one-handed use while standing on a pavement).
const double kTapTarget = 56;

/// Light Material 3 theme for both apps.
///
/// Big tap targets, high-contrast text, 16sp+ body text, no thin fonts:
/// readable on low-end Android screens in sunlight.
ThemeData buildRideMaTheme({Brightness brightness = Brightness.light}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: BrandColors.primary,
    brightness: brightness,
  ).copyWith(
    primary: BrandColors.primary,
    onPrimary: Colors.white,
    secondary: BrandColors.accent,
    onSecondary: BrandColors.ink,
    tertiary: BrandColors.accent,
    error: BrandColors.danger,
    surface: Colors.white,
    onSurface: BrandColors.ink,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: Colors.white,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );

  final text = base.textTheme.apply(bodyColor: BrandColors.ink, displayColor: BrandColors.ink).copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 17, height: 1.4, color: BrandColors.ink),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 16, height: 1.4, color: BrandColors.ink),
        titleLarge: base.textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w700, color: BrandColors.ink),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: BrandColors.ink),
        labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
      );

  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  const buttonSize = Size(64, kTapTarget);

  return base.copyWith(
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: BrandColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: BrandColors.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        backgroundColor: BrandColors.primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(minimumSize: buttonSize, shape: buttonShape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        foregroundColor: BrandColors.primary,
        side: const BorderSide(color: BrandColors.primary, width: 1.5),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: BrandColors.primary,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BrandColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD0D7D4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BrandColors.primary, width: 2),
      ),
      labelStyle: const TextStyle(fontSize: 16),
    ),
    checkboxTheme: CheckboxThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? BrandColors.primary : null,
      ),
    ),
    listTileTheme: const ListTileThemeData(minVerticalPadding: 12, minTileHeight: kTapTarget),
    cardTheme: CardThemeData(
      elevation: 0,
      color: BrandColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
