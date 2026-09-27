import 'dart:math';

import 'uci_engine.dart';

/// A bot's playing style, from /config (bots[].engine). Same numbers the website uses.
class BotStyle {
  const BotStyle({
    required this.depthMin,
    required this.depthMax,
    required this.blunderRate,
    required this.randomness,
    required this.movetimeMs,
    this.openingRepertoire = const [],
  });

  final int depthMin;
  final int depthMax;
  final double blunderRate; // 0..1: chance to pick the 2nd or 3rd best move
  final double randomness; // noise added to scores, in pawns
  final int movetimeMs;
  final List<String> openingRepertoire; // UCI first moves for White

  factory BotStyle.fromConfig(Map<String, dynamic> e) => BotStyle(
        depthMin: (e['depthMin'] as num).toInt(),
        depthMax: (e['depthMax'] as num).toInt(),
        blunderRate: (e['blunderRate'] as num).toDouble(),
        randomness: (e['randomness'] as num).toDouble(),
        movetimeMs: (e['movetimeMs'] as num).toInt(),
        openingRepertoire: ((e['openingRepertoire'] as List?) ?? const []).cast<String>(),
      );
}

/// The bot's move choice, ported exactly from the website (src/lib/bot-engine.ts):
/// Stockfish's top three lines, gaussian noise on their scores, and blunder injection.
class BotBrain {
  BotBrain(this.style, [Random? random]) : _rng = random ?? Random();
  final BotStyle style;
  final Random _rng;

  int pickDepth() => style.depthMin + _rng.nextInt(style.depthMax - style.depthMin + 1);

  double _gaussian() {
    final u = 1 - _rng.nextDouble();
    final v = _rng.nextDouble();
    return sqrt(-2 * log(u)) * cos(2 * pi * v);
  }

  /// Picks from Stockfish's lines with noise and occasional blunders.
  String? pickFromPvs(List<Pv> pvs) {
    if (pvs.isEmpty) return null;
    final noised = [
      for (final p in pvs) (move: p.move, score: p.score + _gaussian() * style.randomness * 100),
    ]..sort((a, b) => b.score.compareTo(a.score));
    if (_rng.nextDouble() < style.blunderRate && noised.length > 1) {
      if (noised.length >= 3 && _rng.nextDouble() < 0.3) return noised[2].move;
      return noised[1].move;
    }
    return noised.first.move;
  }

  /// The bot's move in [fen]. [ply] is the number of moves played so far.
  Future<String> chooseMove(UciEngine engine, String fen, int ply) async {
    // A tiny opening book: White's first move comes from the bot's favourites.
    if (ply == 0 && fen.split(' ')[1] == 'w' && style.openingRepertoire.isNotEmpty) {
      return style.openingRepertoire[_rng.nextInt(style.openingRepertoire.length)];
    }
    final (best, lines) = await engine.analyse(fen, depth: pickDepth(), movetimeMs: style.movetimeMs);
    return pickFromPvs(lines) ?? best;
  }
}
