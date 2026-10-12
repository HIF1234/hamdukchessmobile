import 'dart:async';
import 'dart:convert';
import 'dart:io';

const localTournamentPort = 44441;

/// A local tournament runs on one phone's hotspot LAN -- no internet, nothing touches the
/// server. One device hosts (runs a raw WebSocket server via dart:io, no extra package needed),
/// the rest join over plain TCP once they're on the same WiFi network; the host relays moves
/// between paired players and tracks standings. Casual only: results never sync anywhere.
///
/// Message shapes (all JSON over one WebSocket connection per client):
///   client -> host  {type: "join", username}
///   host -> client  {type: "welcome", clientId}
///   host -> all     {type: "lobby", players: [{id, username}]}
///   host -> pair    {type: "pairing", gameId, color: "white"|"black", opponent, fen}
///   client -> host  {type: "move", gameId, uci}         -- relayed verbatim to the opponent
///   client -> host  {type: "result", gameId, result: "white"|"black"|"draw"}
///   host -> all     {type: "standings", rows: [{id, username, points, games}]}
///   either -> other {type: "bye"}                        -- opponent left mid-game

typedef LocalMessage = Map<String, dynamic>;

class LocalPlayer {
  LocalPlayer(this.id, this.username, this.socket);
  final String id;
  final String username;
  final WebSocket socket;
}

/// Runs on the host device: binds a local server, tracks connected players, relays game
/// messages between the two players of each active pairing.
class LocalTournamentHost {
  HttpServer? _server;
  final _players = <String, LocalPlayer>{};
  // gameId -> (whiteClientId, blackClientId)
  final _games = <String, (String, String)>{};
  // Both players independently detect checkmate/stalemate and may each report a result (and a
  // resignation is reported by just one side) -- only the first report per game counts.
  final _resolvedGames = <String>{};
  int _nextId = 1;

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
    String? id;
    socket.listen(
      (raw) {
        final msg = jsonDecode(raw as String) as LocalMessage;
        if (msg['type'] == 'join') {
          id = '${_nextId++}';
          _players[id!] = LocalPlayer(id!, msg['username'] as String? ?? 'Player', socket);
          _send(socket, {'type': 'welcome', 'clientId': id});
          _broadcastLobby();
        } else {
          _route(id, msg);
        }
      },
      onDone: () {
        if (id != null) {
          _players.remove(id);
          _broadcastLobby();
        }
      },
      cancelOnError: true,
    );
  }

  void _route(String? fromId, LocalMessage msg) {
    if (fromId == null) return;
    final gameId = msg['gameId'] as String?;
    final game = gameId != null ? _games[gameId] : null;
    if (game == null) return;
    final (whiteId, blackId) = game;
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
    final gameId = 'g${_games.length + 1}';
    _games[gameId] = (whiteId, blackId);
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
