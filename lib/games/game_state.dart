import 'package:chess/chess.dart' as ch;

/// A player shown on the board.
class Player {
  const Player({required this.id, required this.username, required this.rating, this.country});
  final String id;
  final String username;
  final int? rating;

  /// ISO-3166 alpha-2, e.g. "NG" -- for the flag on the player bar.
  final String? country;
}

/// The server's view of a game. Only the server decides legality, results and clocks.
class GameState {
  GameState({
    required this.id,
    required this.white,
    required this.black,
    required this.status,
    required this.fen,
    required this.pgn,
    required this.ply,
    required this.timeWhiteMs,
    required this.timeBlackMs,
    required this.lastClockUpdate,
    this.result,
    this.endReason,
    this.winnerId,
    this.drawOfferBy,
    this.timeControl = '',
    this.chess960 = false,
    this.rated = true,
  });

  final String id;
  final Player white;
  final Player black;
  final String status; // waiting | active | completed | aborted
  final String fen;
  final String? pgn;
  final int ply;
  final int timeWhiteMs;
  final int timeBlackMs;
  final DateTime? lastClockUpdate;
  final String? result; // white | black | draw
  final String? endReason;
  final String? winnerId;
  final String? drawOfferBy;
  final String timeControl;
  final bool chess960;
  final bool rated;

  bool get active => status == 'active';
  bool get whiteToMove => fen.split(' ')[1] == 'w';

  /// "bullet", "blitz", "rapid" or "classical", from [timeControl] ("10+0") by the same
  /// initial + 40*increment thresholds /config uses to categorise its time controls.
  String get category {
    final parts = timeControl.split('+');
    final minutes = int.tryParse(parts.isEmpty ? '' : parts[0]) ?? 0;
    final increment = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final estimate = minutes * 60 + 40 * increment;
    if (estimate < 180) return 'bullet';
    if (estimate < 600) return 'blitz';
    if (estimate < 1500) return 'rapid';
    return 'classical';
  }

  static Player _player(String id, Object? p) {
    final m = p is Map ? p : const {};
    return Player(
      id: id,
      username: m['username'] as String? ?? 'Player',
      rating: (m['rating'] as num?)?.toInt(),
      country: m['country'] as String?,
    );
  }

  /// From GET /games/{id}.
  factory GameState.fromApi(Map<String, dynamic> j) => GameState(
        id: j['id'] as String,
        white: _player(j['white_id'] as String, j['white']),
        black: _player(j['black_id'] as String, j['black']),
        status: j['status'] as String,
        fen: j['fen'] as String,
        pgn: j['pgn'] as String?,
        ply: (j['ply'] as num).toInt(),
        timeWhiteMs: (j['time_white_ms'] as num?)?.toInt() ?? 0,
        timeBlackMs: (j['time_black_ms'] as num?)?.toInt() ?? 0,
        lastClockUpdate: DateTime.tryParse(j['last_clock_update'] as String? ?? ''),
        result: j['result'] as String?,
        endReason: j['end_reason'] as String?,
        winnerId: j['winner_id'] as String?,
        drawOfferBy: j['draw_offer_by'] as String?,
        timeControl: j['time_control'] as String? ?? '',
        chess960: j['chess960_start_fen'] != null,
        rated: j['rated'] as bool? ?? true,
      );

  /// A Realtime update of the games row. It has no player names, so those are kept.
  GameState mergeRow(Map<String, dynamic> row) => GameState(
        id: id,
        white: white,
        black: black,
        status: row['status'] as String? ?? status,
        fen: row['fen'] as String? ?? fen,
        pgn: row['pgn'] as String? ?? pgn,
        ply: (row['ply'] as num?)?.toInt() ?? ply,
        timeWhiteMs: (row['time_white_ms'] as num?)?.toInt() ?? timeWhiteMs,
        timeBlackMs: (row['time_black_ms'] as num?)?.toInt() ?? timeBlackMs,
        lastClockUpdate: DateTime.tryParse(row['last_clock_update'] as String? ?? '') ?? lastClockUpdate,
        result: row['result'] as String?,
        endReason: row['end_reason'] as String?,
        winnerId: row['winner_id'] as String?,
        drawOfferBy: row['draw_offer_by'] as String?,
        timeControl: timeControl,
        chess960: chess960,
        rated: rated,
      );

  /// All moves in SAN, read from the PGN (for game review).
  List<String> get sanMoves {
    if (pgn == null || pgn!.isEmpty) return const [];
    final g = ch.Chess();
    if (!g.load_pgn(pgn)) return const [];
    return g.getHistory().cast<String>();
  }

  /// The last move, for highlighting, read from the PGN.
  (String, String)? get lastMove {
    if (pgn == null || pgn!.isEmpty) return null;
    final g = ch.Chess();
    if (!g.load_pgn(pgn)) return null;
    final h = g.getHistory({'verbose': true});
    if (h.isEmpty) return null;
    final m = h.last as Map;
    return (m['from'] as String, m['to'] as String);
  }

  /// Captured pieces and the material count (PlayerBar's `captured`/`advantage`): what's
  /// missing from each side versus a full set, read straight off the board in [fen].
  /// [whiteCaptured]/[blackCaptured] are the pieces that side has captured (opponent's
  /// colour), for display on that side's own bar; [advantage] is white's lead in points,
  /// negative when black leads -- PlayerBar only shows it on the leading side.
  ({List<String> whiteCaptured, List<String> blackCaptured, int advantage}) get material {
    const start = {'P': 8, 'N': 2, 'B': 2, 'R': 2, 'Q': 1};
    const order = ['Q', 'R', 'B', 'N', 'P']; // strongest first, matching the website
    const values = {'P': 1, 'N': 3, 'B': 3, 'R': 5, 'Q': 9};
    final onBoard = <String, int>{};
    for (final ch in fen.split(' ').first.split('')) {
      if (ch == '/' || int.tryParse(ch) != null) continue;
      final isWhite = ch.toUpperCase() == ch;
      final key = '${isWhite ? 'w' : 'b'}${ch.toUpperCase()}';
      onBoard[key] = (onBoard[key] ?? 0) + 1;
    }
    final whiteCaptured = <String>[]; // black pieces white has taken
    final blackCaptured = <String>[]; // white pieces black has taken
    var whiteValue = 0, blackValue = 0;
    for (final type in order) {
      final blackMissing = start[type]! - (onBoard['b$type'] ?? 0);
      final whiteMissing = start[type]! - (onBoard['w$type'] ?? 0);
      whiteCaptured.addAll(List.filled(blackMissing, 'b$type'));
      blackCaptured.addAll(List.filled(whiteMissing, 'w$type'));
      whiteValue += blackMissing * values[type]!;
      blackValue += whiteMissing * values[type]!;
    }
    return (whiteCaptured: whiteCaptured, blackCaptured: blackCaptured, advantage: whiteValue - blackValue);
  }
}

/// Remaining time on each clock. The running side counts down from the server's last clock
/// update, measured in server time: `serverOffset` corrects for a phone whose clock is wrong.
(int white, int black) displayClocks(GameState g, {required DateTime now, required Duration serverOffset}) {
  if (!g.active || g.lastClockUpdate == null) return (g.timeWhiteMs, g.timeBlackMs);
  final elapsed = now.add(serverOffset).difference(g.lastClockUpdate!).inMilliseconds.clamp(0, 1 << 31);
  // Clocks only start after each side's first move, as on the website.
  if (g.ply < 2) return (g.timeWhiteMs, g.timeBlackMs);
  return g.whiteToMove
      ? ((g.timeWhiteMs - elapsed).clamp(0, g.timeWhiteMs), g.timeBlackMs)
      : (g.timeWhiteMs, (g.timeBlackMs - elapsed).clamp(0, g.timeBlackMs));
}

/// A move shown on the board before the server has confirmed it.
class PendingMove {
  PendingMove({required this.uci, required this.ply, required this.fenAfter, required this.from, required this.to});
  final String uci;
  final int ply; // the ply this move will have; makes retries safe
  final String fenAfter;
  final String from;
  final String to;
  int attempts = 0;
}

/// Checks a move locally for instant feedback and builds the optimistic position.
/// Returns null when the move is illegal here, so it never reaches the server.
PendingMove? prepareMove(GameState g, String from, String to, String? promotion) {
  final game = ch.Chess.fromFEN(g.fen, check_validity: false);
  final piece = promotion ?? 'q';
  final ok = game.move({'from': from, 'to': to, 'promotion': piece});
  if (!ok) return null;
  // The history marks promotions with the 'p' flag but doesn't say which piece; we chose it.
  final last = game.getHistory({'verbose': true}).last as Map;
  final promoted = (last['flags'] as String).contains('p');
  final uci = '$from$to${promoted ? piece : ''}';
  return PendingMove(uci: uci, ply: g.ply + 1, fenAfter: game.fen, from: from, to: to);
}
