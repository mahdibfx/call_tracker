import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:call_tracker/data/api_service.dart';
import 'package:call_tracker/data/models.dart';

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
  static Future<void> restore() async {
    signedIn.value = await currentAgent();
  }

  static Future<Agent?> currentAgent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return null;
    return Agent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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
