import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette, kept in sync with the web platform's design system
/// (`hamdukchess/src/styles.css`) so the app, play.chess and the club dashboard read as one
/// product. Light-mode values are the exact hex anchors from that file's comment block; the
/// dark-mode primary/gold are close matches for its brighter oklch values (Flutter has no
/// built-in oklch support, so these are converted by eye rather than computed).
const brandGreen = Color(0xFF1A6B3A); // forest green, light surfaces
const brandGreenBright = Color(0xFF3FA868); // brighter, for dark surfaces
const brandGold = Color(0xFFF5A623);
const brandGoldBright = Color(0xFFF0B84A);
const brandBgDark = Color(0xFF0F0F11);
const brandBgLight = Color(0xFFFAFAF8);
const brandTextOnDark = Color(0xFFF0EDE8);
const brandDanger = Color(0xFFE53E3E);
const boardLight = Color(0xFFF0D9B5);
const boardDark = Color(0xFFB58863);

/// Builds the app's full theme for a given [Brightness] -- not just a seed color. Typography
/// matches the web exactly: Playfair Display for headlines/titles, DM Sans for body/labels.
ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final primary = isDark ? brandGreenBright : brandGreen;
  final gold = isDark ? brandGoldBright : brandGold;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: isDark ? const Color(0xFF0A1F12) : Colors.white,
    secondary: gold,
    onSecondary: isDark ? const Color(0xFF2E2305) : const Color(0xFF2E2305),
    tertiary: gold,
    onTertiary: const Color(0xFF2E2305),
    error: brandDanger,
    onError: Colors.white,
    surface: isDark ? const Color(0xFF17171A) : Colors.white,
    onSurface: isDark ? brandTextOnDark : const Color(0xFF1C1C1F),
    surfaceContainerHighest: isDark ? const Color(0xFF232327) : const Color(0xFFF1EFEA),
    onSurfaceVariant: isDark ? const Color(0xFFB4B1AA) : const Color(0xFF5A584F),
    outline: isDark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFDDD9D0),
    outlineVariant: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE7E3DA),
    inverseSurface: isDark ? brandTextOnDark : const Color(0xFF1C1C1F),
    onInverseSurface: isDark ? const Color(0xFF1C1C1F) : Colors.white,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final headlineStyle = GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700);
  final bodyStyle = GoogleFonts.dmSans();

  final textTheme = TextTheme(
    displayLarge: headlineStyle.copyWith(fontSize: 44, height: 1.05),
    displayMedium: headlineStyle.copyWith(fontSize: 36, height: 1.08),
    displaySmall: headlineStyle.copyWith(fontSize: 30, height: 1.1),
    headlineLarge: headlineStyle.copyWith(fontSize: 28),
    headlineMedium: headlineStyle.copyWith(fontSize: 24),
    headlineSmall: headlineStyle.copyWith(fontSize: 20),
    titleLarge: headlineStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
    titleMedium: bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
    titleSmall: bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    bodyLarge: bodyStyle.copyWith(fontSize: 16),
    bodyMedium: bodyStyle.copyWith(fontSize: 14),
    bodySmall: bodyStyle.copyWith(fontSize: 12),
    labelLarge: bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4),
    labelSmall: bodyStyle.copyWith(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4),
  ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? brandBgDark : brandBgLight,
    textTheme: textTheme,
    fontFamily: bodyStyle.fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? brandBgDark : brandBgLight,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: headlineStyle.copyWith(fontSize: 20, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDark ? BorderSide(color: Colors.white.withValues(alpha: 0.06)) : BorderSide.none,
      ),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: bodyStyle.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: const Color(0xFF2E2305),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: bodyStyle.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: bodyStyle.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: bodyStyle.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      hintStyle: bodyStyle.copyWith(color: scheme.onSurfaceVariant),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      labelStyle: bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF17171A) : Colors.white,
      indicatorColor: primary.withValues(alpha: isDark ? 0.24 : 0.14),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return bodyStyle.copyWith(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? primary : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? primary : scheme.onSurfaceVariant);
      }),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: headlineStyle.copyWith(fontSize: 20, color: scheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? const Color(0xFF232327) : const Color(0xFF1C1C1F),
      contentTextStyle: bodyStyle.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    dividerColor: scheme.outlineVariant,
  );
}
