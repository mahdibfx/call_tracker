import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:call_tracker/data/api_service.dart';
import 'package:call_tracker/data/models.dart';

class AuthService {
  static const _sessionKey = 'agent_session';

  static Future<Agent?> login(String email, String password) async {
    final agent = await ApiService.login(email, password);
    if (agent == null) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(agent.toJson()));
    return agent;
  }

  static Future<Agent?> currentAgent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return null;
    return Agent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await ApiService.clearToken();
  }
}
