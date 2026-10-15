import 'package:chess/chess.dart' as ch;

const _pieceWords = {
  'pawn': 'P',
  'knight': 'N',
  'night': 'N', // common mis-hearing of "knight"
  'bishop': 'B',
  'rook': 'R',
  'queen': 'Q',
  'king': 'K',
};

/// An optional single piece letter directly touching a square, e.g. "nf3" or "qxe5" (the
/// capture 'x' isn't matched -- a from/to pair is the same move whether or not it captures).
final _moveTokenRe = RegExp(r'\b([kqrbn])?\s?([a-h])\s?([1-8])\b');

/// The result of [parseVoiceMove]: either a resolved move, or [error] explaining why not.
class VoiceMove {
  const VoiceMove({this.from, this.to, this.promotion, this.error});
  final String? from;
  final String? to;

  /// Lowercase piece letter ('q', 'r', 'b', 'n'), only set when the move promotes.
  final String? promotion;
  final String? error;
  bool get ok => from != null && to != null;
}

String _pieceOf(Map m) {
  final san = m['san'] as String;
  if (san.startsWith('O-O')) return 'K';
  final c = san[0];
  return 'KQRBN'.contains(c) ? c : 'P';
}

String? _promotionOf(Map m) {
  final match = RegExp(r'=([QRBN])').firstMatch(m['san'] as String);
  return match?.group(1)?.toLowerCase();
}

/// Parses a spoken chess move -- "knight f3", "NF3", "knight on f3 to a4", "e2 to e4",
/// "castle kingside" -- against the legal moves in [fen]. Matches loosely (word boundaries,
/// optional "on"/"to"/"takes", case-insensitive) since this is speech-to-text output, not
/// typed notation, and only resolves a move when it's unambiguous.
VoiceMove parseVoiceMove(String heard, String fen) {
  final text = heard.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return const VoiceMove(error: "Didn't catch that -- try again.");

  final game = ch.Chess.fromFEN(fen, check_validity: false);
  final moves = game.moves({'verbose': true}).cast<Map>();
  if (moves.isEmpty) return const VoiceMove(error: 'No legal moves.');

  // Castling: "castle kingside/short" or "castle queenside/long".
  if (text.contains('castle')) {
    final queenside = text.contains('queenside') || text.contains('long');
    final wanted = queenside ? 'O-O-O' : 'O-O';
    final matches = moves.where((m) => m['san'] == wanted);
    if (matches.isEmpty) return VoiceMove(error: "Can't castle ${queenside ? 'queenside' : 'kingside'} right now.");
    final m = matches.first;
    return VoiceMove(from: m['from'] as String, to: m['to'] as String);
  }

  final tokens = _moveTokenRe.allMatches(text).toList();
  final squares = [for (final t in tokens) '${t.group(2)}${t.group(3)}'];

  // Stripped of its own matched phrase, so "promoting to knight" never gets read back below
  // as "the knight is the piece that's moving" when the move is actually a pawn's.
  String? promotionWanted;
  var searchText = text;
  final promoMatch = RegExp(r'promot\w*\s*(?:to\s*)?(queen|rook|bishop|knight)').firstMatch(text);
  if (promoMatch != null) {
    promotionWanted = _pieceWords[promoMatch.group(1)]?.toLowerCase();
    searchText = text.replaceRange(promoMatch.start, promoMatch.end, '');
  }

  List<Map> candidates;
  String from, to;
  if (squares.length >= 2) {
    // "<square> to <square>", "<piece> on <square> to <square>", or two bare squares.
    from = squares[squares.length - 2];
    to = squares[squares.length - 1];
    candidates = moves.where((m) => m['from'] == from && m['to'] == to).toList();
    if (candidates.isEmpty) return VoiceMove(error: "$from to $to isn't a legal move.");
  } else if (squares.length == 1) {
    // "<piece>? <takes>? <square>" -- SAN-style, piece type (default pawn) + destination only.
    to = squares.first;
    var wantedPiece = tokens.first.group(1)?.toUpperCase() ?? '';
    if (wantedPiece.isEmpty) {
      for (final entry in _pieceWords.entries) {
        if (RegExp('\\b${entry.key}\\b').hasMatch(searchText)) {
          wantedPiece = entry.value;
          break;
        }
      }
    }
    if (wantedPiece.isEmpty) wantedPiece = 'P';
    final matches = moves.where((m) => m['to'] == to && _pieceOf(m) == wantedPiece).toList();
    if (matches.isEmpty) {
      final piece = wantedPiece == 'P' ? 'pawn' : _pieceWords.entries.firstWhere((e) => e.value == wantedPiece).key;
      return VoiceMove(error: 'No legal $piece move to $to.');
    }
    final distinctFrom = {for (final m in matches) m['from']};
    if (distinctFrom.length > 1) {
      return VoiceMove(error: 'More than one piece can move to $to -- say which square it\'s on, e.g. "f3 to $to".');
    }
    from = matches.first['from'] as String;
    candidates = matches;
  } else {
    return const VoiceMove(error: "Didn't catch a move in that -- try again.");
  }

  final m = candidates.first;
  return VoiceMove(from: from, to: to, promotion: promotionWanted ?? _promotionOf(m));
}
