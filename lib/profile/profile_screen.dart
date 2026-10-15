import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/passkeys_screen.dart';
import '../auth/save_account_screen.dart';
import '../auth/two_factor_screen.dart';
import '../coaching/coaches_screen.dart';
import '../coaching/my_sessions_screen.dart';
import '../core/api.dart';
import '../core/hc_widgets.dart';
import '../core/nigeria_states.dart';
import '../core/push.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../learn/learn_screen.dart';
import 'leaderboard_screen.dart';
import 'subscription_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _me;
  String? _error;
  final _settingsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _scrollToSettings() {
    final ctx = _settingsKey.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
  }

  Future<void> _load() async {
    try {
      final me = await Api.instance.get('/me') as Map<String, dynamic>;
      if (mounted) setState(() => _me = me);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = _me?['account'] as Map?;
    final ratings = (_me?['ratings'] as List?) ?? const [];
    final puzzles = _me?['puzzles'] as Map?;
    final username = account?['username'] as String? ?? 'Profile';
    final streak = (puzzles?['current_streak'] as num?)?.toInt() ?? 0;
    final tier = account?['tier'] as String?;
    String ratingFor(String timeControl) {
      for (final r in ratings.cast<Map>()) {
        if (r['time_control'] == timeControl) return '${r['rating']}';
      }
      return '—';
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          ScreenHeader(
            title: 'Profile',
            actions: [IconButton(onPressed: _scrollToSettings, icon: const Icon(Icons.settings_rounded))],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HcSpace.s4),
            child: HeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      HcAvatar(name: username, size: HcSize.avatarLg),
                      const SizedBox(width: HcSpace.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(username, style: HcText.titleLg.copyWith(color: HcColors.onForest)),
                            if (account != null) HeroCard.sub('${account['country'] ?? 'Unknown'}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (streak > 0 || (tier != null && tier != 'free')) ...[
                    const SizedBox(height: HcSpace.s3),
                    Wrap(spacing: HcSpace.s2, runSpacing: HcSpace.s2, children: [
                      if (tier != null && tier != 'free')
                        HcBadge.onHero(tier.toUpperCase(), icon: Icons.workspace_premium_rounded),
                      if (streak > 0) HcBadge.onHero('$streak day streak', icon: Icons.local_fire_department_rounded),
                    ]),
                  ],
                  const SizedBox(height: HcSpace.s4),
                  Row(children: [
                    Expanded(child: HeroCard.tile(label: 'Rapid', value: ratingFor('rapid'))),
                    const SizedBox(width: HcSpace.s2),
                    Expanded(child: HeroCard.tile(label: 'Blitz', value: ratingFor('blitz'))),
                    const SizedBox(width: HcSpace.s2),
                    Expanded(child: HeroCard.tile(label: 'Puzzles', value: puzzles == null ? '—' : '${puzzles['rating']}')),
                  ]),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!)),
              if (account != null) ...[
                _SubscriptionRow(
                  tier: account['tier'] as String? ?? 'free',
                  onTap: () async {
                    await showSubscriptionSheet(context, account['tier'] as String? ?? 'free');
                    await _load();
                  },
                ),
                const SizedBox(height: HcSpace.s5),
              ],
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LearnScreen())),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Learn: tutorials & video lessons'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                icon: const Icon(Icons.leaderboard_outlined),
                label: const Text('Leaderboard'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoachesScreen())),
                icon: const Icon(Icons.school_outlined),
                label: const Text('Find a coach'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MySessionsScreen())),
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('My coaching sessions'),
              ),
              const SizedBox(height: HcSpace.s5),
              SectionLabel('Settings', icon: Icons.settings_outlined, key: _settingsKey),
              HcListGroup(children: [
                ListenableBuilder(
                  listenable: AppSettings.instance,
                  builder: (context, _) => HcListRow(
                    title: 'Low data mode',
                    subtitle: 'No pictures or animations. This session: ${DataMeter.label}.',
                    trailing: Switch(value: AppSettings.instance.lowData, onChanged: AppSettings.instance.setLowData),
                  ),
                ),
                ListenableBuilder(
                  listenable: AppSettings.instance,
                  builder: (context, _) => HcListRow(
                    title: 'Language',
                    subtitle: appLanguages[AppSettings.instance.language] ?? 'English',
                    onTap: () => _editLanguage(context),
                  ),
                ),
                if (Supabase.instance.client.auth.currentUser?.isAnonymous == false) ...[
                  HcListRow(
                    title: 'Location',
                    subtitle: account?['state'] as String? ?? 'For state leaderboards',
                    onTap: () => _editState(context),
                  ),
                  HcListRow(
                    title: 'Passkeys',
                    subtitle: 'Sign in with your face, fingerprint or a security key',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PasskeysScreen())),
                  ),
                  HcListRow(
                    title: 'Two-factor sign-in',
                    subtitle: 'An authenticator-app code, each time you sign in',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TwoFactorScreen())),
                  ),
                  HcListRow(
                    title: 'Sign out everywhere',
                    subtitle: 'End every other session -- for a lost or stolen phone',
                    onTap: () => _signOutEverywhere(context),
                  ),
                ] else
                  HcListRow(
                    title: 'Save my account',
                    subtitle: "Keep your games and rating -- you're playing as a guest",
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SaveAccountScreen())),
                  ),
                HcListRow(
                  title: 'About & licences',
                  subtitle: 'Open-source software used in this app',
                  onTap: () => showLicensePage(context: context, applicationName: 'Hamduk Chess'),
                ),
              ]),
              const SizedBox(height: HcSpace.s5),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _signOut(context),
                  child: const Text('Sign out'),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _editLanguage(BuildContext context) async {
    final current = AppSettings.instance.language;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final entry in appLanguages.entries)
              ListTile(
                title: Text(entry.value),
                trailing: entry.key == current ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, entry.key),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || chosen == current) return;
    await AppSettings.instance.setLanguage(chosen);
    if (Supabase.instance.client.auth.currentUser?.isAnonymous == false) {
      try {
        await Api.instance.patch('/account', {'language': chosen});
      } on ApiError {
        // Best-effort; the device-local preference above is what actually matters today.
      }
    }
  }

  Future<void> _editState(BuildContext context) async {
    final current = _me?['account']?['state'] as String?;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in nigeriaStates)
              ListTile(title: Text(s), trailing: s == current ? const Icon(Icons.check_rounded) : null, onTap: () => Navigator.pop(ctx, s)),
          ],
        ),
      ),
    );
    if (chosen == null || chosen == current) return;
    try {
      await Api.instance.patch('/account', {'state': chosen});
      await _load();
    } on ApiError catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;
    await Push.stop();
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _signOutEverywhere(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out everywhere?'),
        content: const Text('Every other phone, tablet or browser signed into this account will be signed out. This phone stays signed in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: HcButtons.danger(ctx), onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out everywhere')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.others);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Every other session has been signed out.')));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't reach the server. Try again.")));
    }
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({required this.tier, required this.onTap});
  final String tier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final isFree = tier == 'free';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isFree ? hc.surface : hc.greenSoft,
        borderRadius: BorderRadius.circular(HcRadius.md),
        boxShadow: isFree ? HcShadows.e1(hc.brightness) : null,
      ),
      child: HcListRow(
        leading: Icon(
          isFree ? Icons.workspace_premium_outlined : Icons.workspace_premium_rounded,
          color: isFree ? hc.ink2 : hc.green,
        ),
        title: isFree ? 'Free plan' : '${tier[0].toUpperCase()}${tier.substring(1)} plan',
        subtitle: isFree ? 'Upgrade for unlimited puzzles and more' : 'Tap to manage your subscription',
        trailing: isFree
            ? FilledButton.tonal(onPressed: onTap, child: const Text('Upgrade'))
            : Icon(Icons.chevron_right_rounded, color: hc.green),
        onTap: onTap,
      ),
    );
  }
}
