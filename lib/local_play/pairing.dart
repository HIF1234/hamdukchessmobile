/// A simplified Swiss-style pairing for casual local tournaments: each round, players are
/// sorted by points and paired adjacent-by-score, skipping anyone already paired this
/// tournament against each other when a same-score alternative exists. Good enough for a club
/// running an informal offline event; it is not a strict FIDE Swiss implementation (no
/// Buchholz tie-breaks, no colour-balance history) -- those can be added later if local
/// tournaments ever need to feel official rather than casual.
class LocalStanding {
  LocalStanding(this.id, this.username);
  final String id;
  final String username;
  double points = 0;
  int games = 0;
  final Set<String> opponents = {};

  Map<String, dynamic> toJson() => {'id': id, 'username': username, 'points': points, 'games': games};
}

class Pairing {
  Pairing(this.whiteId, this.blackId);
  final String whiteId;
  final String? blackId; // null means a bye
}

List<Pairing> pairRound(List<LocalStanding> standings) {
  final sorted = [...standings]..sort((a, b) => b.points.compareTo(a.points));
  final remaining = [...sorted];
  final pairings = <Pairing>[];

  while (remaining.isNotEmpty) {
    final p1 = remaining.removeAt(0);
    if (remaining.isEmpty) {
      pairings.add(Pairing(p1.id, null)); // odd player out gets a bye
      break;
    }
    // Prefer the next-best player they haven't already played.
    var idx = remaining.indexWhere((p) => !p1.opponents.contains(p.id));
    if (idx == -1) idx = 0; // everyone left has been played already -- pair anyway
    final p2 = remaining.removeAt(idx);
    pairings.add(Pairing(p1.id, p2.id));
  }
  return pairings;
}

void applyResult(Map<String, LocalStanding> byId, String whiteId, String? blackId, String result) {
  final white = byId[whiteId];
  if (white == null) return;
  white.games++;
  if (blackId == null) {
    white.points += 1; // bye
    return;
  }
  final black = byId[blackId];
  if (black == null) return;
  black.games++;
  white.opponents.add(blackId);
  black.opponents.add(whiteId);
  switch (result) {
    case 'white':
      white.points += 1;
    case 'black':
      black.points += 1;
    case 'draw':
      white.points += 0.5;
      black.points += 0.5;
  }
}
