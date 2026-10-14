import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:call_tracker/data/models.dart';

/// Why a sign-in attempt failed. The backend distinguishes these, so the
/// agent should see the real reason rather than "wrong password" for
/// everything — a blocked account and a dead connection look nothing alike.
enum LoginFailure {
  invalidCredentials('Incorrect email or password.'),
  blocked('This account has been blocked. Contact your supervisor.'),
  network("Can't reach the server — check your connection and try again."),
  server('Something went wrong. Please try again in a moment.');

  const LoginFailure(this.message);
  final String message;
}

class ApiService {
  static const _host = 'https://backendelameed.onrender.com';

  /// Called when the backend rejects our token — it has expired, or the agent
  /// was blocked since it was issued (the backend re-checks on every request).
  /// Wired up in `main.dart`; without it an expired session would leave every
  /// screen silently stuck on stale data with no way back to the login screen.
  static Future<void> Function()? onUnauthorized;

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

  /// True when the response means our token is no longer good. Announces the
  /// dead session so the app can send the agent back to the login screen.
  ///
  /// Only for authenticated calls — a 401 from [login] means a bad password,
  /// not a dead session, and must not trigger this.
  static Future<bool> _isUnauthorized(http.Response res) async {
    if (res.statusCode != 401) return false;
    await onUnauthorized?.call();
    return true;
  }

  /// POST /auth/login. Returns the agent on success, otherwise why it failed.
  static Future<({Agent? agent, LoginFailure? failure})> login(
    String email,
    String password,
  ) async {
    final http.Response res;
    try {
      res = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
    } catch (_) {
      return (agent: null, failure: LoginFailure.network);
    }

    if (res.statusCode == 401) {
      return (agent: null, failure: LoginFailure.invalidCredentials);
    }
    if (res.statusCode == 403) return (agent: null, failure: LoginFailure.blocked);
    if (res.statusCode != 200) return (agent: null, failure: LoginFailure.server);

    try {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      await _saveToken(json['token'] as String);
      final agentJson = json['agent'] as Map<String, dynamic>;
      return (
        agent: Agent(
          id: agentJson['id'].toString(),
          name: agentJson['name'] as String,
          email: agentJson['email'] as String,
        ),
        failure: null,
      );
    } catch (_) {
      return (agent: null, failure: LoginFailure.server);
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
      if (await _isUnauthorized(res)) return null;
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
      if (await _isUnauthorized(res)) return null;
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
      if (await _isUnauthorized(res)) return null;
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final inner = body['data'] as Map<String, dynamic>?;
      if (inner == null) return null;
      return Paged.fromJson(inner, Student.fromJson);
    } catch (_) {
      return null;
    }
  }

  /// GET /ManagementStudent/student-calls/:id — every call ever made to one
  /// student, newest first, unpaginated. Null on failure.
  ///
  /// Another root-level envelope route, like [getGroupStudents]. Note the
  /// backend currently refuses call-tracker agent tokens here with 403, so
  /// this returns null until that guard accepts them.
  static Future<List<StudentCall>?> getStudentCalls(String studentId) async {
    try {
      final res = await http.get(
        Uri.parse('$_host/ManagementStudent/student-calls/$studentId'),
        headers: await _authHeaders(),
      );
      if (await _isUnauthorized(res)) return null;
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['data'] as List<dynamic>?;
      if (list == null) return null;
      return list
          .map((e) => StudentCall.fromJson(e as Map<String, dynamic>))
          .whereType<StudentCall>()
          .toList();
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
      if (await _isUnauthorized(res)) return null;
      if (res.statusCode != 201) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
