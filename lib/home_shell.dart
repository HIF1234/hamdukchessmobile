// Supabase's own passkey API is marked @experimental (it's a beta feature on their side,
// not an unstable choice on ours); every call into it trips this lint.
// ignore_for_file: experimental_member_use
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'auth/passkey_auth.dart';
import 'bots/bot_game_screen.dart';
import 'core/active_game.dart';
import 'core/api.dart';
import 'core/app_config.dart';
import 'core/app_shortcuts.dart';
import 'core/first_move.dart';
import 'core/hc_widgets.dart';
import 'core/links.dart';
import 'core/push.dart';
import 'core/settings.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'core/whats_new.dart';
import 'games/game_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'games/challenge_screens.dart';
import 'games/play_screen.dart';
import 'learn/learn_screen.dart';
import 'learn/tutorial_screen.dart';
import 'local_play/local_tournament_home_screen.dart';
import 'profile/profile_screen.dart';
import 'puzzles/daily_puzzle_screen.dart';
import 'puzzles/puzzles_screen.dart';
import 'social/social_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.config, required this.appVersion});
  final AppConfig config;
  final String appVersion;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  StreamSubscription<String>? _links;
  StreamSubscription<String>? _gameLinks;
  StreamSubscription<void>? _dailyPuzzleLinks;
  bool _offlineBannerDismissed = false;
  bool _updateBannerDismissed = false;

  bool _online = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _presenceTimer;
  Timer? _badgeTimer;
  int _yourMoveCount = 0; // Play tab badge
  bool _socialUnread = false; // Social tab dot
  StreamSubscription<AppShortcut>? _shortcutTaps;

  @override
  void initState() {
    super.initState();
    // Challenge links: open now, including one that arrived before sign-in.
    _links = IncomingLinks.instance.challenges.listen(_openChallenge);
    final pending = IncomingLinks.instance.takePending();
    if (pending != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openChallenge(pending));
    // Tapped notifications ("Your move", challenge accepted) open their game.
    _gameLinks = IncomingLinks.instance.games.listen(_openGame);
    final pendingGame = IncomingLinks.instance.takePendingGame();
    if (pendingGame != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openGame(pendingGame));
    // Tapped daily puzzle / streak reminder notifications open the daily puzzle.
    _dailyPuzzleLinks = IncomingLinks.instance.dailyPuzzle.listen((_) => _openDailyPuzzle());
    if (IncomingLinks.instance.takePendingDailyPuzzle()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDailyPuzzle());
    }
    _maybeStartPush();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptPasskey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeResumeGame());
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartFirstMove());
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOfferLowData());
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleShortcut());
    WidgetsBinding.instance.addPostFrameCallback((_) => maybeShowWhatsNew(context, widget.appVersion));
    _watchConnectivity();
    _loadBadges();
    _badgeTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadBadges());
    _sendPresence();
    _presenceTimer = Timer.periodic(const Duration(seconds: 20), (_) => _sendPresence());
    _shortcutTaps = AppShortcuts.onTap.listen(_runShortcut);
  }

  void _handleShortcut() {
    final shortcut = AppShortcuts.take();
    if (shortcut != null) _runShortcut(shortcut);
  }

  void _runShortcut(AppShortcut shortcut) {
    switch (shortcut) {
      case AppShortcut.play5:
        setState(() => _tab = _homeTab);
        PlayScreenActions.requestSeek('5+0');
      case AppShortcut.dailyPuzzle:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DailyPuzzleScreen()));
      case AppShortcut.hostLocal:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LocalTournamentHomeScreen()));
    }
  }

  Future<void> _watchConnectivity() async {
    final initial = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _online = !initial.contains(ConnectivityResult.none));
    _connectivity = Connectivity().onConnectivityChanged.listen((r) {
      if (mounted) setState(() => _online = !r.contains(ConnectivityResult.none));
    });
  }

  void _sendPresence() {
    if (Supabase.instance.client.auth.currentSession == null) return;
    Api.instance.post('/presence').catchError((_) => null);
  }

  /// Games waiting for your move (Play tab) and unread messages/friend requests (Social
  /// tab) -- a plain poll, same cadence the rest of the app already uses for this kind of
  /// thing, rather than a dedicated realtime channel for a badge.
  Future<void> _loadBadges() async {
    if (Supabase.instance.client.auth.currentSession == null) return;
    try {
      final games = await Api.instance.get('/games') as Map<String, dynamic>;
      final active = (games['active'] as List).cast<Map<String, dynamic>>();
      final me = Supabase.instance.client.auth.currentUser!.id;
      final yourMove = active.where((g) {
        final isWhite = g['white_id'] == me;
        final whiteToMove = (g['fen'] as String).split(' ')[1] == 'w';
        return whiteToMove == isWhite;
      }).length;
      if (mounted) setState(() => _yourMoveCount = yourMove);
    } catch (_) {
      // Leave the last known count rather than flashing it away on a blip.
    }
    try {
      final friends = await Api.instance.get('/social/friends') as Map<String, dynamic>;
      final incoming = (friends['incoming'] as List).isNotEmpty;
      final messages = await Api.instance.get('/social/messages') as Map<String, dynamic>;
      final unread = (messages['conversations'] as List).cast<Map>().any((c) => (c['unread'] as int? ?? 0) > 0);
      if (mounted) setState(() => _socialUnread = incoming || unread);
    } catch (_) {
      // Same as above.
    }
  }

  /// Registers this phone for push right away only if notification permission was already
  /// decided (granted or denied) before -- an existing player, or one who has already been
  /// through the in-game prompt below. A brand-new install waits for NotificationPrompt to
  /// ask with its one-line reason, right after the first finished game, not at launch.
  Future<void> _maybeStartPush() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.notDetermined) Push.start();
  }

  /// Onboarding just created this guest's session and decided what their first move should
  /// be (PendingFirstMove) -- open it now, once.
  Future<void> _maybeStartFirstMove() async {
    final intent = PendingFirstMove.take();
    if (intent == null || !mounted) return;
    switch (intent) {
      case FirstMoveIntent.tutorial:
        try {
          final tutorial = await Api.instance.get('/tutorials/how-pieces-move') as Map<String, dynamic>;
          if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => TutorialScreen(tutorial: tutorial)));
        } on ApiError {
          // Offline; they'll find it in Learn once connected.
        }
      case FirstMoveIntent.bot:
        final matches = widget.config.bots.where((b) => b['id'] == 'army_legend');
        if (matches.isEmpty || !mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BotGameScreen(bot: matches.first, playWhite: true, autoHint: true),
        ));
    }
  }

  /// "You're on mobile data. Use less data?" -- asked at most once per install.
  Future<void> _maybeOfferLowData() async {
    if (AppSettings.instance.lowData) return;
    final store = await JsonStore.open();
    if (await store.read('mobile_data_prompt_asked') == true) return;
    await store.write('mobile_data_prompt_asked', true);
    final result = await Connectivity().checkConnectivity();
    if (!result.contains(ConnectivityResult.mobile) || !mounted) return;
    final use = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("You're on mobile data."),
        content: const Text('Use less data? Turns off pictures and animations -- you can change this any time in Settings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Use less data')),
        ],
      ),
    );
    if (use == true) await AppSettings.instance.setLowData(true);
  }

  /// If the app closed mid-game last time, reopen it now: online games reconnect through
  /// the game screen's own controller, bot games replay their saved moves.
  Future<void> _maybeResumeGame() async {
    final pending = await ActiveGame.takePending();
    if (pending == null || !mounted) return;
    final me = Supabase.instance.client.auth.currentUser?.id;
    switch (pending) {
      case OnlineActiveGame(gameId: final id):
        if (me == null) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(gameId: id, myId: me)));
      case BotActiveGame(
          botId: final botId,
          playWhite: final playWhite,
          sanMoves: final moves,
          timeControl: final timeControl,
          whiteMs: final whiteMs,
          blackMs: final blackMs,
        ):
        final matches = widget.config.bots.where((b) => b['id'] == botId);
        if (matches.isEmpty) return;
        final bot = matches.first;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BotGameScreen(
            bot: bot,
            playWhite: playWhite,
            initialSanMoves: moves,
            timeControl: timeControl,
            initialWhiteMs: whiteMs,
            initialBlackMs: blackMs,
          ),
        ));
    }
  }

  /// Offers to add a passkey once per account, right after a real (non-guest) sign-in, so
  /// "sign in faster next time" lands when it's actually true -- not buried in Settings where
  /// most players will never find it on their own.
  Future<void> _maybePromptPasskey() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    final store = await JsonStore.open();
    final key = 'passkey_prompt_asked_${user.id}';
    if (await store.read(key) == true) return;
    await store.write(key, true); // ask at most once per account, regardless of outcome below

    final List<Passkey> existing;
    try {
      existing = await Supabase.instance.client.auth.passkey.list();
    } catch (_) {
      return; // offline, or the server doesn't have passkeys configured; skip quietly
    }
    if (existing.isNotEmpty || !mounted) return;

    final add = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => const _PasskeyPromptSheet());
    if (add != true || !mounted) return;
    try {
      await PasskeyAuth.register();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Passkey added. You can sign in with it next time.')));
      }
    } catch (e) {
      if (mounted && !PasskeyAuth.isCancellation(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't add a passkey right now. You can try again later in Profile → Settings.")),
        );
      }
    }
  }

  void _openGame(String id) {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (!mounted || me == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(gameId: id, myId: me)));
  }

  void _openChallenge(String id) {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChallengeAcceptScreen(challengeId: id)));
  }

  void _openDailyPuzzle() {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DailyPuzzleScreen()));
  }

  @override
  void dispose() {
    _links?.cancel();
    _gameLinks?.cancel();
    _dailyPuzzleLinks?.cancel();
    _connectivity?.cancel();
    _presenceTimer?.cancel();
    _badgeTimer?.cancel();
    _shortcutTaps?.cancel();
    super.dispose();
  }

  static const _homeTab = 0; // Play

  @override
  Widget build(BuildContext context) {
    final pages = [
      PlayScreen(config: widget.config),
      const PuzzlesScreen(),
      const LearnScreen(),
      const SocialScreen(),
      const ProfileScreen(),
    ];
    return PopScope(
      canPop: _tab == _homeTab,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _tab = _homeTab);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (widget.config.maintenanceEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(HcSpace.s4, HcSpace.s2, HcSpace.s4, 0),
                  child: HcBanner(icon: Icons.build_rounded, text: widget.config.maintenanceMessage, tone: HcBannerTone.info),
                ),
              if ((!_online || widget.config.isBundledFallback) && !_offlineBannerDismissed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(HcSpace.s4, HcSpace.s2, HcSpace.s4, 0),
                  child: HcBanner(
                    icon: Icons.cloud_off_rounded,
                    text: 'Offline. Bots, puzzles and local play still work.',
                    tone: HcBannerTone.info,
                    actions: [TextButton(style: HcButtons.small(), onPressed: () => setState(() => _offlineBannerDismissed = true), child: const Text('Dismiss'))],
                  ),
                ),
              if (!_updateBannerDismissed && widget.config.hasOptionalUpdate(widget.appVersion))
                Padding(
                  padding: const EdgeInsets.fromLTRB(HcSpace.s4, HcSpace.s2, HcSpace.s4, 0),
                  child: HcBanner(
                    icon: Icons.system_update_rounded,
                    text: 'A new version of Hamduk Chess is available.',
                    tone: HcBannerTone.offer,
                    actions: [TextButton(style: HcButtons.small(), onPressed: () => setState(() => _updateBannerDismissed = true), child: const Text('Dismiss'))],
                  ),
                ),
              Expanded(child: IndexedStack(index: _tab, children: pages)),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            NavigationDestination(
              icon: _yourMoveCount > 0 ? Badge(label: Text('$_yourMoveCount'), child: const KnightIcon()) : const KnightIcon(),
              selectedIcon: _yourMoveCount > 0 ? Badge(label: Text('$_yourMoveCount'), child: const KnightIcon()) : const KnightIcon(),
              label: 'Play',
            ),
            const NavigationDestination(icon: Icon(Icons.extension_outlined), selectedIcon: Icon(Icons.extension_rounded), label: 'Puzzles'),
            const NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Learn'),
            NavigationDestination(
              icon: _socialUnread ? const Badge(child: Icon(Icons.people_outline_rounded)) : const Icon(Icons.people_outline_rounded),
              selectedIcon: _socialUnread ? const Badge(child: Icon(Icons.people_rounded)) : const Icon(Icons.people_rounded),
              label: 'Social',
            ),
            const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class _PasskeyPromptSheet extends StatelessWidget {
  const _PasskeyPromptSheet();

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(HcSpace.s5, HcSpace.s5, HcSpace.s5, HcSpace.s5),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: hc.greenSoft, shape: BoxShape.circle),
              child: Icon(Icons.fingerprint_rounded, color: hc.green, size: 28),
            ),
          ),
          const SizedBox(height: HcSpace.s4),
          Text('Sign in faster next time', style: HcText.displayMd.copyWith(color: hc.ink), textAlign: TextAlign.center),
          const SizedBox(height: HcSpace.s2),
          Text(
            'Add a passkey so you can sign in with your face, fingerprint or a security key — no password to type.',
            style: HcText.body.copyWith(color: hc.ink2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: HcSpace.s5),
          FilledButton(
            style: HcButtons.large(),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add a passkey'),
          ),
          const SizedBox(height: HcSpace.s2),
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not now')),
        ]),
      ),
    );
  }
}
