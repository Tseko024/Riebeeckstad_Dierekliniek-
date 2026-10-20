import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static TextStyle tagline({double size = 22}) => GoogleFonts.kaushanScript(
        fontSize: size,
        color: AppColors.navy,
      );

  static TextStyle heading({double size = 28}) => GoogleFonts.dmSerifDisplay(
        fontSize: size,
        color: AppColors.navy,
      );

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navy,
        primary: AppColors.navy,
        secondary: AppColors.red,
        surface: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      // Body text in the mockups is a soft serif.
      textTheme: GoogleFonts.gelasioTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.navy,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
