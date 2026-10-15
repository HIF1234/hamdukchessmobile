// Shared widgets of the Hamduk Chess design system. Each one follows the component guideline of
// the same name in design/components/. Colours, type and spacing come only from tokens.dart.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'settings.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------------------------
// Formatting

/// 1214 -> "1,214"; negative numbers use a real minus sign ("−6").
String hcNumber(int n) {
  final digits = n.abs().toString();
  final out = StringBuffer(n < 0 ? '−' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// A rating change for pills and rows: "+8", "−6", "+0".
String hcDelta(int n) => n > 0 ? '+${hcNumber(n)}' : (n < 0 ? hcNumber(n) : '+0');

/// "NG" -> 🇳🇬, via the regional-indicator Unicode trick (each letter offset into that
/// block); null or malformed input shows nothing rather than a broken glyph.
String? countryFlagEmoji(String? iso2) {
  if (iso2 == null || iso2.length != 2) return null;
  final upper = iso2.toUpperCase();
  final codes = upper.codeUnits;
  if (codes.any((c) => c < 0x41 || c > 0x5A)) return null;
  const base = 0x1F1E6 - 0x41;
  return String.fromCharCodes(codes.map((c) => c + base));
}

/// Naira with grouping and no kobo: 250000 kobo -> "₦2,500".
String hcNaira(int kobo) => '₦${hcNumber((kobo / 100).round())}';

/// Up to two initials from a display name or username ("tunde_adebayo" -> "TA").
String hcInitials(String name) {
  final parts = name.trim().split(RegExp(r'[\s_.\-]+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
  return '${parts[0].characters.first}${parts[1].characters.first}'.toUpperCase();
}

/// The persona stage colour for a bot's rating band.
Color hcStageFor(num rating) {
  if (rating <= 1000) return HcColors.stageMint;
  if (rating <= 1600) return HcColors.stageSand;
  if (rating <= 2200) return HcColors.stageClay;
  return HcColors.stageIndigo;
}

// ---------------------------------------------------------------------------------------------
// Brand

/// The woven signature band (AsoOkeStrip). Once per screen at most.
class AsoOkeStrip extends StatelessWidget {
  const AsoOkeStrip({super.key, this.height = HcSize.strip});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: const CustomPaint(painter: _StripPainter()),
    );
  }
}

class _StripPainter extends CustomPainter {
  const _StripPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    var x = 0.0;
    while (x < size.width) {
      for (final (color, width) in HcStrip.pattern) {
        if (x >= size.width) break;
        paint.color = color;
        canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), paint);
        x += width;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The one branded card at the top of a main tab (HeroCard). Text and icons inside default to
/// `on-forest`; use [HeroCard.overline], [HeroCard.sub] and [HeroCard.tile] for the rest.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.strip = true});

  final Widget child;
  final bool strip;

  static final overlineStyle = HcText.overline.copyWith(color: HcColors.onForest2);
  static final subStyle = HcText.bodySm.copyWith(color: HcColors.onForest2);

  /// An uppercase label at the top of the hero.
  static Widget overline(String text) => Text(text.toUpperCase(), style: overlineStyle);

  /// A secondary line on the hero.
  static Widget sub(String text) => Text(text, style: subStyle);

  /// A raised tile on the hero with a small label over a value.
  static Widget tile({required String label, required String value}) {
    return DecoratedBox(
      decoration: BoxDecoration(color: HcColors.forestRaised, borderRadius: BorderRadius.circular(HcRadius.md)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: HcSpace.s3, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: subStyle),
            Text(value, style: HcText.ratingMd.copyWith(color: HcColors.onForest)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(HcRadius.lg),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [HcColors.brandGreen, HcColors.forest],
            stops: [0, 0.72],
          ),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: HcColors.onForest),
          child: IconTheme.merge(
            data: const IconThemeData(color: HcColors.onForest),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (strip) const AsoOkeStrip(),
                Padding(padding: const EdgeInsets.all(HcSpace.s5), child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Buttons

/// Style helpers for the stock Material buttons (Button guideline).
abstract final class HcButtons {
  /// The red confirm button, for Resign and Block in a confirm sheet only.
  static ButtonStyle danger(BuildContext context) {
    final hc = context.hc;
    return FilledButton.styleFrom(backgroundColor: hc.dangerInk, foregroundColor: hc.onDanger);
  }

  /// The one large button on a screen. Combine with any button: `style: HcButtons.large()`.
  static ButtonStyle large() => ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, HcSize.buttonLg)),
        textStyle: WidgetStatePropertyAll(
          HcText.label.copyWith(fontSize: 16, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: 0),
        ),
      );

  /// A small pill button inside cards and banners.
  static ButtonStyle small() => ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, HcSize.buttonSm)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: HcSpace.s4)),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: WidgetStatePropertyAll(HcText.label.copyWith(letterSpacing: 0)),
      );
}

/// The gold button that starts a game: "Play", "Play 10 min", "Play Mama Cass". One per screen.
class PlayButton extends StatelessWidget {
  const PlayButton({super.key, required this.label, required this.onPressed, this.icon = Icons.bolt_rounded, this.expand = true});

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final button = FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: hc.gold,
        foregroundColor: hc.onGold,
        minimumSize: const Size(64, HcSize.buttonLg),
        textStyle: HcText.label.copyWith(fontSize: 16, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: 0),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HcRadius.md),
        boxShadow: onPressed == null ? null : HcShadows.gold,
      ),
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Navigation

/// The large Playfair title at the top of a main tab (ScreenHeader). Replaces TabHeader.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;

  /// Up to two 48px icon buttons, in `ink`.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final sub = subtitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(HcSpace.s4, HcSpace.s4, HcSpace.s2, HcSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HcText.displayLg.copyWith(color: hc.ink)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: HcText.bodySm.copyWith(color: hc.ink2)),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// The Play tab icon: the cburnett black knight as a one-colour silhouette.
class KnightIcon extends StatelessWidget {
  const KnightIcon({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? context.hc.ink2;
    return SvgPicture.asset(
      'assets/pieces/bN.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Play

/// The icon for a time-control category from /config.
IconData hcTimeControlIcon(String category) => switch (category) {
      'bullet' => Icons.speed_rounded,
      'blitz' => Icons.bolt_rounded,
      'rapid' => Icons.timer_rounded,
      _ => Icons.hourglass_empty_rounded,
    };

/// One tile of the time-control grid (TimeControlTile). Four per row from 360dp, three below.
class TimeControlTile extends StatelessWidget {
  const TimeControlTile({
    super.key,
    required this.id,
    required this.category,
    this.searching = false,
    this.dimmed = false,
    this.onTap,
  });

  /// As data writes it: "15+10".
  final String id;

  /// "bullet", "blitz", "rapid" or "classical".
  final String category;
  final bool searching;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final name = category.isEmpty ? '' : '${category[0].toUpperCase()}${category.substring(1)}';
    final accent = searching ? hc.goldInk : hc.green;
    return AnimatedOpacity(
      opacity: dimmed ? 0.45 : 1,
      duration: HcMotion.state,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HcRadius.md),
          boxShadow: searching ? HcShadows.gold : null,
        ),
        child: Material(
          color: hc.surface2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HcRadius.md),
            side: BorderSide(color: searching ? hc.gold : Colors.transparent, width: 2),
          ),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: HcSize.tcTile,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (searching)
                      SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                    else
                      Icon(hcTimeControlIcon(category), size: 18, color: accent),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(id, style: HcText.ratingMd.copyWith(fontSize: 20, height: 1.2, letterSpacing: -0.3, color: hc.ink)),
                        Text(
                          searching ? 'Searching' : name,
                          style: HcText.bodySm.copyWith(fontSize: 12, height: 16 / 12, color: searching ? hc.goldInk : hc.ink2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A Naija bot card for the Play carousel and the bot picker (PersonaCard).
class PersonaCard extends StatelessWidget {
  const PersonaCard({
    super.key,
    required this.name,
    required this.hometown,
    required this.rating,
    required this.catchphrase,
    this.portraitUrl,
    this.locked = false,
    this.lowData = false,
    this.onTap,
  });

  final String name;
  final String hometown;
  final int rating;
  final String catchphrase;
  final String? portraitUrl;

  /// A Plus bot and the player is on the free tier.
  final bool locked;

  /// Low-data mode: no portrait download, initials on the stage.
  final bool lowData;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final stage = hcStageFor(rating);
    final url = portraitUrl;
    return SizedBox(
      width: 148,
      child: Material(
        color: hc.surface,
        elevation: hc.isDark ? 0 : 1,
        shadowColor: const Color(0x1417201A),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HcRadius.md),
          side: hc.isDark ? BorderSide(color: hc.line) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 148,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: stage),
                    if (url != null && !lowData)
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        color: stage,
                        colorBlendMode: BlendMode.multiply,
                        errorBuilder: (context, error, stack) => _StageInitials(name: name),
                      )
                    else
                      _StageInitials(name: name),
                    if (locked) const Positioned(top: HcSpace.s2, right: HcSpace.s2, child: HcBadge.plus()),
                    Positioned(left: HcSpace.s2, bottom: HcSpace.s2, child: _RatingChip(rating: rating, locked: locked)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(HcSpace.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: HcText.titleSm.copyWith(color: hc.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: hc.ink2),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            hometown,
                            style: HcText.bodySm.copyWith(color: hc.ink2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 36,
                      child: Text(
                        '“$catchphrase”',
                        style: HcText.bodySm.copyWith(color: hc.ink3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageInitials extends StatelessWidget {
  const _StageInitials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(hcInitials(name), style: HcText.ratingXl.copyWith(color: HcColors.forest)));
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating, required this.locked});

  final int rating;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: HcSpace.s2),
      decoration: BoxDecoration(color: HcColors.forest, borderRadius: BorderRadius.circular(HcRadius.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (locked) ...[
            const Icon(Icons.lock_rounded, size: 14, color: HcColors.onForest),
            const SizedBox(width: HcSpace.s1),
          ],
          Text(hcNumber(rating), style: HcText.label.copyWith(color: HcColors.onForest, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Game

/// m:ss, m:ss.t under ten seconds, h:mm:ss over an hour.
String hcClock(int ms) {
  final clamped = ms < 0 ? 0 : ms;
  final total = clamped ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  if (clamped < 10000) return '$m:$s.${(clamped % 1000) ~/ 100}';
  return '$m:$s';
}

/// The clock pill at the end of a PlayerBar (Clock).
class GameClock extends StatelessWidget {
  const GameClock({super.key, required this.ms, required this.active});

  final int ms;

  /// This side is to move.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final low = active && ms < 20000;
    final flagged = ms <= 0;
    final Color bg;
    final Color fg;
    if (flagged) {
      bg = hc.dangerSoft;
      fg = hc.dangerInk;
    } else if (low) {
      bg = hc.danger;
      fg = hc.onDanger;
    } else if (active) {
      bg = hc.green;
      fg = hc.onGreen;
    } else {
      bg = hc.surface2;
      fg = hc.ink2;
    }
    return AnimatedContainer(
      duration: HcMotion.state,
      height: 40,
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: HcSpace.s3),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(HcRadius.xs)),
      child: Text(hcClock(ms), style: HcText.clock.copyWith(color: fg)),
    );
  }
}

/// One row above or below the board (PlayerBar). The opponent's is above, yours below.
class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
    required this.name,
    required this.clock,
    this.rating,
    this.country,
    this.fideTitle,
    this.subscriptionTier,
    this.avatar,
    this.status,
    this.warn = false,
    this.captured = const [],
    this.advantage = 0,
  });

  /// Shown in DM Sans with the Noto Sans fallback; never Playfair.
  final String name;
  final int? rating;

  /// ISO-3166 alpha-2; shown as a flag emoji next to the name.
  final String? country;

  /// Self-reported real title ("GM", "IM", ...): shown as bold text before the name.
  /// Untitled players past 2200 get an in-house "Expert" badge instead (never the same
  /// styling as a real title, so the two are never confused).
  final String? fideTitle;

  /// "free", "plus" or "gold" -- a small badge after the name for plus/gold.
  final String? subscriptionTier;

  /// An HcAvatar; defaults to initials.
  final Widget? avatar;

  /// "Your move", "Reconnecting…", "Left the game". Replaces the captured pieces when set.
  final String? status;

  /// Shows [status] in danger-ink.
  final bool warn;

  /// Piece codes this player has captured, e.g. ['bP', 'bN'].
  final List<String> captured;

  /// Material advantage, shown as "+2" only when positive.
  final int advantage;

  /// Usually a GameClock wrapped in the tick listener.
  final Widget clock;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final r = AppSettings.instance.hideRatings ? null : rating;
    final s = status;
    // The in-house tier is derived from the rating, so it respects hideRatings too; a real
    // title is an identity claim, not a number, and always shows.
    final title = fideTitle ?? (r != null && r >= 2200 ? 'Expert' : null);
    final titleIsReal = fideTitle != null;
    final badged = subscriptionTier == 'plus' || subscriptionTier == 'gold';
    return SizedBox(
      height: HcSize.playerBar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: HcSpace.s4),
        child: Row(
          children: [
            avatar ?? HcAvatar(name: name),
            const SizedBox(width: HcSpace.s3),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (countryFlagEmoji(country) != null) ...[
                      Text(countryFlagEmoji(country)!, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                    ],
                    if (title != null) ...[
                      Text(
                        title,
                        style: titleIsReal
                            ? HcText.titleSm.copyWith(color: hc.ink, fontWeight: FontWeight.w800)
                            : HcText.bodySm.copyWith(color: hc.ink2, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(name, style: HcText.titleSm.copyWith(color: hc.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (badged) ...[
                      const SizedBox(width: 4),
                      Icon(
                        subscriptionTier == 'gold' ? Icons.workspace_premium_rounded : Icons.star_rounded,
                        size: 14,
                        color: hc.gold,
                      ),
                    ],
                  ]),
                  DefaultTextStyle(
                    style: HcText.bodySm.copyWith(color: hc.ink2, fontFeatures: const [FontFeature.tabularFigures()]),
                    child: Row(
                      children: [
                        if (r != null) ...[Text(hcNumber(r)), const SizedBox(width: HcSpace.s2)],
                        if (s != null)
                          Flexible(
                            child: Text(
                              s,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: warn ? hc.dangerInk : hc.ink3),
                            ),
                          )
                        else ...[
                          for (final code in captured)
                            Align(
                              widthFactor: 0.7,
                              child: SvgPicture.asset('assets/pieces/$code.svg', width: 16, height: 16),
                            ),
                          if (advantage > 0) ...[
                            const SizedBox(width: HcSpace.s2),
                            Text('+$advantage', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: HcSpace.s3),
            clock,
          ],
        ),
      ),
    );
  }
}

/// The one-line move list between the app bar and the top player bar (MoveList).
class MoveListRibbon extends StatefulWidget {
  const MoveListRibbon({super.key, required this.san, required this.current, this.onTap});

  final List<String> san;

  /// Index into [san] of the move on the board.
  final int current;
  final ValueChanged<int>? onTap;

  @override
  State<MoveListRibbon> createState() => _MoveListRibbonState();
}

class _MoveListRibbonState extends State<MoveListRibbon> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(MoveListRibbon old) {
    super.didUpdateWidget(old);
    if (old.san.length != widget.san.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: HcMotion.state, curve: HcMotion.enter);
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final items = <Widget>[];
    for (var i = 0; i < widget.san.length; i++) {
      if (i.isEven) {
        items.add(Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : HcSpace.s2, right: 2),
          child: Text('${i ~/ 2 + 1}.', style: HcText.notation.copyWith(color: hc.ink3)),
        ));
      }
      final isCurrent = i == widget.current;
      items.add(GestureDetector(
        onTap: widget.onTap == null ? null : () => widget.onTap!(i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: isCurrent ? hc.greenSoft : null,
            borderRadius: BorderRadius.circular(HcRadius.xs),
          ),
          child: Text(
            widget.san[i],
            style: HcText.notation.copyWith(
              color: isCurrent ? hc.green : hc.ink,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ));
    }
    return Container(
      height: 40,
      color: hc.surface2,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HcSpace.s3),
        child: Row(children: items),
      ),
    );
  }
}

/// One action in the GameActionBar.
@immutable
class GameAction {
  const GameAction({required this.icon, required this.label, required this.onTap, this.active = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
}

/// The bar docked under the board (GameActions): Offer draw, Resign, Flip, Chat.
class GameActionBar extends StatelessWidget {
  const GameActionBar({super.key, required this.actions});

  final List<GameAction> actions;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return DecoratedBox(
      decoration: BoxDecoration(color: hc.surface, border: Border(top: BorderSide(color: hc.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HcSpace.s2, vertical: HcSpace.s1),
          child: Row(
            children: [
              for (final a in actions)
                Expanded(
                  child: InkWell(
                    onTap: a.onTap,
                    borderRadius: BorderRadius.circular(HcRadius.sm),
                    child: SizedBox(
                      height: 56,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(a.icon, color: a.active ? hc.green : hc.ink2),
                          const SizedBox(height: 2),
                          Text(a.label, style: HcText.label.copyWith(fontSize: 12, color: a.active ? hc.green : hc.ink2)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The content of the bottom sheet shown when a game ends (ResultSheet). Present it with
/// `showModalBottomSheet(context: context, builder: (_) => ResultSheet(...))`.
class ResultSheet extends StatelessWidget {
  const ResultSheet({
    super.key,
    required this.overline,
    required this.headline,
    required this.detail,
    required this.actions,
    this.ratingBefore,
    this.ratingAfter,
  });

  /// "Game over · Rapid 10+0".
  final String overline;

  /// Fixed copy: "You won.", "You lost.", "Draw."
  final String headline;

  /// "By checkmate in 31 moves."
  final String detail;
  final int? ratingBefore;
  final int? ratingAfter;

  /// Rematch (large primary) first, then Review and New opponent.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final before = ratingBefore;
    final after = ratingAfter;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(HcSpace.s5, 0, HcSpace.s5, HcSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(overline.toUpperCase(), style: HcText.overline.copyWith(color: hc.ink3)),
            const SizedBox(height: HcSpace.s1),
            Text(headline, style: HcText.displayXl.copyWith(color: hc.ink)),
            const SizedBox(height: HcSpace.s1),
            Text(detail, style: HcText.body.copyWith(color: hc.ink2)),
            if (before != null && after != null) ...[
              const SizedBox(height: HcSpace.s4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: HcSpace.s4, vertical: HcSpace.s3),
                decoration: BoxDecoration(color: hc.surface2, borderRadius: BorderRadius.circular(HcRadius.md)),
                child: Row(
                  children: [
                    Text(hcNumber(before), style: HcText.ratingMd.copyWith(color: hc.ink)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: HcSpace.s1),
                      child: Icon(Icons.arrow_forward_rounded, size: 18, color: hc.ink3),
                    ),
                    Text(hcNumber(after), style: HcText.ratingMd.copyWith(color: hc.ink)),
                    const Spacer(),
                    _GainPill(delta: after - before),
                  ],
                ),
              ),
            ],
            const SizedBox(height: HcSpace.s4),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: HcSpace.s2),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _GainPill extends StatelessWidget {
  const _GainPill({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final Color bg;
    final Color fg;
    if (delta > 0) {
      bg = hc.gold;
      fg = hc.onGold;
    } else if (delta < 0) {
      bg = hc.dangerSoft;
      fg = hc.dangerInk;
    } else {
      bg = hc.surface3;
      fg = hc.ink2;
    }
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: HcSpace.s3),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(HcRadius.full)),
      child: Text(hcDelta(delta), style: HcText.ratingMd.copyWith(fontSize: 15, color: fg)),
    );
  }
}

/// A move-classification badge for review (ReviewBadge). [kind] is the Classification name:
/// book, best, good, inaccuracy, mistake or blunder.
class ReviewBadge extends StatelessWidget {
  const ReviewBadge({super.key, required this.kind, this.size = 20});

  final String kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (Color fill, Color ink, String? glyph, IconData? icon) = switch (kind) {
      'book' => (HcColors.reviewBook, HcColors.onReview, null, Icons.menu_book_rounded),
      'best' => (HcColors.reviewBest, HcColors.onReview, null, Icons.star_rounded),
      'good' => (HcColors.reviewGood, HcColors.onReview, null, Icons.check_rounded),
      'inaccuracy' => (HcColors.reviewInaccuracy, HcColors.onReviewDark, '?!', null),
      'mistake' => (HcColors.reviewMistake, HcColors.onReviewDark, '?', null),
      _ => (HcColors.reviewBlunder, HcColors.onReview, '??', null),
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(HcRadius.xs)),
      child: icon != null
          ? Icon(icon, size: size * 0.7, color: ink)
          : Text(
              glyph ?? '',
              style: HcText.label.copyWith(fontSize: size * 0.55, height: 1, fontWeight: FontWeight.w800, color: ink),
            ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Progress and status

/// A tile with one rating and its weekly change (StatTile), three to a row on public profiles.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.icon, required this.value, this.delta});

  final String label;
  final IconData icon;
  final int value;

  /// Change this week; null shows "No change this week".
  final int? delta;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final d = delta;
    final Color deltaColor = d == null || d == 0 ? hc.ink3 : (d > 0 ? hc.win : hc.loss);
    final deltaText = d == null || d == 0 ? 'No change this week' : '${hcDelta(d)} this week';
    return Container(
      padding: const EdgeInsets.all(HcSpace.s4),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(HcRadius.md),
        boxShadow: HcShadows.e1(hc.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: hc.green),
              const SizedBox(width: HcSpace.s1),
              Flexible(child: Text(label.toUpperCase(), style: HcText.overline.copyWith(color: hc.ink3))),
            ],
          ),
          const SizedBox(height: 2),
          Text(hcNumber(value), style: HcText.ratingXl.copyWith(color: hc.ink)),
          Text(deltaText, style: HcText.label.copyWith(color: deltaColor)),
        ],
      ),
    );
  }
}

enum _BadgeKind { plus, gold, streak, live, rated, casual, count, onHero }

/// Small status pills (Badge): membership, streak, live, rated, unread count.
class HcBadge extends StatelessWidget {
  const HcBadge.plus({super.key})
      : _kind = _BadgeKind.plus,
        _text = 'PLUS',
        _icon = Icons.workspace_premium_rounded;
  const HcBadge.gold({super.key})
      : _kind = _BadgeKind.gold,
        _text = 'GOLD',
        _icon = Icons.workspace_premium_rounded;
  const HcBadge.live({super.key})
      : _kind = _BadgeKind.live,
        _text = 'LIVE',
        _icon = null;
  const HcBadge.rated({super.key})
      : _kind = _BadgeKind.rated,
        _text = 'Rated',
        _icon = null;
  const HcBadge.casual({super.key})
      : _kind = _BadgeKind.casual,
        _text = 'Casual',
        _icon = null;
  const HcBadge.streak(int days, {super.key})
      : _kind = _BadgeKind.streak,
        _text = '$days day streak',
        _icon = Icons.local_fire_department_rounded;
  const HcBadge.count(int n, {super.key})
      : _kind = _BadgeKind.count,
        _text = n > 99 ? '99+' : '$n',
        _icon = null;

  /// A translucent badge for use on a HeroCard.
  const HcBadge.onHero(String text, {super.key, this._icon})
      : _kind = _BadgeKind.onHero,
        _text = text;

  final _BadgeKind _kind;
  final String _text;
  final IconData? _icon;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final (Color? bg, Color fg, BoxBorder? border) = switch (_kind) {
      _BadgeKind.plus => (hc.goldSoft, hc.goldInk, null),
      _BadgeKind.gold => (hc.gold, hc.onGold, null),
      _BadgeKind.streak => (hc.goldSoft, hc.goldInk, null),
      _BadgeKind.live => (hc.dangerSoft, hc.dangerInk, null),
      _BadgeKind.rated || _BadgeKind.casual => (null, hc.ink2, Border.all(color: hc.lineControl)),
      _BadgeKind.count => (hc.green, hc.onGreen, null),
      _BadgeKind.onHero => (const Color(0x38000000), HcColors.onForest, null),
    };
    final isCount = _kind == _BadgeKind.count;
    final upper = _kind == _BadgeKind.plus || _kind == _BadgeKind.gold || _kind == _BadgeKind.live;
    final icon = _icon;
    return Container(
      height: isCount ? 20 : 24,
      constraints: BoxConstraints(minWidth: isCount ? 20 : 0),
      padding: EdgeInsets.symmetric(horizontal: isCount ? 6 : HcSpace.s2),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, border: border, borderRadius: BorderRadius.circular(HcRadius.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_kind == _BadgeKind.live) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: hc.danger, shape: BoxShape.circle)),
            const SizedBox(width: HcSpace.s1),
          ],
          if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: HcSpace.s1)],
          Text(
            _text,
            style: HcText.label.copyWith(
              fontSize: upper || isCount ? 11 : 12,
              fontWeight: _kind == _BadgeKind.rated || _kind == _BadgeKind.casual ? FontWeight.w600 : FontWeight.w700,
              letterSpacing: upper ? 0.6 : 0,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// W, L or D with an optional rating change (ResultPill). [outcome] is 'win', 'loss' or 'draw'.
class ResultPill extends StatelessWidget {
  const ResultPill({super.key, required this.outcome, this.delta});

  final String outcome;
  final int? delta;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final (String letter, Color bg, Color fg) = switch (outcome) {
      'win' => ('W', hc.greenSoft, hc.win),
      'loss' => ('L', hc.dangerSoft, hc.loss),
      _ => ('D', hc.surface2, hc.draw),
    };
    final d = delta;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: HcSpace.s2),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(HcRadius.full)),
      child: Text(
        d == null ? letter : '$letter ${hcDelta(d)}',
        style: HcText.label.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Lists, avatars, feedback

/// A rounded-square avatar: initials for people, a portrait on its stage for bots (Avatar).
class HcAvatar extends StatelessWidget {
  const HcAvatar({super.key, required this.name, this.imageUrl, this.stage, this.size = HcSize.avatarMd, this.online = false, this.seed});

  final String name;
  final String? imageUrl;

  /// A bot's stage colour; the portrait multiplies onto it.
  final Color? stage;
  final double size;
  final bool online;

  /// A stable id (the user id) that picks the initials tint; defaults to [name].
  final String? seed;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final tints = [(hc.greenSoft, hc.green), (hc.goldSoft, hc.goldInk), (hc.surface3, hc.ink)];
    final (Color bg, Color fg) = stage != null ? (stage!, HcColors.forest) : tints[(seed ?? name).hashCode.abs() % tints.length];
    final radius = size >= HcSize.avatarLg ? HcRadius.lg : (size <= HcSize.avatarSm ? 8.0 : HcRadius.sm);
    final url = imageUrl;
    final face = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: bg,
        alignment: Alignment.center,
        child: url != null
            ? Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                color: stage,
                colorBlendMode: stage == null ? null : BlendMode.multiply,
                errorBuilder: (context, error, stack) => Text(hcInitials(name)),
              )
            : Text(
                hcInitials(name),
                style: HcText.titleSm.copyWith(fontSize: size * 0.38, fontWeight: FontWeight.w700, color: fg),
              ),
      ),
    );
    if (!online) return face;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        face,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: hc.green,
              shape: BoxShape.circle,
              border: Border.all(color: hc.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// A grouped list on `surface` with inset hairlines (ListRow). Replaces Card + ListTile.
class HcListGroup extends StatelessWidget {
  const HcListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(HcRadius.md),
        boxShadow: HcShadows.e1(hc.brightness),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, indent: 68, color: hc.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One row in an HcListGroup.
class HcListRow extends StatelessWidget {
  const HcListRow({super.key, required this.title, this.subtitle, this.leading, this.trailing, this.onTap});

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final sub = subtitle;
    final lead = leading;
    final trail = trailing;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HcSpace.s4, vertical: HcSpace.s3),
          child: Row(
            children: [
              if (lead != null) ...[lead, const SizedBox(width: HcSpace.s3)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: HcText.titleSm.copyWith(color: hc.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(sub, style: HcText.bodySm.copyWith(color: hc.ink2), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              if (trail != null) ...[const SizedBox(width: HcSpace.s3), trail],
            ],
          ),
        ),
      ),
    );
  }
}

enum HcBannerTone { info, offer, error }

/// An inline message the player should know or answer now (Banner).
class HcBanner extends StatelessWidget {
  const HcBanner({super.key, required this.icon, required this.text, this.detail, this.tone = HcBannerTone.info, this.actions = const []});

  final IconData icon;
  final String text;
  final String? detail;
  final HcBannerTone tone;

  /// Up to two small buttons (HcButtons.small()).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final (Color bg, Color iconColor) = switch (tone) {
      HcBannerTone.offer => (hc.greenSoft, hc.green),
      HcBannerTone.error => (hc.dangerSoft, hc.dangerInk),
      HcBannerTone.info => (hc.surface2, hc.ink2),
    };
    final d = detail;
    return Container(
      padding: const EdgeInsets.fromLTRB(HcSpace.s4, HcSpace.s3, HcSpace.s3, HcSpace.s3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(HcRadius.md)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: HcSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: HcText.titleSm.copyWith(color: hc.ink)),
                if (d != null) Text(d, style: HcText.bodySm.copyWith(color: hc.ink2)),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// What a section shows when it has nothing yet (EmptyState).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.actionLabel, this.actionIcon, this.onAction});

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final label = actionLabel;
    final aIcon = actionIcon;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HcSpace.s6, vertical: HcSpace.s8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: hc.surface2, shape: BoxShape.circle),
                child: Icon(icon, size: 28, color: hc.ink2),
              ),
              const SizedBox(height: HcSpace.s4),
              Text(title, textAlign: TextAlign.center, style: HcText.titleMd.copyWith(color: hc.ink)),
              const SizedBox(height: HcSpace.s2),
              Text(body, textAlign: TextAlign.center, style: HcText.bodySm.copyWith(color: hc.ink2)),
              if (label != null) ...[
                const SizedBox(height: HcSpace.s5),
                aIcon != null
                    ? FilledButton.icon(onPressed: onAction, icon: Icon(aIcon), label: Text(label))
                    : FilledButton(onPressed: onAction, child: Text(label)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A grey placeholder shape where a card or row will appear, instead of a spinner -- the
/// loading state for a list that already knows its own layout (Play's continue/friends
/// rows, the daily puzzle card). A gentle pulse, not a shimmer sweep, to stay cheap on
/// older phones (spec's perf budget).
class HcSkeleton extends StatefulWidget {
  const HcSkeleton({super.key, this.width, required this.height, this.radius = HcRadius.md});
  final double? width;
  final double height;
  final double radius;

  @override
  State<HcSkeleton> createState() => _HcSkeletonState();
}

class _HcSkeletonState extends State<HcSkeleton> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(hc.surface2, hc.line, _controller.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Signal bars + "123ms" in an online game's app bar, so a player notices their own
/// connection is bad before it costs them a move -- not just when the opponent's does.
class ConnectionSignal extends StatelessWidget {
  const ConnectionSignal({super.key, required this.connected, required this.pingMs});
  final bool connected;
  final int? pingMs;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final ms = pingMs;
    if (!connected || ms == null) {
      return Tooltip(
        message: 'No connection',
        child: Icon(Icons.signal_cellular_connected_no_internet_0_bar_rounded, size: 18, color: hc.dangerInk),
      );
    }
    final (icon, color) = switch (ms) {
      < 150 => (Icons.signal_cellular_alt_rounded, hc.green),
      < 400 => (Icons.signal_cellular_alt_2_bar_rounded, HcColors.brandGold),
      _ => (Icons.signal_cellular_alt_1_bar_rounded, hc.dangerInk),
    };
    return Tooltip(
      message: '${ms}ms to the server',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text('${ms}ms', style: HcText.bodySm.copyWith(color: color)),
      ]),
    );
  }
}
