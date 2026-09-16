import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:call_tracker/data/models.dart';

class ApiService {
  static const _host = 'https://backendelameed.onrender.com';

  /// Call-tracker routes. These return plain JSON bodies — no `{success,
  /// message, data}` envelope, unlike the rest of the API (see [getGroupStudents]).
  static const _baseUrl = '$_host/call-tracker';
  static const _tokenKey = 'jwt_token';

  /// The backend caps `limit` at 100.
  static const studentsPageSize = 100;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// POST /auth/login — returns Agent on success, null on failure.
  static Future<Agent?> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      await _saveToken(json['token'] as String);
      final agentJson = json['agent'] as Map<String, dynamic>;
      return Agent(
        id: agentJson['id'].toString(),
        name: agentJson['name'] as String,
        email: agentJson['email'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  /// GET /call-tracker/students — one page of the dialing list. Null when the
  /// request failed, so a refresh on a flaky connection can leave the list it
  /// already has alone instead of blanking it.
  ///
  /// [search] matches name, email and any phone on file, server-side — the
  /// roster is far too large to filter on the device.
  static Future<Paged<Student>?> getStudents({
    int page = 1,
    int limit = studentsPageSize,
    String? search,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/students').replace(queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      });
      final res = await http.get(uri, headers: await _authHeaders());
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return Paged.fromJson(body, Student.fromJson);
    } catch (_) {
      return null;
    }
  }

  /// GET /call-tracker/groups — every group, unpaginated. Null on failure.
  /// Carries no roster; see [getGroupStudents].
  static Future<List<Group>?> getGroups() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/groups'),
        headers: await _authHeaders(),
      );
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>;
      return list
          .map((e) => Group.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// GET /groups/:id/students — the roster for one group. Null on failure.
  ///
  /// This one is NOT a call-tracker route: it sits at the host root and wraps
  /// its payload in the app-wide `{success, message, data}` envelope, so the
  /// page lives at `data`, one level deeper than the call-tracker endpoints.
  static Future<Paged<Student>?> getGroupStudents(
    String groupId, {
    int page = 1,
    int limit = studentsPageSize,
  }) async {
    try {
      final uri = Uri.parse('$_host/groups/$groupId/students')
          .replace(queryParameters: {'page': '$page', 'limit': '$limit'});
      final res = await http.get(uri, headers: await _authHeaders());
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final inner = body['data'] as Map<String, dynamic>?;
      if (inner == null) return null;
      return Paged.fromJson(inner, Student.fromJson);
    } catch (_) {
      return null;
    }
  }

  /// POST /call-tracker/calls — log one finished call.
  ///
  /// The backend recomputes the verdict from these fields; anything the client
  /// sent as a verdict would be ignored, so none is sent.
  static Future<Map<String, dynamic>?> submitCall({
    required String studentId,
    required String studentName,
    required String reason,
    required String outcome,
    String? notes,
    required bool reallyDialed,
    required int talkDurationSeconds,
    int? ringSessionSeconds,
    required bool likelyHungUpEarly,
    required bool endedQuickly,
    required String finalResult,
    required int startedAtEpochMs,
    required int endedAtEpochMs,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/calls'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'studentId': studentId,
          'studentName': studentName,
          'reason': reason,
          'outcome': outcome,
          'notes': notes,
          'reallyDialed': reallyDialed,
          'talkDurationSeconds': talkDurationSeconds,
          'ringSessionSeconds': ringSessionSeconds,
          'likelyHungUpEarly': likelyHungUpEarly,
          'endedQuickly': endedQuickly,
          'finalResult': finalResult,
          'startedAtEpochMs': startedAtEpochMs,
          'endedAtEpochMs': endedAtEpochMs,
        }),
      );
      if (res.statusCode != 201) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
