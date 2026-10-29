import 'package:flutter/material.dart';

import 'tokens.dart';

/// Semantic status colours that Material's [ColorScheme] does not cover.
///
/// Each status is a text colour (`success`) plus a pale pill pair
/// (`successContainer` with `onSuccessContainer`).
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.onDangerContainer,
  });

  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color danger;
  final Color dangerContainer;
  final Color onDangerContainer;

  static const StatusColors light = StatusColors(
    success: AppColors.successLight,
    successContainer: AppColors.successContainerLight,
    onSuccessContainer: AppColors.onSuccessContainerLight,
    warning: AppColors.warningLight,
    warningContainer: AppColors.warningContainerLight,
    onWarningContainer: AppColors.onWarningContainerLight,
    danger: AppColors.dangerLight,
    dangerContainer: AppColors.dangerContainerLight,
    onDangerContainer: AppColors.onDangerContainerLight,
  );

  static const StatusColors dark = StatusColors(
    success: AppColors.successDark,
    successContainer: AppColors.successContainerDark,
    onSuccessContainer: AppColors.onSuccessContainerDark,
    warning: AppColors.warningDark,
    warningContainer: AppColors.warningContainerDark,
    onWarningContainer: AppColors.onWarningContainerDark,
    danger: AppColors.dangerDark,
    dangerContainer: AppColors.dangerContainerDark,
    onDangerContainer: AppColors.onDangerContainerDark,
  );

  /// The status colours of the ambient theme, falling back to [light].
  static StatusColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<StatusColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  StatusColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? danger,
    Color? dangerContainer,
    Color? onDangerContainer,
  }) {
    return StatusColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
    );
  }

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return StatusColors(
      success: mix(success, other.success),
      successContainer: mix(successContainer, other.successContainer),
      onSuccessContainer: mix(onSuccessContainer, other.onSuccessContainer),
      warning: mix(warning, other.warning),
      warningContainer: mix(warningContainer, other.warningContainer),
      onWarningContainer: mix(onWarningContainer, other.onWarningContainer),
      danger: mix(danger, other.danger),
      dangerContainer: mix(dangerContainer, other.dangerContainer),
      onDangerContainer: mix(onDangerContainer, other.onDangerContainer),
    );
  }
}

/// Surface roles the Material colour scheme has no name for.
@immutable
class AppSurfaces extends ThemeExtension<AppSurfaces> {
  const AppSurfaces({
    required this.ground,
    required this.rule,
    required this.accent,
    required this.accentTint,
    required this.onAccentTint,
  });

  /// The page background behind cards.
  final Color ground;

  /// Row rules inside lists and tables: one step lighter than a border.
  final Color rule;

  /// The one hue, for the main data element only.
  final Color accent;
  final Color accentTint;
  final Color onAccentTint;

  static const AppSurfaces light = AppSurfaces(
    ground: AppColors.ground,
    rule: AppColors.rule,
    accent: AppColors.accent,
    accentTint: AppColors.accentTint,
    onAccentTint: AppColors.onAccentTint,
  );

  static const AppSurfaces dark = AppSurfaces(
    ground: AppColors.groundDark,
    rule: AppColors.ruleDark,
    accent: AppColors.accentDark,
    accentTint: AppColors.accentTintDark,
    onAccentTint: AppColors.onAccentTintDark,
  );

  static AppSurfaces of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppSurfaces>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  AppSurfaces copyWith({
    Color? ground,
    Color? rule,
    Color? accent,
    Color? accentTint,
    Color? onAccentTint,
  }) {
    return AppSurfaces(
      ground: ground ?? this.ground,
      rule: rule ?? this.rule,
      accent: accent ?? this.accent,
      accentTint: accentTint ?? this.accentTint,
      onAccentTint: onAccentTint ?? this.onAccentTint,
    );
  }

  @override
  AppSurfaces lerp(AppSurfaces? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSurfaces(
      ground: mix(ground, other.ground),
      rule: mix(rule, other.rule),
      accent: mix(accent, other.accent),
      accentTint: mix(accentTint, other.accentTint),
      onAccentTint: mix(onAccentTint, other.onAccentTint),
    );
  }
}

/// UniRent light and dark themes.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ColorScheme _scheme(Brightness brightness) {
    if (brightness == Brightness.light) {
      return const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.accentTint,
        onPrimaryContainer: AppColors.onAccentTint,
        secondary: AppColors.muted,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.raised,
        onSecondaryContainer: AppColors.onRaised,
        tertiary: AppColors.warningLight,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.warningContainerLight,
        onTertiaryContainer: AppColors.onWarningContainerLight,
        error: AppColors.dangerLight,
        onError: Colors.white,
        errorContainer: AppColors.dangerContainerLight,
        onErrorContainer: AppColors.onDangerContainerLight,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.muted,
        surfaceDim: AppColors.border,
        surfaceBright: AppColors.surface,
        surfaceContainerLowest: AppColors.surface,
        surfaceContainerLow: AppColors.surfaceLow,
        surfaceContainer: AppColors.ground,
        surfaceContainerHigh: AppColors.raised,
        surfaceContainerHighest: AppColors.border,
        outline: AppColors.control,
        outlineVariant: AppColors.border,
        inverseSurface: AppColors.surfaceDark,
        onInverseSurface: Colors.white,
        inversePrimary: Colors.white,
        shadow: Colors.black,
        scrim: Colors.black,
        surfaceTint: Colors.transparent,
      );
    }
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primaryDark,
      onPrimary: AppColors.ink,
      primaryContainer: AppColors.accentTintDark,
      onPrimaryContainer: AppColors.onAccentTintDark,
      secondary: AppColors.mutedDark,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.raisedDark,
      onSecondaryContainer: AppColors.onRaisedDark,
      tertiary: AppColors.warningDark,
      onTertiary: AppColors.ink,
      tertiaryContainer: AppColors.warningContainerDark,
      onTertiaryContainer: AppColors.onWarningContainerDark,
      error: AppColors.dangerDark,
      onError: AppColors.surfaceDark,
      errorContainer: AppColors.dangerContainerDark,
      onErrorContainer: AppColors.onDangerContainerDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.inkDark,
      onSurfaceVariant: AppColors.mutedDark,
      surfaceDim: AppColors.groundDark,
      surfaceBright: AppColors.raisedDark,
      surfaceContainerLowest: AppColors.groundDark,
      surfaceContainerLow: AppColors.surfaceLowDark,
      surfaceContainer: AppColors.surfaceDark,
      surfaceContainerHigh: AppColors.raisedDark,
      surfaceContainerHighest: AppColors.controlDark,
      outline: AppColors.controlDark,
      outlineVariant: AppColors.borderDark,
      inverseSurface: AppColors.surface,
      onInverseSurface: AppColors.ink,
      inversePrimary: AppColors.primary,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = _scheme(brightness);
    final surfaces = dark ? AppSurfaces.dark : AppSurfaces.light;
    // Component themes take styles from here, so the face must be on them.
    final text = AppTypography.textTheme.apply(
      fontFamily: AppTypography.fontFamily,
    );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: scheme.outlineVariant),
    );
    const buttonMinSize = Size(64, AppSizes.buttonHeight);
    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpacing.lg);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: scheme.outline),
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: surfaces.ground,
      canvasColor: surfaces.ground,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: [dark ? StatusColors.dark : StatusColors.light, surfaces],
      iconTheme: IconThemeData(color: scheme.onSurface, size: AppSizes.iconMd),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: surfaces.ground,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
        toolbarHeight: 56,
        titleSpacing: AppSpacing.screen,
        iconTheme: IconThemeData(
          color: scheme.onSurface,
          size: AppSizes.iconMd,
        ),
        actionsIconTheme: IconThemeData(
          color: scheme.onSurface,
          size: AppSizes.iconMd,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.onSurface,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: scheme.outlineVariant,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        overlayColor: WidgetStatePropertyAll(
          scheme.onSurface.withValues(alpha: 0.04),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.surfaceContainerHigh,
        indicatorShape: controlShape,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: AppSizes.iconMd,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: text.labelLarge,
          foregroundColor: scheme.onSurface,
          backgroundColor: scheme.surface,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: controlShape,
          textStyle: text.labelLarge,
          foregroundColor: scheme.onSurface,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          shape: controlShape,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: scheme.surface,
          selectedBackgroundColor: scheme.surfaceContainerHigh,
          foregroundColor: scheme.onSurfaceVariant,
          selectedForegroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          shape: controlShape,
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w500),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 2,
        extendedTextStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primary,
        disabledColor: scheme.surfaceContainerHigh,
        checkmarkColor: scheme.onPrimary,
        deleteIconColor: scheme.onSurfaceVariant,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        labelStyle: text.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        secondaryLabelStyle: text.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: scheme.onPrimary,
        ),
        iconTheme: IconThemeData(
          size: AppSizes.iconSm,
          color: scheme.onSurfaceVariant,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        showCheckmark: true,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.onSurface, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: text.bodySmall?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        iconColor: scheme.onSurfaceVariant,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        titleTextStyle: text.bodyLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: text.bodySmall?.copyWith(
          fontSize: 13,
          color: scheme.onSurfaceVariant,
        ),
        leadingAndTrailingTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screen,
        ),
        minVerticalPadding: AppSpacing.md,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        shape: Border(),
        collapsedShape: Border(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: text.titleLarge?.copyWith(
          fontSize: 18,
          color: scheme.onSurface,
        ),
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        textStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: dark ? AppColors.accent : AppColors.accentDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.onSurface,
        linearTrackColor: scheme.outlineVariant,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 3,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHigh,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: scheme.outline, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.outline,
        ),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: AppColors.dangerLight,
        textColor: Colors.white,
        textStyle: text.labelSmall,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.onSurface,
        selectionColor: surfaces.accentTint,
        selectionHandleColor: scheme.onSurface,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}
