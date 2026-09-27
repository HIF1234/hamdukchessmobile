import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Native Google sign-in, bridged into Supabase.
///
/// Requires GOOGLE_WEB_CLIENT_ID to be set on the server (exposed via /config as
/// googleWebClientId) — this is the Web-type OAuth client that Supabase's Google provider
/// already accepts as an audience for the website's own "Continue with Google". Native
/// Android sign-in requests an ID token for that same client, so no change is needed on
/// Supabase's side.
///
/// Also requires an Android-type OAuth client to exist in the same Google Cloud project,
/// registered with this app's package name (ng.com.hamduk.chess) and signing certificate
/// SHA-1 — Google's Android sign-in flow is authorized by that pairing, not by a client ID
/// in code. There is currently no API to create that client; it's a one-time manual step in
/// Google Cloud Console → APIs & Services → Credentials → Create OAuth client ID → Android.
class GoogleAuth {
  static bool _initialized = false;
  static String? _webClientId;

  static Future<void> _ensureInitialized(String webClientId) async {
    if (_initialized && _webClientId == webClientId) return;
    await GoogleSignIn.instance.initialize(serverClientId: webClientId);
    _initialized = true;
    _webClientId = webClientId;
  }

  /// Signs in with Google and starts a Supabase session. Throws on failure or cancellation
  /// (a cancelled Google picker throws GoogleSignInException with code canceled — callers
  /// should treat that one as "no error to show", not a failure).
  static Future<void> signIn(String webClientId) async {
    await _ensureInitialized(webClientId);
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError("Google didn't return an ID token. Try again.");
    }
    await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  /// True if the user simply closed the Google account picker.
  static bool isCancellation(Object e) => e is GoogleSignInException && e.code == GoogleSignInExceptionCode.canceled;
}
