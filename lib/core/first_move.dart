/// What to show right after onboarding finishes a brand-new guest sign-in: a beginner goes
/// to the "How the pieces move" tutorial, everyone else straight into a bot game against
/// Army Legend. Consumed once by HomeShell, the same one-shot pattern as ActiveGame's
/// "resume the game that was open when the app closed".
enum FirstMoveIntent { tutorial, bot }

class PendingFirstMove {
  static FirstMoveIntent? _pending;

  static void set(FirstMoveIntent intent) => _pending = intent;

  static FirstMoveIntent? take() {
    final v = _pending;
    _pending = null;
    return v;
  }
}
