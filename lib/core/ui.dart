import 'package:flutter/material.dart';

import 'theme.dart';

/// Milestone bands a rating climbs through, lowest first.
const ratingMilestones = [400, 600, 800, 1000, 1200, 1400, 1600, 1800, 2000, 2200];

/// A horizontal path of rating milestones with the player's current band lit in gold
/// (RatingLadder guideline): reached bands green, the current one gold, the rest locked.
class RatingLadder extends StatefulWidget {
  const RatingLadder({super.key, required this.rating});
  final int? rating;

  @override
  State<RatingLadder> createState() => _RatingLadderState();
}

class _RatingLadderState extends State<RatingLadder> {
  static const _step = 56.0;

  // Opens with the current band in view.
  late final ScrollController _scroll = ScrollController(initialScrollOffset: _initialOffset(widget.rating));

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final r = widget.rating;
    return Container(
      height: 92,
      padding: const EdgeInsets.fromLTRB(HcSpace.s2, HcSpace.s3, HcSpace.s2, HcSpace.s2),
      decoration: BoxDecoration(color: hc.surface2, borderRadius: BorderRadius.circular(HcRadius.md)),
      child: r == null
          ? Center(
              child: Text('Solve a puzzle to start climbing', style: HcText.bodySm.copyWith(color: hc.ink3)),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: ratingMilestones.length,
              controller: _scroll,
              itemBuilder: (context, i) {
                final band = ratingMilestones[i];
                final reached = r >= band;
                final isCurrent = reached && (i == ratingMilestones.length - 1 || r < ratingMilestones[i + 1]);
                final nextReached = i < ratingMilestones.length - 1 && r >= ratingMilestones[i + 1];
                final Color left = i == 0 ? Colors.transparent : (reached ? hc.green : hc.lineControl);
                final Color right =
                    i == ratingMilestones.length - 1 ? Colors.transparent : (nextReached ? hc.green : hc.lineControl);
                return SizedBox(
                  width: _step,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 40,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Container(height: 2, color: left)),
                                Expanded(child: Container(height: 2, color: right)),
                              ],
                            ),
                            _Node(reached: reached, current: isCurrent),
                          ],
                        ),
                      ),
                      const SizedBox(height: HcSpace.s2),
                      Text(
                        _grouped(band),
                        style: HcText.label.copyWith(
                          fontSize: 12,
                          color: isCurrent ? hc.goldInk : hc.ink3,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  static double _initialOffset(int? rating) {
    if (rating == null) return 0;
    var index = 0;
    for (var i = 0; i < ratingMilestones.length; i++) {
      if (rating >= ratingMilestones[i]) index = i;
    }
    final offset = (index - 2) * _step;
    return offset < 0 ? 0 : offset;
  }

  static String _grouped(int n) => n >= 1000 ? '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}' : '$n';
}

class _Node extends StatelessWidget {
  const _Node({required this.reached, required this.current});
  final bool reached;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    if (current) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: hc.gold, shape: BoxShape.circle, boxShadow: HcShadows.gold),
        child: Icon(Icons.emoji_events_rounded, size: 20, color: hc.onGold),
      );
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: reached ? hc.green : hc.surface,
        shape: BoxShape.circle,
        border: reached ? null : Border.all(color: hc.lineControl, width: 1.5),
      ),
      child: Icon(
        reached ? Icons.check_rounded : Icons.lock_outline_rounded,
        size: reached ? 16 : 14,
        color: reached ? hc.onGreen : hc.ink3,
      ),
    );
  }
}

/// The overline that introduces a group of content ("NAIJA BOTS"): uppercase `overline` in
/// `ink-2`, with an optional 16px icon in `green`.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final i = icon;
    return Padding(
      padding: const EdgeInsets.only(bottom: HcSpace.s2),
      child: Row(
        children: [
          if (i != null) ...[Icon(i, size: 16, color: hc.green), const SizedBox(width: 6)],
          Text(text.toUpperCase(), style: HcText.overline.copyWith(color: hc.ink2)),
        ],
      ),
    );
  }
}
