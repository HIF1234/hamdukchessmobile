import 'dart:math';

import 'package:chess/chess.dart' as ch;

import '../engine/uci_engine.dart';

/// Move quality, with the same thresholds as the website (src/lib/game-review.ts).
enum Classification { book, best, good, inaccuracy, mistake, blunder }

extension ClassificationLabel on Classification {
  String get label => switch (this) {
        Classification.book => 'Book',
        Classification.best => 'Best',
        Classification.good => 'Good',
        Classification.inaccuracy => 'Inaccuracy',
        Classification.mistake => 'Mistake',
        Classification.blunder => 'Blunder',
      };
  String get symbol => switch (this) {
        Classification.inaccuracy => '?!',
        Classification.mistake => '?',
        Classification.blunder => '??',
        _ => '',
      };
}

class MoveReview {
  MoveReview({
    required this.ply,
    required this.san,
    required this.uci,
    required this.white,
    required this.fenBefore,
    required this.fenAfter,
    required this.evalBefore,
    required this.evalAfter,
    required this.bestMove,
    required this.cpLoss,
    required this.classification,
  });

  final int ply;
  final String san;
  final String uci;
  final bool white; // who played it
  final String fenBefore;
  final String fenAfter;
  final int evalBefore; // centipawns, White's point of view
  final int evalAfter;
  final String? bestMove; // UCI
  final int cpLoss; // >= 0, from the mover's point of view
  final Classification classification;

  /// The engine's preferred move in SAN, for "Best was Nf3".
  String? get bestSan {
    final b = bestMove;
    if (b == null || b.length < 4) return null;
    final g = ch.Chess.fromFEN(fenBefore, check_validity: false);
    final before = g.moves({'verbose': true}).cast<Map>();
    for (final m in before) {
      if (m['from'] == b.substring(0, 2) && m['to'] == b.substring(2, 4)) return m['san'] as String;
    }
    return null;
  }
}

class ReviewResult {
  ReviewResult({required this.depth, required this.moves, required this.accuracyWhite, required this.accuracyBlack});
  final int depth;
  final List<MoveReview> moves;
  final double accuracyWhite;
  final double accuracyBlack;
}

/// Depth for this phone (spec §3: stay light on 2 GB phones). The website uses 14 for Plus.
({int depth, int movetimeMs, bool light}) reviewDepthFor(int ramMb) {
  if (ramMb >= 4000) return (depth: 14, movetimeMs: 1500, light: false);
  if (ramMb >= 3000) return (depth: 12, movetimeMs: 1000, light: false);
  return (depth: 10, movetimeMs: 700, light: true);
}

class _Pos {
  _Pos(this.fenBefore, this.fenAfter, this.san, this.uci, this.white);
  final String fenBefore, fenAfter, san, uci;
  final bool white;
}

/// Replays the SAN moves from [startFen].
List<_Pos> _positions(String startFen, List<String> sanMoves) {
  final g = ch.Chess.fromFEN(startFen, check_validity: false);
  final out = <_Pos>[];
  for (final san in sanMoves) {
    final before = g.fen;
    final white = g.turn == ch.Color.WHITE;
    final legal = g.moves({'verbose': true}).cast<Map>();
    final m = legal.firstWhere((x) => x['san'] == san, orElse: () => const {});
    if (m.isEmpty || !g.move(san)) break;
    final promo = (m['flags'] as String).contains('p') ? san.split('=').last.substring(0, 1).toLowerCase() : '';
    out.add(_Pos(before, g.fen, san, '${m['from']}${m['to']}$promo', white));
  }
  return out;
}

/// Engine evaluation of a position in centipawns from White's point of view, and its best
/// move. Finished positions (mate or stalemate) are scored without searching.
Future<(int, String?)> _evaluate(UciEngine engine, String fen, int depth, int movetimeMs) async {
  final g = ch.Chess.fromFEN(fen, check_validity: false);
  final whiteToMove = g.turn == ch.Color.WHITE;
  if (g.in_checkmate) return (whiteToMove ? -100000 : 100000, null);
  if (g.in_stalemate || g.insufficient_material) return (0, null);
  final (best, lines) = await engine.analyse(fen, depth: depth, movetimeMs: movetimeMs, multiPv: 1);
  final stm = lines.isEmpty ? 0 : lines.first.score;
  return (whiteToMove ? stm : -stm, best == '(none)' ? null : best);
}

/// Reviews a game move by move. [isCancelled] lets the screen stop it (e.g. when closed).
Future<ReviewResult?> reviewGame(
  UciEngine engine, {
  required String startFen,
  required List<String> sanMoves,
  required int depth,
  required int movetimeMs,
  void Function(int done, int total)? onProgress,
  bool Function()? isCancelled,
}) async {
  final positions = _positions(startFen, sanMoves);
  final evals = <(int, String?)>[await _evaluate(engine, startFen, depth, movetimeMs)];
  for (var i = 0; i < positions.length; i++) {
    if (isCancelled?.call() ?? false) return null;
    evals.add(await _evaluate(engine, positions[i].fenAfter, depth, movetimeMs));
    onProgress?.call(i + 1, positions.length);
  }
  return buildReview(depth, [for (final p in positions) (p.fenBefore, p.fenAfter, p.san, p.uci, p.white)], evals);
}

/// Turns evaluations into move reviews. evals[i] is the position before move i; the last one
/// is the final position. Pure, so it's easy to test.
ReviewResult buildReview(
  int depth,
  List<(String fenBefore, String fenAfter, String san, String uci, bool white)> positions,
  List<(int cp, String? best)> evals,
) {
  final moves = <MoveReview>[];
  for (var i = 0; i < positions.length; i++) {
    final p = positions[i];
    final before = evals[i].$1;
    final after = i + 1 < evals.length ? evals[i + 1].$1 : before;
    final sign = p.$5 ? 1 : -1;
    final cpLoss = max(0, (before - after) * sign);
    // Early moves count as book unless they lose real material/position, never a checkmate.
    // The threshold is generous (not the ~15cp "best" cutoff) because Stockfish 11's classical
    // eval is genuinely noisy in the opening — swings of 80-100cp between near-symmetric
    // positions a few plies apart are normal engine noise here, not an actual mistake.
    final isBook = i < 12 && cpLoss < 150 && !p.$3.endsWith('#');
    moves.add(MoveReview(
      ply: i + 1,
      san: p.$3,
      uci: p.$4,
      white: p.$5,
      fenBefore: p.$1,
      fenAfter: p.$2,
      evalBefore: before,
      evalAfter: after,
      bestMove: evals[i].$2,
      cpLoss: cpLoss,
      classification: isBook ? Classification.book : classify(cpLoss, p.$4 == evals[i].$2),
    ));
  }
  return ReviewResult(
    depth: depth,
    moves: moves,
    accuracyWhite: accuracy(moves.where((m) => m.white).toList()),
    accuracyBlack: accuracy(moves.where((m) => !m.white).toList()),
  );
}

Classification classify(int cpLoss, bool isTop) {
  if (isTop || cpLoss < 15) return Classification.best;
  if (cpLoss < 40) return Classification.good;
  if (cpLoss < 90) return Classification.inaccuracy;
  if (cpLoss < 200) return Classification.mistake;
  return Classification.blunder;
}

/// Lichess-style accuracy from the drop in winning chances, 0-100 (same formula as the site).
/// Book moves are skipped: they're theory, not something the engine's opening-phase eval
/// (noisy at this depth) should be allowed to mark down.
double accuracy(List<MoveReview> moves) {
  final scored = moves.where((m) => m.classification != Classification.book).toList();
  if (scored.isEmpty) return 100;
  var sum = 0.0;
  for (final m in scored) {
    final sign = m.white ? 1 : -1;
    final drop = max(0.0, winPct(m.evalBefore * sign) - winPct(m.evalAfter * sign));
    sum += (103.1668 * exp(-0.04354 * drop) - 3.1669).clamp(0.0, 100.0);
  }
  return (sum / scored.length * 10).round() / 10;
}

/// Centipawns to win percentage from the mover's point of view.
double winPct(int cp) {
  final c = cp.clamp(-1000, 1000);
  return 50 + 50 * (2 / (1 + exp(-0.00368208 * c)) - 1);
}
