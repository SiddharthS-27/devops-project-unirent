import 'package:flutter/material.dart';

/// Raw colour palette. Widgets should normally read colours from the theme
/// (`Theme.of(context).colorScheme` or [StatusColors]) rather than from here.
///
/// The chrome holds no brand colour: ink on an off-white ground, a
/// near-black primary action, and one hue ([accent]) kept for the thing the
/// screen is about (the current step, the next action). Status colours are
/// pale tints with dark text of the same hue.
abstract final class AppColors {
  // Light.
  static const Color ground = Color(0xFFF5F4F1);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLow = Color(0xFFFAFAF8);
  static const Color raised = Color(0xFFECEBE8);
  static const Color border = Color(0xFFE4E3DF);
  static const Color rule = Color(0xFFEFEEEB);
  static const Color control = Color(0xFFD3D2CE);
  static const Color ink = Color(0xFF0A0A0A);
  static const Color primary = Color(0xFF141414);
  static const Color muted = Color(0xFF666666);
  static const Color onRaised = Color(0xFF3D3D3D);

  /// The one hue. Appears on the main data element only.
  static const Color accent = Color(0xFF1D5FBF);
  static const Color accentTint = Color(0xFFE6EEFB);
  static const Color onAccentTint = Color(0xFF0B2F6B);

  static const Color star = Color(0xFFE09A1B);

  static const Color successLight = Color(0xFF247B50);
  static const Color successContainerLight = Color(0xFFDCFAE5);
  static const Color onSuccessContainerLight = Color(0xFF04250E);
  static const Color warningLight = Color(0xFF92400E);
  static const Color warningContainerLight = Color(0xFFFFFBEB);
  static const Color onWarningContainerLight = Color(0xFF92400E);
  static const Color dangerLight = Color(0xFFC4242A);
  static const Color dangerContainerLight = Color(0xFFFFEDEA);
  static const Color onDangerContainerLight = Color(0xFF831C1E);

  // Dark: true neutrals, lightness steps for surfaces, colour on data only.
  static const Color groundDark = Color(0xFF111111);
  static const Color surfaceDark = Color(0xFF1A1A1A);
  static const Color surfaceLowDark = Color(0xFF161616);
  static const Color raisedDark = Color(0xFF2A2A2A);
  static const Color borderDark = Color(0xFF2E2E2E);
  static const Color ruleDark = Color(0xFF242424);
  static const Color controlDark = Color(0xFF444444);
  static const Color inkDark = Color(0xFFFFFFFF);
  static const Color primaryDark = Color(0xFFFFFFFF);
  static const Color mutedDark = Color(0xFFB4B4B4);
  static const Color onRaisedDark = Color(0xFFD4D4D4);
  static const Color accentDark = Color(0xFF7FB0F5);
  static const Color accentTintDark = Color(0xFF17273F);
  static const Color onAccentTintDark = Color(0xFFBCD4F7);

  static const Color successDark = Color(0xFF3FC07A);
  static const Color successContainerDark = Color(0xFF172A1D);
  static const Color onSuccessContainerDark = Color(0xFF3FC07A);
  static const Color warningDark = Color(0xFFF2B544);
  static const Color warningContainerDark = Color(0xFF2B2211);
  static const Color onWarningContainerDark = Color(0xFFF2B544);
  static const Color dangerDark = Color(0xFFF0708A);
  static const Color dangerContainerDark = Color(0xFF2C1A20);
  static const Color onDangerContainerDark = Color(0xFFF0708A);
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

/// Corner radii: one tight pair (cards 8, controls 6), tags at 4.
abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double pill = 999;
}

/// Fixed component sizes.
abstract final class AppSizes {
  /// Minimum interactive target (Material accessibility guideline).
  static const double minTouchTarget = 48;
  static const double buttonHeight = 48;
  static const double iconXs = 14;
  static const double iconSm = 16;
  static const double iconMd = 22;
  static const double iconLg = 32;
}

/// Type scale, set in Geist (bundled). Colours are applied by the theme.
///
/// Titles stop at 28; figures never exceed 32. Weight 700 is for money and
/// the one code on a screen; everything else is 400–600.
abstract final class AppTypography {
  static const String fontFamily = 'Geist';

  /// Equal-width digits, for numbers that change in place (timers, codes)
  /// or line up in columns.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  static const TextTheme textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -0.5,
      fontFeatures: tabularFigures,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.6,
      fontFeatures: tabularFigures,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.25,
      letterSpacing: -0.4,
      fontFeatures: tabularFigures,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3,
      letterSpacing: -0.3,
      fontFeatures: tabularFigures,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: -0.1,
      fontFeatures: tabularFigures,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0,
      fontFeatures: tabularFigures,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.5,
      letterSpacing: 0,
      fontFeatures: tabularFigures,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.45,
      letterSpacing: 0,
      fontFeatures: tabularFigures,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.4,
      letterSpacing: 0,
      fontFeatures: tabularFigures,
    ),
    labelLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: 0,
      fontFeatures: tabularFigures,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.3,
      letterSpacing: 0,
      fontFeatures: tabularFigures,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.3,
      letterSpacing: 0,
      fontFeatures: tabularFigures,
    ),
  );
}
