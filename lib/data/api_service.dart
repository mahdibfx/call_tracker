import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:call_tracker/data/models.dart';

class ApiService {
  static const _baseUrl = 'https://backendelameed.onrender.com/api';
  static const _tokenKey = 'jwt_token';

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

  /// GET /students — null when the request failed, so a refresh on a flaky
  /// connection can leave the list it already has alone instead of blanking it.
  static Future<List<Student>?> getStudents() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/students'),
        headers: await _authHeaders(),
      );
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>;
      // ponytail: defensive dedupe — the backend has been seen returning the
      // same student id twice; drop the repeat here rather than in every
      // screen that filters this roster. Remove once the API is confirmed clean.
      final seenIds = <String>{};
      final students = <Student>[];
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final student = Student(
          id: m['id'].toString(),
          name: m['name'] as String,
          phone: m['phone'] as String,
          level: m['level'] as String,
          parentName: m['parentName'] as String,
          studentId: m['studentId'] as String,
        );
        if (seenIds.add(student.id)) students.add(student);
      }
      return students;
    } catch (_) {
      return null;
    }
  }

  /// GET /groups — null when the request failed, see [getStudents].
  static Future<List<Group>?> getGroups() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/groups'),
        headers: await _authHeaders(),
      );
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return Group(
          name: m['name'] as String,
          studentCount: m['studentCount'] as int,
          studentIds: (m['studentIds'] as List<dynamic>)
              .map((id) => id.toString())
              .toList(),
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  /// POST /calls
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
    required bool isFinal,
  }) async {
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
        'isFinal': isFinal,
      }),
    );

    if (res.statusCode != 201) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
