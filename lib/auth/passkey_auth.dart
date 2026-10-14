// Supabase's own passkey API is marked @experimental (it's a beta feature on their side,
// not an unstable choice on ours); every call into it trips this lint.
// ignore_for_file: experimental_member_use
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bridges the `passkeys` plugin's native WebAuthn ceremony (FaceID/TouchID,
/// fingerprint, security key) to Supabase's passkey endpoints. Supabase runs
/// the server side of the ceremony (challenges, storage, verification); this
/// only drives the on-device prompt and hands the result back to it.
class PasskeyAuth {
  static final _authenticator = PasskeyAuthenticator();

  /// Registers a new passkey for the signed-in (non-anonymous) user.
  /// [friendlyName] is the account label the OS passkey sheet shows.
  static Future<void> register({String? friendlyName}) async {
    final auth = Supabase.instance.client.auth;
    final reg = await auth.passkey.startRegistration(friendlyName: friendlyName);
    final response = await _authenticator.register(RegisterRequestType.fromJson(reg.options));
    await auth.passkey.verifyRegistration(challengeId: reg.challengeId, credential: response.toJson());
  }

  /// Signs in with a passkey already on this device (or synced via the
  /// platform's passkey provider). Saves the session on success, same as any
  /// other sign-in.
  static Future<void> signIn() async {
    final auth = Supabase.instance.client.auth;
    final start = await auth.passkey.startAuthentication();
    final response = await _authenticator.authenticate(AuthenticateRequestType.fromJson(start.options));
    await auth.passkey.verifyAuthentication(challengeId: start.challengeId, credential: response.toJson());
  }

  /// True if the user simply dismissed the OS passkey sheet — not an error
  /// to show, same convention as [GoogleAuth.isCancellation].
  static bool isCancellation(Object e) => e is PasskeyAuthCancelledException;
}
