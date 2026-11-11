import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:call_tracker/data/api_service.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/task_models.dart';

/// `GET /tasks`, `GET /tasks/:id` and the one write an agent does: recording
/// what happened on a student's line.
///
/// Root-level routes, so the `{success, message, data}` envelope applies. The
/// list nests once more and — unlike `/reports` — pages with a proper
/// `pagination` object, so this is `Paged.fromJson` territory.
class TaskApi {
  static const _host = 'https://backendelameed.onrender.com';

  /// What a list fetch returns: the page, plus the counts behind the tabs.
  /// They are fetched together because the backend computes them together.
  ///
  /// Null, as everywhere else in this app, means the request failed — the
  /// screen keeps what it had rather than blanking.
  static Future<({Paged<Task> page, TaskCounts counts})?> getTasks({
    List<TaskStatus> statuses = const [],
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final uri = Uri.parse('$_host/tasks').replace(queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (statuses.isNotEmpty) 'status': statuses.map((s) => s.code).join(','),
      });
      final res = await http.get(uri, headers: await ApiService.authHeaders());
      if (await ApiService.isUnauthorized(res)) return null;
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final inner = body['data'] as Map<String, dynamic>?;
      if (inner == null) return null;
      final tasks = (inner['data'] as List<dynamic>? ?? [])
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .whereType<Task>()
          .toList();
      return (
        page: Paged.fromJsonItems<Task>(inner, tasks),
        counts: TaskCounts.fromJson(inner['counts'] as Map<String, dynamic>?),
      );
    } catch (_) {
      return null;
    }
  }

  /// GET /tasks/:id — the same task with its students.
  static Future<Task?> getTask(int id) async {
    try {
      final res = await http.get(
        Uri.parse('$_host/tasks/$id'),
        headers: await ApiService.authHeaders(),
      );
      if (await ApiService.isUnauthorized(res)) return null;
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      return data == null ? null : Task.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// PUT /tasks/:id/targets/:targetId — what happened on one student's line.
  ///
  /// The task itself follows along at the backend: it moves to `in_progress`
  /// at the first result and to `done` once nobody is pending, so the agent
  /// never sets a task's status and this app never calls
  /// `PUT /tasks/:id/status`.
  ///
  /// [callId] links the call-tracker call that did it, when there is one.
  ///
  /// Returns the server's message on failure, null on success — a result that
  /// silently fails to save would have the agent ring the same student twice.
  static Future<String?> setTargetResult(
    int taskId,
    int targetId, {
    required TargetStatus status,
    String? note,
    int? callId,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$_host/tasks/$taskId/targets/$targetId'),
        headers: await ApiService.authHeaders(),
        body: jsonEncode({
          'status': status.code,
          if (note != null && note.trim().isNotEmpty) 'result_note': note.trim(),
          'call_id': ?callId,
        }),
      );
      if (await ApiService.isUnauthorized(res)) {
        return 'Your session ended. Sign in again.';
      }
      if (res.statusCode == 200) return null;
      // 409 is the documented "this task was cancelled" — worth passing on
      // verbatim, because the agent should stop working it.
      return _serverMessage(res);
    } catch (_) {
      return "Couldn't reach the server. Check your connection.";
    }
  }

  static String _serverMessage(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final message = (body['message'] ?? body['error'])?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    } catch (_) {
      // Not JSON.
    }
    return "Couldn't save that result (${res.statusCode}).";
  }
}
