import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:call_tracker/data/models.dart';

/// Persists finished, verified calls for the test-mode monitor screen.
class CallHistoryStore {
  static const _key = 'call_history';

  static Future<void> add(CallRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await _read(prefs);
    records.insert(0, record);
    await prefs.setString(_key, jsonEncode(records.map((r) => r.toJson()).toList()));
  }

  static Future<List<CallRecord>> all() async {
    final prefs = await SharedPreferences.getInstance();
    return _read(prefs);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<List<CallRecord>> _read(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => CallRecord.fromJson(e as Map<String, dynamic>)).toList();
  }
}
