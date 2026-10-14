// GENERATED from the Hamduk Chess design system (tokens.json). Do not edit by hand:
// change the design system, regenerate, and replace this file.
// Design system: https://claude.ai/artifact/Xat88cLq3NVJra74yq2k26
import 'package:flutter/material.dart';

/// Colours that change between the dark and light themes. Read them with `context.hc`.
@immutable
class HcPalette {
  const HcPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.lineControl,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.green,
    required this.onGreen,
    required this.greenSoft,
    required this.gold,
    required this.onGold,
    required this.goldInk,
    required this.goldSoft,
    required this.danger,
    required this.onDanger,
    required this.dangerInk,
    required this.dangerSoft,
  });

  final Brightness brightness;
  /// Scaffold background behind every screen. Same values as the web platform.
  final Color bg;
  /// Cards, bottom sheets, the nav bar, list rows.
  final Color surface;
  /// Wells inside a surface: time-control tiles, inputs, chips, the idle clock, move-list ribbon.
  final Color surface2;
  /// Pressed state, skeleton loaders, a selected neutral chip. Never put ink-3 on it.
  final Color surface3;
  /// Hairline dividers between rows; card edges in the dark theme.
  final Color line;
  /// Borders that define a control: outline button, unfilled input, checkbox. 3:1 on bg and surface in both themes.
  final Color lineControl;
  /// Primary text and icons on bg, surface, surface-2 and surface-3.
  final Color ink;
  /// Secondary text: subtitles, metadata, idle nav labels. Legible on bg, surface, surface-2, surface-3.
  final Color ink2;
  /// Tertiary text: timestamps, placeholders, hints. On bg, surface and surface-2 only (fails on surface-3).
  final Color ink3;
  /// Primary action fill, active tab, links, selection, focus ring. As text on bg, surface, surface-2 and green-soft.
  final Color green;
  /// Text and icons on a green fill (primary button label). Dark text in the dark theme because green lightens there.
  final Color onGreen;
  /// Tinted ground behind green text: selected chip, current move in the move list, win pill.
  final Color greenSoft;
  /// Reward and premium fill: the Play button, the current rating milestone, the Plus badge, rating gains. One gold fill per screen. Never body text.
  final Color gold;
  /// Text and icons on a gold fill.
  final Color onGold;
  /// Gold as text (rating gain, streak count) on bg, surface, surface-2 and gold-soft.
  final Color goldInk;
  /// Tinted ground behind gold-ink: rating-gain pill, streak badge.
  final Color goldSoft;
  /// Destructive icons, the live dot, the low-time clock. The light value is the web's brand red: white text on it is only 4.1:1, so text and button fills use danger-ink.
  final Color danger;
  /// Text and icons on a danger-ink fill (the confirm-resign button).
  final Color onDanger;
  /// Destructive text and the fill of the destructive button. On bg, surface and danger-soft.
  final Color dangerInk;
  /// Tinted ground behind danger-ink: loss pill, error banner.
  final Color dangerSoft;

  /// A won game (always shown with W or the word).
  Color get win => green;
  /// A lost game (always shown with L or the word).
  Color get loss => dangerInk;
  /// A drawn game (always shown with D or the word).
  Color get draw => ink2;

  bool get isDark => brightness == Brightness.dark;

  static HcPalette of(Brightness brightness) => brightness == Brightness.dark ? dark : light;

  static const dark = HcPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0F0F11),
    surface: Color(0xFF17171A),
    surface2: Color(0xFF1F1F23),
    surface3: Color(0xFF2A2A2F),
    line: Color(0xFF26262B),
    lineControl: Color(0xFF6B6B72),
    ink: Color(0xFFF0EDE8),
    ink2: Color(0xFFB4B1AA),
    ink3: Color(0xFF8E8B84),
    green: Color(0xFF3FA868),
    onGreen: Color(0xFF0A1F12),
    greenSoft: Color(0xFF13301F),
    gold: Color(0xFFF0B84A),
    onGold: Color(0xFF2E2305),
    goldInk: Color(0xFFF0B84A),
    goldSoft: Color(0xFF2E2410),
    danger: Color(0xFFF26B66),
    onDanger: Color(0xFF2A0B0A),
    dangerInk: Color(0xFFF26B66),
    dangerSoft: Color(0xFF3A1918),
  );

  static const light = HcPalette(
    brightness: Brightness.light,
    bg: Color(0xFFFAFAF8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF3F1EC),
    surface3: Color(0xFFE8E4DA),
    line: Color(0xFFE4E0D6),
    lineControl: Color(0xFF8F897C),
    ink: Color(0xFF1C1C1F),
    ink2: Color(0xFF4F4D46),
    ink3: Color(0xFF6E6B63),
    green: Color(0xFF1A6B3A),
    onGreen: Color(0xFFFFFFFF),
    greenSoft: Color(0xFFE3F1E7),
    gold: Color(0xFFF5A623),
    onGold: Color(0xFF2E2305),
    goldInk: Color(0xFF8A5A00),
    goldSoft: Color(0xFFFDF0D5),
    danger: Color(0xFFE53E3E),
    onDanger: Color(0xFFFFFFFF),
    dangerInk: Color(0xFFC42B2B),
    dangerSoft: Color(0xFFFBE4E2),
  );
}

/// Colours that are the same in both themes: brand, hero, board, persona stages, review.
abstract final class HcColors {
  /// Hamduk green as a fixed brand colour: woven strip, hero gradient start, app icon. Does not change with theme.
  static const brandGreen = Color(0xFF1A6B3A);
  /// Hamduk gold as a fixed brand colour: woven strip and cover. Does not change with theme.
  static const brandGold = Color(0xFFF5A623);
  /// Deep brand ground for hero cards and the gradient's end; the same in both themes.
  static const forest = Color(0xFF0F2E1C);
  /// A raised element sitting on forest, such as a tile inside a hero card.
  static const forestRaised = Color(0xFF16402A);
  /// Text and icons on forest and on the hero gradient.
  static const onForest = Color(0xFFF0EDE8);
  /// Secondary text on forest and anywhere on the hero gradient (4.7:1 at its lightest point).
  static const onForest2 = Color(0xFFCFE0D4);
  /// Light squares of the Hamduk board (default). Coordinates on these squares use board-dark.
  static const boardLight = Color(0xFFECE3CB);
  /// Dark squares of the Hamduk board. 4.6:1 against black pieces. Coordinates on these squares use board-light.
  static const boardDark = Color(0xFF4E8360);
  /// Overlay on the from and to squares of the last move.
  static const boardLastMove = Color(0x66F5A623);
  /// Overlay on the picked-up piece's square and on a hint square.
  static const boardSelected = Color(0x9EF5A623);
  /// Legal-move dot (16% of a square) and capture ring (8% stroke).
  static const boardMoveDot = Color(0x4C0F2E1C);
  /// Overlay on queued premove squares; adire indigo so it never reads as a real move.
  static const boardPremove = Color(0x804C5FD5);
  /// Centre of the radial glow under a king in check, fading to transparent at the square's edge.
  static const boardCheck = Color(0xD9E53E3E);
  /// Hint and analysis arrows.
  static const boardArrow = Color(0xE6F5A623);
  /// Classic board option, light squares (the app's previous board).
  static const boardClassicLight = Color(0xFFF0D9B5);
  /// Classic board option, dark squares.
  static const boardClassicDark = Color(0xFFB58863);
  /// Adire board option (Hamduk Plus), light squares.
  static const boardAdireLight = Color(0xFFE6E3EF);
  /// Adire board option (Hamduk Plus), dark squares; 4.5:1 against black pieces.
  static const boardAdireDark = Color(0xFF6670AE);
  /// Portrait stage for bots rated up to 1000. The portrait multiplies onto it so its white backdrop takes this colour.
  static const stageMint = Color(0xFFDDEFE2);
  /// Portrait stage for bots rated 1200 to 1600.
  static const stageSand = Color(0xFFF6E7C8);
  /// Portrait stage for bots rated 1800 to 2200.
  static const stageClay = Color(0xFFF3DCD0);
  /// Portrait stage for bots rated 2400 and up.
  static const stageIndigo = Color(0xFFDFE1F3);
  /// Book move badge fill; glyph on-review.
  static const reviewBook = Color(0xFF8B6F4E);
  /// Best move badge fill; glyph on-review.
  static const reviewBest = Color(0xFF1F8048);
  /// Good move badge fill; glyph on-review.
  static const reviewGood = Color(0xFF2F7FA6);
  /// Inaccuracy (?!) badge fill; glyph on-review-dark.
  static const reviewInaccuracy = Color(0xFFE8A317);
  /// Mistake (?) badge fill; glyph on-review-dark.
  static const reviewMistake = Color(0xFFE07A1F);
  /// Blunder (??) badge fill; glyph on-review.
  static const reviewBlunder = Color(0xFFD23B3B);
  /// Glyph on book, best, good and blunder badges.
  static const onReview = Color(0xFFFFFFFF);
  /// Glyph on inaccuracy and mistake badges.
  static const onReviewDark = Color(0xFF2E2305);
}

/// The 4-point spacing scale.
abstract final class HcSpace {
  /// Icon-to-label gap inside a chip or badge.
  static const double s1 = 4;
  /// Gap between related items: player bar and board, chips in a row, lines in a card.
  static const double s2 = 8;
  /// Gap between tiles in a grid; list row inner gap.
  static const double s3 = 12;
  /// Screen gutter, card padding, gap between cards.
  static const double s4 = 16;
  /// Bottom-sheet padding; hero card padding.
  static const double s5 = 20;
  /// Space below a ScreenHeader before content.
  static const double s6 = 24;
  /// Gap between sections on a screen.
  static const double s7 = 32;
  /// Empty-state vertical padding.
  static const double s8 = 40;
  /// Top padding on onboarding and sign-in panels.
  static const double s9 = 56;
  /// The screen gutter.
  static const double gutter = s4;
}

/// Corner radii by role.
abstract final class HcRadius {
  /// Clock pill, review badge, small count badges.
  static const double xs = 6;
  /// Chips, inputs, segmented controls, avatar squircles at 40px.
  static const double sm = 10;
  /// Cards, time-control tiles, list groups, large buttons.
  static const double md = 14;
  /// Hero cards; top corners of bottom sheets.
  static const double lg = 20;
  /// Onboarding and sign-in panels.
  static const double xl = 28;
  /// Board corners where the board sits inside a gutter (puzzles, previews). Edge-to-edge boards are square.
  static const double board = 8;
  /// Pills: badges, result pills, rating chips.
  static const double full = 999;
}

/// Fixed component dimensions in logical pixels.
abstract final class HcSize {
  /// Minimum touch target for anything tappable.
  static const double tap = 48;
  /// Large button height: the one main action on a screen.
  static const double buttonLg = 52;
  /// Default button height.
  static const double buttonMd = 44;
  /// Small button height inside cards and banners.
  static const double buttonSm = 34;
  /// Compact app bar height on pushed screens.
  static const double header = 56;
  /// Bottom navigation bar height (plus the system inset).
  static const double nav = 64;
  /// Player bar height above and below the board.
  static const double playerBar = 52;
  /// Time-control tile height (4 tiles per row from 360dp wide, 3 below).
  static const double tcTile = 80;
  /// Avatar in dense lists and chat.
  static const double avatarSm = 32;
  /// Avatar in list rows and player bars.
  static const double avatarMd = 40;
  /// Avatar on profile headers.
  static const double avatarLg = 72;
  /// Height of the woven strip.
  static const double strip = 6;
}

/// Font families as declared in pubspec.yaml (bundled, never fetched at runtime).
abstract final class HcFonts {
  static const display = 'PlayfairDisplay';
  static const sans = 'DMSans';
  static const mono = 'JetBrainsMono';
  /// Fills the letters DM Sans and Playfair lack: ẹ ọ ṣ ɓ ɗ ƙ and ₦.
  static const fallback = <String>['NotoSans'];
}

/// The type scale. Playfair (display*) only for fixed copy at 24px and up.
abstract final class HcText {
  /// Result headlines and onboarding. Fixed copy only, never user names. Sample: "Checkmate.".
  static const displayXl = TextStyle(fontFamily: HcFonts.display, fontFamilyFallback: HcFonts.fallback, fontSize: 40, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  /// Large screen titles on the five main tabs. Sample: "Puzzles".
  static const displayLg = TextStyle(fontFamily: HcFonts.display, fontFamilyFallback: HcFonts.fallback, fontSize: 32, height: 1.125, fontWeight: FontWeight.w700, letterSpacing: -0.4);
  /// Bottom-sheet and section-hero titles. The smallest size Playfair is allowed. Sample: "Challenge a friend".
  static const displayMd = TextStyle(fontFamily: HcFonts.display, fontFamilyFallback: HcFonts.fallback, fontSize: 24, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: -0.2);
  /// Card titles, player names on profile, compact app bar title. Sample: "Mama Cass".
  static const titleLg = TextStyle(fontFamily: HcFonts.sans, fontFamilyFallback: HcFonts.fallback, fontSize: 20, height: 1.3, fontWeight: FontWeight.w700, letterSpacing: -0.2);
  /// List-row titles, banner text, tile titles. Sample: "Finding a 10+0 opponent".
  static const titleMd = TextStyle(fontFamily: HcFonts.sans, fontFamilyFallback: HcFonts.fallback, fontSize: 17, height: 1.2941, fontWeight: FontWeight.w600);
  /// Persona names, player bar names, small card titles. Sample: "Mama Cass".
  static const titleSm = TextStyle(fontFamily: HcFonts.sans, fontFamilyFallback: HcFonts.fallback, fontSize: 15, height: 1.3333, fontWeight: FontWeight.w600);
  /// Lead paragraphs and empty-state text. Sample: "Play offline, no data needed.".
  static const bodyLg = TextStyle(fontFamily: HcFonts.sans, fontFamilyFallback: HcFonts.fallback, fontSize: 16, height: 1.5, fontWeight: FontWeight.w400);
  /// Default running text. Letters DM Sans lacks (ẹ ọ ṣ ɓ ɗ ƙ, ₦) fall back to Noto Sans. Sample: "Clubs in Ṣàgámù, Ọ̀yọ́ and Ìbàdàn".
  static const body = TextStyle(fontFamily: HcFonts.sans, fontFamilyFallback: HcFonts.fallback, fontSize: 15, height: 1.4667, fontWeight: FontWeight.w400);
  /// Subtitles, metadata, helper text. Sample: "Lagos Island · Street smart, chess dumb".
  static const bodySm = TextStyle(fontFamily: HcFonts.sans, fontFamilyFallback: HcFonts.fallback, fontSize: 13, height: 1.3846, fontWeight: FontWeight.w400);
  /// Chips, small buttons, tab labels. Sample: "Offer draw".
  static const label = TextStyle(fontFamily: HcFonts.sans, fontFamilyFallback: HcFonts.fallback, fontSize: 13, height: 1.2308, fontWeight: FontWeight.w600, letterSpacing: 0.1);
  /// Section labels above content. Always uppercase. Sample: "NAIJA BOTS".
  static const overline = TextStyle(fontFamily: HcFonts.sans, fontFamilyFallback: HcFonts.fallback, fontSize: 11, height: 1.2727, fontWeight: FontWeight.w700, letterSpacing: 1.2);
  /// The headline rating on profile and puzzle hero. Tabular figures. Sample: "1,486".
  static const ratingXl = TextStyle(fontFamily: HcFonts.sans, fontFamilyFallback: HcFonts.fallback, fontSize: 34, height: 1.1176, fontWeight: FontWeight.w700, letterSpacing: -0.5, fontFeatures: [FontFeature.tabularFigures()]);
  /// Ratings in rows, chips and the result sheet. Tabular figures. Sample: "+12".
  static const ratingMd = TextStyle(fontFamily: HcFonts.sans, fontFamilyFallback: HcFonts.fallback, fontSize: 17, height: 1.2941, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]);
  /// The game clock in a player bar. Tabular by design. Sample: "4:52".
  static const clock = TextStyle(fontFamily: HcFonts.mono, fontFamilyFallback: HcFonts.fallback, fontSize: 26, height: 1.1538, fontWeight: FontWeight.w600, letterSpacing: -0.5, fontFeatures: [FontFeature.tabularFigures()]);
  /// Clocks in spectate lists and the local-tournament board. Sample: "0:09.4".
  static const clockSm = TextStyle(fontFamily: HcFonts.mono, fontFamilyFallback: HcFonts.fallback, fontSize: 18, height: 1.2222, fontWeight: FontWeight.w600, letterSpacing: -0.2, fontFeatures: [FontFeature.tabularFigures()]);
  /// Move list and PGN text. Sample: "14. Nxe5 Qd4".
  static const notation = TextStyle(fontFamily: HcFonts.mono, fontFamilyFallback: HcFonts.fallback, fontSize: 13, height: 1.3846, fontWeight: FontWeight.w500, fontFeatures: [FontFeature.tabularFigures()]);
}

/// Durations and curves.
abstract final class HcMotion {
  static const press = Duration(milliseconds: 120);
  static const state = Duration(milliseconds: 200);
  static const sheet = Duration(milliseconds: 320);
  static const pieceSlide = Duration(milliseconds: 120);
  /// One breath of the searching glow on a time-control tile.
  static const glow = Duration(milliseconds: 1200);
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
}

/// Elevation. CSS box-shadows from the design system, as Flutter BoxShadows.
abstract final class HcShadows {
  /// Resting cards and tiles. In the dark theme it is a hairline edge, not a shadow.
  static List<BoxShadow> e1(Brightness b) => b == Brightness.dark
      ? const [BoxShadow(color: Color(0x0FF0EDE8), spreadRadius: 1)]
      : const [BoxShadow(color: Color(0x0F17201A), offset: Offset(0, 1), blurRadius: 2), BoxShadow(color: Color(0x1417201A), offset: Offset(0, 2), blurRadius: 8, spreadRadius: -2)];
  /// Bottom sheets, the result sheet, a dragged piece.
  static List<BoxShadow> e2(Brightness b) => b == Brightness.dark
      ? const [BoxShadow(color: Color(0xB2000000), offset: Offset(0, 12), blurRadius: 32, spreadRadius: -12)]
      : const [BoxShadow(color: Color(0x4717201A), offset: Offset(0, 12), blurRadius: 32, spreadRadius: -12)];
  /// The one current thing on a screen: the current milestone, the tile being searched, the active Play button.
  static const gold = <BoxShadow>[BoxShadow(color: Color(0x4CF5A623), spreadRadius: 3), BoxShadow(color: Color(0x8CF5A623), offset: Offset(0, 8), blurRadius: 22, spreadRadius: -8)];
  /// Keyboard and switch focus: a 2px gap in bg, then a solid 2px green ring.
  static List<BoxShadow> focusRing(HcPalette p) => [
        BoxShadow(color: p.green, spreadRadius: 4),
        BoxShadow(color: p.bg, spreadRadius: 2),
      ];
}

/// The woven strip: one 24px repeat, left to right, as (colour, width).
abstract final class HcStrip {
  static const double repeat = 24;
  static const pattern = <(Color, double)>[
    (HcColors.forest, 6),
    (HcColors.brandGold, 3),
    (HcColors.brandGreen, 1),
    (HcColors.brandGold, 2),
    (HcColors.forest, 3),
    (HcColors.onForest, 1),
    (HcColors.brandGreen, 5),
    (HcColors.onForest, 1),
    (HcColors.forest, 2),
  ];
}

/// A board colour scheme. Overlays are shared by every theme.
@immutable
class HcBoardTheme {
  const HcBoardTheme({required this.id, required this.name, required this.light, required this.dark, this.plusOnly = false});
  final String id;
  final String name;
  final Color light;
  final Color dark;
  final bool plusOnly;
  Color get lastMove => HcColors.boardLastMove;
  Color get selected => HcColors.boardSelected;
  Color get moveDot => HcColors.boardMoveDot;
  Color get premove => HcColors.boardPremove;
  Color get check => HcColors.boardCheck;
  Color get arrow => HcColors.boardArrow;
}

abstract final class HcBoardThemes {
  static const hamduk = HcBoardTheme(id: 'hamduk', name: 'Hamduk', light: HcColors.boardLight, dark: HcColors.boardDark);
  static const classic = HcBoardTheme(id: 'classic', name: 'Classic', light: HcColors.boardClassicLight, dark: HcColors.boardClassicDark);
  static const adire = HcBoardTheme(id: 'adire', name: 'Adire', light: HcColors.boardAdireLight, dark: HcColors.boardAdireDark, plusOnly: true);
  static const all = <HcBoardTheme>[hamduk, classic, adire];
  static HcBoardTheme byId(String? id) => all.firstWhere((t) => t.id == id, orElse: () => hamduk);
}
