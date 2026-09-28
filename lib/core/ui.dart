import 'package:flutter/material.dart';

import 'theme.dart';

/// Rounded-bottom brand banner used at the top of each main tab, so every screen shares the
/// same identity instead of a bare headline on a plain background.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brandGreen, Color.lerp(brandGreen, Colors.black, 0.25)!],
        ),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      ),
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
                  Text(subtitle!, style: t.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
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
