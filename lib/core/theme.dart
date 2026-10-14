import 'package:flutter/material.dart';

import 'tokens.dart';

export 'tokens.dart';

/// The design system on [ThemeData]: the palette for the current brightness and the board
/// colours the player picked. Read it through [HcContext].
@immutable
class HcTheme extends ThemeExtension<HcTheme> {
  const HcTheme({required this.palette, this.board = HcBoardThemes.hamduk});

  final HcPalette palette;
  final HcBoardTheme board;

  @override
  HcTheme copyWith({HcPalette? palette, HcBoardTheme? board}) =>
      HcTheme(palette: palette ?? this.palette, board: board ?? this.board);

  @override
  HcTheme lerp(ThemeExtension<HcTheme>? other, double t) {
    if (other is! HcTheme) return this;
    return t < 0.5 ? this : other;
  }
}

extension HcContext on BuildContext {
  /// The current palette: `context.hc.surface2`, `context.hc.goldInk`, …
  HcPalette get hc {
    final theme = Theme.of(this);
    return theme.extension<HcTheme>()?.palette ?? HcPalette.of(theme.brightness);
  }

  /// The board colours for the player's chosen board theme.
  HcBoardTheme get hcBoard => Theme.of(this).extension<HcTheme>()?.board ?? HcBoardThemes.hamduk;
}

/// Builds the whole app theme from the design system tokens.
ThemeData buildTheme(Brightness brightness, {HcBoardTheme board = HcBoardThemes.hamduk}) {
  final p = HcPalette.of(brightness);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.green,
    onPrimary: p.onGreen,
    primaryContainer: p.greenSoft,
    onPrimaryContainer: p.green,
    secondary: p.gold,
    onSecondary: p.onGold,
    // Material 3 uses the secondary container for the nav indicator, selected chips and
    // tonal buttons; in this system those are all green-soft.
    secondaryContainer: p.greenSoft,
    onSecondaryContainer: p.green,
    tertiary: p.gold,
    onTertiary: p.onGold,
    tertiaryContainer: p.goldSoft,
    onTertiaryContainer: p.goldInk,
    error: p.dangerInk,
    onError: p.onDanger,
    errorContainer: p.dangerSoft,
    onErrorContainer: p.dangerInk,
    surface: p.surface,
    onSurface: p.ink,
    surfaceContainerLowest: p.bg,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surface2,
    surfaceContainerHighest: p.surface2,
    onSurfaceVariant: p.ink2,
    outline: p.lineControl,
    outlineVariant: p.line,
    inverseSurface: p.ink,
    onInverseSurface: p.bg,
    inversePrimary: p.isDark ? HcPalette.light.green : HcPalette.dark.green,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  TextStyle ink(TextStyle s, [Color? color]) => s.copyWith(color: color ?? p.ink);

  final textTheme = TextTheme(
    displayLarge: ink(HcText.displayXl),
    displayMedium: ink(HcText.displayLg),
    displaySmall: ink(HcText.displayMd),
    headlineLarge: ink(HcText.displayLg),
    headlineMedium: ink(HcText.displayMd),
    headlineSmall: ink(HcText.titleLg),
    titleLarge: ink(HcText.titleLg),
    titleMedium: ink(HcText.titleMd),
    titleSmall: ink(HcText.titleSm),
    bodyLarge: ink(HcText.bodyLg),
    bodyMedium: ink(HcText.body),
    bodySmall: ink(HcText.bodySm, p.ink2),
    labelLarge: ink(HcText.label.copyWith(fontSize: 15, height: 20 / 15, letterSpacing: 0)),
    labelMedium: ink(HcText.label),
    labelSmall: ink(HcText.overline.copyWith(letterSpacing: 0.4), p.ink2),
  );

  final buttonText = HcText.label.copyWith(fontSize: 15, height: 20 / 15, letterSpacing: 0);
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(HcRadius.md));
  const buttonPadding = EdgeInsets.symmetric(horizontal: HcSpace.s5);
  const buttonSize = Size(64, HcSize.buttonMd);
  OutlineInputBorder field(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(HcRadius.sm),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    textTheme: textTheme,
    fontFamily: HcFonts.sans,
    fontFamilyFallback: HcFonts.fallback,
    iconTheme: IconThemeData(color: p.ink, size: 24),
    dividerColor: p.line,
    extensions: <ThemeExtension<dynamic>>[HcTheme(palette: p, board: board)],
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: HcSize.header,
      titleTextStyle: HcText.titleLg.copyWith(color: p.ink),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: p.isDark ? 0 : 1,
      shadowColor: const Color(0x1417201A),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HcRadius.md),
        side: p.isDark ? BorderSide(color: p.line) : BorderSide.none,
      ),
    ),
    // Colours come from the scheme: filled = primary (green), tonal = secondary container
    // (green-soft). Gold buttons are PlayButton in hc_widgets.dart.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: buttonText,
        elevation: 0,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.green,
        foregroundColor: p.onGreen,
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: buttonText,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        side: BorderSide(color: p.lineControl),
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.green,
        minimumSize: const Size(48, HcSize.buttonMd),
        padding: const EdgeInsets.symmetric(horizontal: HcSpace.s3),
        textStyle: buttonText,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: HcSpace.s3, vertical: 14),
      border: field(p.lineControl, 1),
      enabledBorder: field(p.lineControl, 1),
      focusedBorder: field(p.green, 2),
      errorBorder: field(p.dangerInk, 2),
      focusedErrorBorder: field(p.dangerInk, 2),
      hintStyle: HcText.body.copyWith(color: p.ink3),
      labelStyle: HcText.label.copyWith(color: p.ink2),
      helperStyle: HcText.bodySm.copyWith(color: p.ink3),
      errorStyle: HcText.bodySm.copyWith(color: p.dangerInk),
      prefixIconColor: p.ink3,
      suffixIconColor: p.ink3,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface2,
      selectedColor: p.greenSoft,
      checkmarkColor: p.green,
      labelStyle: HcText.label.copyWith(color: p.ink2),
      secondaryLabelStyle: HcText.label.copyWith(color: p.green),
      padding: const EdgeInsets.symmetric(horizontal: HcSpace.s2, vertical: 6),
      shape: const StadiumBorder(),
      side: BorderSide.none,
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: p.ink2,
      titleTextStyle: HcText.titleSm.copyWith(color: p.ink),
      subtitleTextStyle: HcText.bodySm.copyWith(color: p.ink2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.greenSoft,
      indicatorShape: const StadiumBorder(),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: HcSize.nav,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return HcText.label.copyWith(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? p.ink : p.ink2,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? p.green : p.ink2, size: 24);
      }),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      modalBackgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.surface3,
      dragHandleSize: const Size(36, 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HcRadius.lg)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HcRadius.lg)),
      titleTextStyle: HcText.displayMd.copyWith(color: p.ink),
      contentTextStyle: HcText.body.copyWith(color: p.ink2),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.isDark ? p.surface3 : HcPalette.dark.surface,
      contentTextStyle: HcText.body.copyWith(color: HcPalette.dark.ink),
      actionTextColor: HcPalette.dark.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HcRadius.md)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.green),
  );
}
