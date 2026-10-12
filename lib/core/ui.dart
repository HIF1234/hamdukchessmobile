import 'package:flutter/material.dart';

import 'theme.dart';

/// Rounded-bottom brand banner used at the top of each main tab, so every screen shares the
/// same identity instead of a bare headline on a plain background. The faint checkerboard
/// texture is the app's visual signature -- a quiet nod to the board on every screen, the way
/// chess.com leans on its own board motif well beyond the game screen itself.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.subtitle, this.trailing, this.badges});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  /// Small pills (streak, membership tier, …) shown under the subtitle, chess.com-profile style.
  final List<Widget>? badges;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [brandGreen, Color.lerp(brandGreen, Colors.black, 0.25)!],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _CheckerTexture())),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: t.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: t.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ],
                        if (badges != null && badges!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: badges!),
                        ],
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faint alternating squares, bottom-right-weighted, evoking a board without competing with
/// the title text that sits top-left.
class _CheckerTexture extends CustomPainter {
  static const _cell = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.05);
    final cols = (size.width / _cell).ceil() + 1;
    final rows = (size.height / _cell).ceil() + 1;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        if ((row + col).isOdd) {
          canvas.drawRect(Rect.fromLTWH(col * _cell, row * _cell, _cell, _cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A rounded pill showing a number (rating, streak, count) against the brand gold accent.
class StatBadge extends StatelessWidget {
  const StatBadge({super.key, required this.label, required this.value, this.light = false});
  final String label;
  final String value;
  /// True when placed on a dark/brand background (e.g. inside a [TabHeader]).
  final bool light;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: light ? Colors.white.withValues(alpha: 0.16) : brandGold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: t.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: light ? Colors.white : brandGold,
            ),
          ),
          Text(
            label,
            style: t.textTheme.labelSmall?.copyWith(color: light ? Colors.white70 : t.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A small icon+text pill for a [TabHeader]'s `badges` row (streak, membership tier, …).
class HeaderBadge extends StatelessWidget {
  const HeaderBadge({super.key, required this.icon, required this.label, this.color = Colors.white});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    );
  }
}

/// Milestone bands a rating climbs through, lowest first.
const ratingMilestones = [400, 600, 800, 1000, 1200, 1400, 1600, 1800, 2000, 2200];

/// A horizontal "journey" strip of rating milestones with the player's current band lit up,
/// in the spirit of chess.com's puzzle path -- but driven by the player's real rating, not a
/// fixed curriculum, since our puzzles are served by rating rather than numbered levels.
class RatingLadder extends StatelessWidget {
  const RatingLadder({super.key, required this.rating});
  final int? rating;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = rating;
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: r == null
          ? Center(
              child: Text('Solve a puzzle to start climbing', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: ratingMilestones.length,
              itemBuilder: (context, i) {
                final band = ratingMilestones[i];
                final reached = r >= band;
                final isCurrent = reached && (i == ratingMilestones.length - 1 || r < ratingMilestones[i + 1]);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isCurrent ? 46 : 36,
                        height: isCurrent ? 46 : 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent ? brandGold : (reached ? t.colorScheme.primary : t.colorScheme.surface),
                          border: Border.all(
                            color: isCurrent ? brandGold : (reached ? t.colorScheme.primary : t.colorScheme.outline),
                            width: isCurrent ? 3 : 1.5,
                          ),
                          boxShadow: isCurrent
                              ? [BoxShadow(color: brandGold.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1)]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          reached ? Icons.emoji_events : Icons.lock_outline,
                          size: isCurrent ? 22 : 16,
                          color: isCurrent
                              ? const Color(0xFF2E2305)
                              : (reached ? t.colorScheme.onPrimary : t.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$band',
                        style: t.textTheme.labelSmall?.copyWith(
                          color: isCurrent ? brandGold : t.colorScheme.onSurfaceVariant,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// A small-caps-style section label with an icon, used to introduce a group of content
/// (e.g. "Naija bots") with more presence than a bare Text widget.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: t.colorScheme.primary), const SizedBox(width: 6)],
          Text(
            text.toUpperCase(),
            style: t.textTheme.labelMedium?.copyWith(
              color: t.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
