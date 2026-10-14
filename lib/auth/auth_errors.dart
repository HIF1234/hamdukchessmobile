import 'package:supabase_flutter/supabase_flutter.dart';

/// Plain words for every auth failure. Supabase's own [AuthException.message] is meant for
/// developers, not players -- never show it directly.
String friendlyAuthError(Object error) {
  if (error is AuthException) {
    final m = error.message.toLowerCase();
    if (m.contains('invalid login credentials')) return 'Wrong email or password.';
    if (m.contains('email not confirmed')) return "Confirm your email first -- check your inbox for the link.";
    if (m.contains('already registered') || m.contains('user already exists')) {
      return 'An account already exists with that email. Try signing in instead.';
    }
    if (m.contains('rate limit') || m.contains('security purposes') || error.statusCode == '429') {
      return 'Too many tries. Wait a few minutes and try again.';
    }
    if (m.contains('password') && (m.contains('short') || m.contains('weak') || m.contains('least'))) {
      return 'Choose a longer password -- at least 8 characters.';
    }
    if (m.contains('invalid email')) return 'Enter a valid email address.';
    if (m.contains('expired') || m.contains('invalid') && m.contains('token')) {
      return "That link has expired. Request a new one.";
    }
    return "Something went wrong. Try again.";
  }
  return 'No internet. Check your data or Wi-Fi.';
}
