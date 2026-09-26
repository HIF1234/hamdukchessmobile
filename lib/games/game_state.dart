import 'package:chess/chess.dart' as ch;

/// A player shown on the board.
class Player {
  const Player({required this.id, required this.username, required this.rating});
  final String id;
  final String username;
  final int? rating;
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

  bool get active => status == 'active';
  bool get whiteToMove => fen.split(' ')[1] == 'w';

  static Player _player(String id, Object? p) {
    final m = p is Map ? p : const {};
    return Player(id: id, username: m['username'] as String? ?? 'Player', rating: (m['rating'] as num?)?.toInt());
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
      );

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
