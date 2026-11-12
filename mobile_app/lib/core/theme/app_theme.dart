import 'package:flutter/material.dart';

import 'app_colors.dart';

const String kHeadingFont = 'serif'; // Android system serif; swap for a bundled font if desired

ThemeData buildAppTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: AppColors.terracotta,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.terracotta,
    onPrimary: Colors.white,
    secondary: AppColors.sage,
    onSecondary: AppColors.charcoal,
    tertiary: AppColors.sandstone,
    onTertiary: AppColors.charcoal,
    surface: AppColors.white,
    onSurface: AppColors.charcoal,
    error: AppColors.error,
  );

  final TextTheme base = ThemeData(useMaterial3: true, brightness: Brightness.light)
      .textTheme
      .apply(bodyColor: AppColors.charcoal, displayColor: AppColors.charcoal);

  TextStyle? serif(TextStyle? s, {FontWeight weight = FontWeight.w700}) =>
      s?.copyWith(fontFamily: kHeadingFont, fontWeight: weight);

  final TextTheme textTheme = base.copyWith(
    displaySmall: serif(base.displaySmall),
    headlineLarge: serif(base.headlineLarge),
    headlineMedium: serif(base.headlineMedium),
    headlineSmall: serif(base.headlineSmall),
    titleLarge: serif(base.titleLarge),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
    bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
  );

  final RoundedRectangleBorder buttonShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ivory,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.ivory,
      foregroundColor: AppColors.charcoal,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.white,
      indicatorColor: AppColors.sandstone,
      elevation: 3,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.charcoal),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.terracotta,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 52),
        shape: buttonShape,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.terracotta,
        minimumSize: const Size(48, 52),
        side: const BorderSide(color: AppColors.terracotta, width: 1.4),
        shape: buttonShape,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.terracotta),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.charcoal,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.terracotta),
    dividerColor: AppColors.sandstone,
  );
}
