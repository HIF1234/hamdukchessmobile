import 'package:chess/chess.dart' as ch;

class Puzzle {
  Puzzle({required this.id, required this.fen, required this.solution, required this.themes, required this.rating});
  final String id;
  final String fen;
  final List<String> solution; // UCI; the solver plays the even-indexed moves
  final List<String> themes;
  final int rating;

  factory Puzzle.fromJson(Map<String, dynamic> j) => Puzzle(
        id: j['id'] as String,
        fen: j['fen'] as String,
        solution: (j['solution'] as List).cast<String>(),
        themes: ((j['themes'] as List?) ?? const []).cast<String>(),
        rating: (j['rating'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'fen': fen, 'solution': solution, 'themes': themes, 'rating': rating};
}

enum PuzzleStatus { playing, solved, failed }

/// Solving one puzzle, entirely offline. The first move of the solution is the solver's.
class PuzzleSession {
  PuzzleSession(this.puzzle) : _game = ch.Chess.fromFEN(puzzle.fen, check_validity: false);

  final Puzzle puzzle;
  final ch.Chess _game;
  int _step = 0;
  PuzzleStatus status = PuzzleStatus.playing;
  (String, String)? lastMove;

  String get fen => _game.fen;
  bool get whiteToSolve => puzzle.fen.split(' ')[1] == 'w';
  String? get hint => status == PuzzleStatus.playing ? puzzle.solution[_step].substring(0, 2) : null;

  /// Plays the solver's move. Returns false if it's illegal. A legal wrong move fails the
  /// puzzle. If the line continues, call [playReply] to make the opponent's answer.
  bool tryMove(String from, String to, [String? promotion]) {
    if (status != PuzzleStatus.playing) return false;
    final expected = puzzle.solution[_step];
    final expPromo = expected.length > 4 ? expected[4] : null;
    final legal = _game.move({'from': from, 'to': to, 'promotion': promotion ?? expPromo ?? 'q'});
    if (!legal) return false;
    lastMove = (from, to);
    final correct = expected.substring(0, 2) == from &&
        expected.substring(2, 4) == to &&
        (expPromo == null || promotion == null || promotion == expPromo);
    if (!correct) {
      status = PuzzleStatus.failed;
      return true;
    }
    _step++;
    if (_step >= puzzle.solution.length) status = PuzzleStatus.solved;
    return true;
  }

  bool get awaitingReply => status == PuzzleStatus.playing && _step.isOdd;

  /// The opponent's scripted reply.
  void playReply() {
    if (!awaitingReply) return;
    final m = puzzle.solution[_step];
    _game.move({'from': m.substring(0, 2), 'to': m.substring(2, 4), 'promotion': m.length > 4 ? m[4] : null});
    lastMove = (m.substring(0, 2), m.substring(2, 4));
    _step++;
    if (_step >= puzzle.solution.length) status = PuzzleStatus.solved;
  }
}
