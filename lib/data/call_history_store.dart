import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:call_tracker/data/models.dart';

/// On-device record of finished calls, backing the History tab. The backend
/// has no history endpoint, so this is the only place past calls can be read
/// back — and it keeps working with no connection.
///
/// Records carry verification fields, but History must never render anything
/// derived from them (see CLAUDE.md).
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
