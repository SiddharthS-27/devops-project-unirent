import 'package:flutter/material.dart';

/// Raw colour palette. Widgets should normally read colours from the theme
/// (`Theme.of(context).colorScheme` or [StatusColors]) rather than from here.
abstract final class AppColors {
  /// Brand seed colour; the Material colour scheme is generated from it.
  static const Color brand = Color(0xFF3949AB);

  static const Color star = Color(0xFFF5A623);

  static const Color successLight = Color(0xFF1B7F3B);
  static const Color successContainerLight = Color(0xFFD5F5DD);
  static const Color onSuccessContainerLight = Color(0xFF00391A);
  static const Color warningLight = Color(0xFF9A5B00);
  static const Color warningContainerLight = Color(0xFFFFE6C2);
  static const Color onWarningContainerLight = Color(0xFF3D2300);
  static const Color dangerLight = Color(0xFFBA1A1A);
  static const Color dangerContainerLight = Color(0xFFFFDAD6);
  static const Color onDangerContainerLight = Color(0xFF410002);

  static const Color successDark = Color(0xFF7FDA97);
  static const Color successContainerDark = Color(0xFF00522A);
  static const Color onSuccessContainerDark = Color(0xFFA2F7B4);
  static const Color warningDark = Color(0xFFFFB95C);
  static const Color warningContainerDark = Color(0xFF5C3700);
  static const Color onWarningContainerDark = Color(0xFFFFDDB3);
  static const Color dangerDark = Color(0xFFFFB4AB);
  static const Color dangerContainerDark = Color(0xFF93000A);
  static const Color onDangerContainerDark = Color(0xFFFFDAD6);
}

/// Spacing scale (logical pixels), based on a 4pt grid.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Default horizontal padding for screen content.
  static const double screen = lg;
}

/// Corner radii.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

/// Fixed component sizes.
abstract final class AppSizes {
  /// Minimum interactive target (Material accessibility guideline).
  static const double minTouchTarget = 48;
  static const double buttonHeight = 52;
  static const double iconSm = 16;
  static const double iconMd = 24;
  static const double iconLg = 48;
}

/// Type scale. Colours are applied by the theme.
abstract final class AppTypography {
  static const TextTheme textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.25,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45),
    bodySmall: TextStyle(fontSize: 12, height: 1.4),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  );

  /// Equal-width digits, for numbers that change in place (timers, codes).
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];
}
