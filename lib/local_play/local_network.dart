import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as ch;

const localTournamentPort = 44441;

/// A local tournament runs on one phone's hotspot LAN -- no internet, nothing touches the
/// server. One device hosts (runs a raw WebSocket server via dart:io, no extra package needed),
/// the rest join over plain TCP once they're on the same WiFi network; the host relays moves
/// between paired players and tracks standings. Casual only: results never sync anywhere.
///
/// A player's username is their stable identity for the whole tournament (real accounts already
/// have globally unique usernames, so two genuinely different people colliding is not a
/// practical concern). That makes reconnection simple: a WiFi blip or a backgrounded app just
/// drops the socket, and re-joining with the same username resumes -- the host still has their
/// standing and, if they were mid-game, their board's current position (tracked server-side
/// from relayed moves, not just blindly forwarded) to hand straight back.
///
/// Message shapes (all JSON over one WebSocket connection per client):
///   client -> host  {type: "join", username}
///   host -> client  {type: "welcome", clientId}
///   host -> client  {type: "name_taken"}                -- that username is connected right now
///   host -> all     {type: "lobby", players: [{id, username}]}
///   host -> pair    {type: "pairing", gameId, color: "white"|"black", opponent, fen}
///                                                        -- also used to resume after a reconnect,
///                                                           with fen set to the current position
///   client -> host  {type: "move", gameId, uci}         -- relayed verbatim to the opponent
///   client -> host  {type: "result", gameId, result: "white"|"black"|"draw"}
///   host -> all     {type: "standings", rows: [{id, username, points, games}]}
///   host -> client  {type: "opponent_left", gameId}      -- your opponent's connection dropped
///   host -> client  {type: "opponent_back", gameId}      -- they reconnected; carry on

typedef LocalMessage = Map<String, dynamic>;

class LocalPlayer {
  LocalPlayer(this.username, this.socket);
  String get id => username;
  final String username;
  final WebSocket socket;
}

/// Runs on the host device: binds a local server, tracks connected players, relays game
/// messages between the two players of each active pairing, and keeps each active game's board
/// server-side so a reconnecting player can be handed the current position.
class LocalTournamentHost {
  HttpServer? _server;
  final _players = <String, LocalPlayer>{}; // username -> connected player
  // gameId -> (whiteUsername, blackUsername)
  final _games = <String, (String, String)>{};
  final _boards = <String, ch.Chess>{};
  // Both players independently detect checkmate/stalemate and may each report a result (and a
  // resignation is reported by just one side) -- only the first report per game counts.
  final _resolvedGames = <String>{};
  int _gameCounter = 0;

  final _lobbyController = StreamController<List<LocalPlayer>>.broadcast();
  Stream<List<LocalPlayer>> get lobby => _lobbyController.stream;

  /// (gameId, whiteId, blackId, result) -- fired when either player reports how a game ended,
  /// so the host can update standings. Still relayed to the opponent as a normal message too.
  final _resultsController = StreamController<(String, String, String, String)>.broadcast();
  Stream<(String, String, String, String)> get results => _resultsController.stream;

  List<LocalPlayer> get players => _players.values.toList();

  /// Starts the server and returns this device's local IP (for the QR code), or null if no
  /// WiFi interface was found.
  Future<String?> start() async {
    final ip = await _localIp();
    if (ip == null) return null;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, localTournamentPort);
    _server!.listen((req) {
      if (WebSocketTransformer.isUpgradeRequest(req)) {
        WebSocketTransformer.upgrade(req).then(_onClientConnected);
      }
    });
    return ip;
  }

  void _onClientConnected(WebSocket socket) {
    String? username;
    socket.listen(
      (raw) {
        final msg = jsonDecode(raw as String) as LocalMessage;
        if (msg['type'] == 'join') {
          final name = msg['username'] as String? ?? 'Player';
          if (_players.containsKey(name)) {
            _send(socket, {'type': 'name_taken'});
            return;
          }
          username = name;
          _players[name] = LocalPlayer(name, socket);
          _send(socket, {'type': 'welcome', 'clientId': name});
          _broadcastLobby();
          _resumeIfInGame(name);
        } else {
          _route(username, msg);
        }
      },
      onDone: () {
        if (username != null) {
          _players.remove(username);
          _notifyOpponentLeft(username!);
          _broadcastLobby();
        }
      },
      cancelOnError: true,
    );
  }

  /// If [username] was mid-game when they dropped, hand them the game back at its current
  /// position (reusing the "pairing" message, which the client already knows how to open into
  /// a board) and tell the opponent they're back.
  void _resumeIfInGame(String username) {
    for (final entry in _games.entries) {
      final (whiteId, blackId) = entry.value;
      if (whiteId != username && blackId != username) continue;
      if (_resolvedGames.contains(entry.key)) continue;
      final isWhite = whiteId == username;
      final opponentName = isWhite ? blackId : whiteId;
      final me = _players[username];
      final opponent = _players[opponentName];
      final board = _boards[entry.key];
      if (me != null && board != null) {
        _send(me.socket, {
          'type': 'pairing',
          'gameId': entry.key,
          'color': isWhite ? 'white' : 'black',
          'opponent': opponentName,
          'fen': board.fen,
        });
      }
      if (opponent != null) _send(opponent.socket, {'type': 'opponent_back', 'gameId': entry.key});
      return; // a player is only ever in one active game at a time
    }
  }

  void _notifyOpponentLeft(String username) {
    for (final entry in _games.entries) {
      final (whiteId, blackId) = entry.value;
      if (whiteId != username && blackId != username) continue;
      if (_resolvedGames.contains(entry.key)) continue;
      final opponentName = whiteId == username ? blackId : whiteId;
      final opponent = _players[opponentName];
      if (opponent != null) _send(opponent.socket, {'type': 'opponent_left', 'gameId': entry.key});
      return;
    }
  }

  void _route(String? fromId, LocalMessage msg) {
    if (fromId == null) return;
    final gameId = msg['gameId'] as String?;
    final game = gameId != null ? _games[gameId] : null;
    if (game == null) return;
    final (whiteId, blackId) = game;
    if (msg['type'] == 'move') {
      final uci = msg['uci'] as String?;
      final board = _boards[gameId];
      if (uci != null && board != null && uci.length >= 4) {
        board.move({'from': uci.substring(0, 2), 'to': uci.substring(2, 4), 'promotion': uci.length > 4 ? uci[4] : null});
      }
    }
    if (msg['type'] == 'result' && _resolvedGames.add(gameId!) && !_resultsController.isClosed) {
      _resultsController.add((gameId, whiteId, blackId, msg['result'] as String));
    }
    final opponentId = fromId == whiteId ? blackId : whiteId;
    final opponent = _players[opponentId];
    if (opponent != null) _send(opponent.socket, msg);
  }

  void _broadcastLobby() {
    if (!_lobbyController.isClosed) _lobbyController.add(players);
    final payload = {
      'type': 'lobby',
      'players': players.map((p) => {'id': p.id, 'username': p.username}).toList(),
    };
    for (final p in players) {
      _send(p.socket, payload);
    }
  }

  /// Pairs two connected players for a new game, telling each their color and opponent name.
  /// Returns the new game's id.
  String startGame(String whiteId, String blackId, {String fen = kStartFen}) {
    final gameId = 'g${++_gameCounter}';
    _games[gameId] = (whiteId, blackId);
    _boards[gameId] = ch.Chess.fromFEN(fen, check_validity: false);
    final white = _players[whiteId];
    final black = _players[blackId];
    if (white != null && black != null) {
      _send(white.socket, {'type': 'pairing', 'gameId': gameId, 'color': 'white', 'opponent': black.username, 'fen': fen});
      _send(black.socket, {'type': 'pairing', 'gameId': gameId, 'color': 'black', 'opponent': white.username, 'fen': fen});
    }
    return gameId;
  }

  void broadcastStandings(List<Map<String, dynamic>> rows) {
    final payload = {'type': 'standings', 'rows': rows};
    for (final p in players) {
      _send(p.socket, payload);
    }
  }

  void _send(WebSocket s, LocalMessage msg) {
    // readyState can still read `open` a moment before the underlying sink actually rejects a
    // write (the socket is mid-close, e.g. a player who just left) -- best-effort send.
    if (s.readyState != WebSocket.open) return;
    try {
      s.add(jsonEncode(msg));
    } catch (_) {
      /* the player disconnected between the check and the write; nothing to do */
    }
  }

  Future<void> stop() async {
    for (final p in players) {
      await p.socket.close();
    }
    await _server?.close(force: true);
    await _lobbyController.close();
    await _resultsController.close();
  }

  static Future<String?> _localIp() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    for (final i in interfaces) {
      for (final a in i.addresses) {
        // Private LAN ranges a phone hotspot or home router hands out.
        if (a.address.startsWith('192.168.') || a.address.startsWith('172.') || a.address.startsWith('10.')) {
          return a.address;
        }
      }
    }
    return null;
  }
}

/// Runs on a joining device: connects to the host's IP, sends/receives messages.
class LocalTournamentClient {
  WebSocket? _socket;
  StreamSubscription? _socketSub;
  final _messages = StreamController<LocalMessage>.broadcast();
  Stream<LocalMessage> get messages => _messages.stream;

  void _emit(LocalMessage msg) {
    if (!_messages.isClosed) _messages.add(msg);
  }

  Future<bool> connect(String hostIp, String username) async {
    try {
      _socket = await WebSocket.connect('ws://$hostIp:$localTournamentPort').timeout(const Duration(seconds: 6));
    } catch (_) {
      return false;
    }
    _socketSub = _socket!.listen(
      (raw) => _emit(jsonDecode(raw as String) as LocalMessage),
      onDone: () => _emit({'type': 'disconnected'}),
      cancelOnError: true,
    );
    send({'type': 'join', 'username': username});
    return true;
  }

  void send(LocalMessage msg) {
    final s = _socket;
    if (s == null || s.readyState != WebSocket.open) return;
    try {
      s.add(jsonEncode(msg));
    } catch (_) {
      /* disconnected between the check and the write */
    }
  }

  Future<void> disconnect() async {
    // Cancel the listener first so its onDone (fired by closing the socket below) can't race
    // the stream controller's close -- otherwise it tries to add to an already-closed stream.
    await _socketSub?.cancel();
    await _socket?.close();
    await _messages.close();
  }
}

const kStartFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
