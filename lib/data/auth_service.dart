import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:call_tracker/data/api_service.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/push_service.dart';

/// Who is signed in, as app-wide state.
///
/// `AuthGate` rebuilds from [signedIn], so signing in, signing out, or the
/// backend rejecting our token all move the whole app without any screen
/// navigating by hand.
class AuthService {
  static const _sessionKey = 'agent_session';

  /// The signed-in agent, or null when nobody is.
  static final ValueNotifier<Agent?> signedIn = ValueNotifier<Agent?>(null);

  /// Why the last session ended, when it ended on its own rather than by the
  /// agent logging out. The login screen shows it once so they aren't dumped
  /// back at sign-in with no explanation.
  static String? endedReason;

  /// Loads any stored session. Call once at startup, before the first frame.
  ///
  /// Paints from the cache immediately and re-checks the token with the backend
  /// afterwards, without blocking: the API is on a host that cold-starts, and
  /// awaiting a round-trip here would add seconds to every launch. `AuthGate`
  /// listens to [signedIn], so the shell simply re-renders when the check lands
  /// — the same path that already handles a session expiring mid-use.
  ///
  /// The exception is a session stored by a build that predates roles. It has
  /// nothing to route on, so [revalidate] is awaited for that case alone.
  static Future<void> restore() async {
    final cached = await currentAgent();
    signedIn.value = cached;
    if (cached == null) return;

    if (cached.role == null || await storedSessionIsLegacy()) {
      await revalidate();
      // Still no role: the stored session predates roles and we could not
      // complete it (no token, or the backend was unreachable). There is
      // nothing to route on, so ask for a sign-in rather than leaving the app
      // on its loading state forever.
      if (signedIn.value != null && signedIn.value!.role == null) {
        await _endWith('Please sign in again to continue.');
      }
      return;
    }
    // Unawaited on purpose — see above.
    revalidate();
  }

  /// Re-reads the account from the backend and updates the session in place.
  ///
  /// Keeps the cached session on a network failure so the app still works
  /// offline; ends it when the backend says the token is dead; ejects a teacher
  /// whose role changed under an active session.
  static Future<void> revalidate() async {
    final result = await ApiService.verifyToken();
    switch (result) {
      case VerifyNetwork():
        return;
      case VerifyInvalid():
        await expire();
      case VerifyOk(:final agent):
        if (agent.role == StaffRole.teacher) {
          await _endWith(LoginFailure.teacherAccount.message);
          return;
        }
        if (agent.role == null) {
          await _endWith(LoginFailure.unsupportedRole.message);
          return;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sessionKey, jsonEncode(agent.toJson()));
        signedIn.value = agent;
    }
  }

  /// Ends the session and leaves [endedReason] for the login screen to show
  /// once, so the user is told why they were signed out.
  static Future<void> _endWith(String reason) async {
    await _clear();
    endedReason = reason;
    signedIn.value = null;
  }

  /// The stored session, or null when there is none or it cannot be read.
  ///
  /// Never throws. `main()` awaits this before `runApp`, so an exception here
  /// would leave the app with no first frame and no login screen to fall back
  /// to — unrecoverable without clearing app data. A session we cannot parse
  /// is discarded instead, which costs the user one sign-in.
  static Future<Agent?> currentAgent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw == null) return null;
      return Agent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await _clear();
      return null;
    }
  }

  /// Whether the stored session predates roles and so cannot be routed until
  /// it has been re-validated against the backend.
  static Future<bool> storedSessionIsLegacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw == null) return false;
      return Agent.isLegacyBlob(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return false;
    }
  }

  /// Returns null on success, or why it failed.
  static Future<LoginFailure?> signIn(String email, String password) async {
    final result = await ApiService.login(email, password);
    final agent = result.agent;
    if (agent == null) return result.failure ?? LoginFailure.server;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(agent.toJson()));
    endedReason = null;
    signedIn.value = agent;
    return null;
  }

  static Future<void> signOut() async {
    // Before _clear: unregistering needs the token it is about to discard, so
    // a shared handset stops showing the previous user's reports.
    await PushService.unregister();
    await _clear();
    endedReason = null;
    signedIn.value = null;
  }

  /// The backend rejected our token, so the session is over whether the agent
  /// wanted it or not. Returns whether there was actually a session to end —
  /// concurrent 401s from several screens refreshing at once should only
  /// bounce the agent to the login screen once.
  static Future<bool> expire() async {
    if (signedIn.value == null) return false;
    await _clear();
    endedReason = 'Your session ended. Please sign in again.';
    signedIn.value = null;
    return true;
  }

  static Future<void> _clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await ApiService.clearToken();
  }
}
