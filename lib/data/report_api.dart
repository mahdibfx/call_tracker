import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:call_tracker/data/api_service.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/report_models.dart';

/// The reports side of the API. Root-level routes, so every response is
/// wrapped in the `{success, message, data}` envelope.
///
/// Shares `ApiService`'s token and its contract: a getter returns null when
/// the request failed, so a screen can keep what it already had instead of
/// blanking on a flaky connection.
class ReportApi {
  static const _host = 'https://backendelameed.onrender.com';

  /// Photos over this are refused by the backend. Checked before upload: a
  /// 10MB POST that fails after two minutes on mobile data is a bad way to
  /// find out.
  static const maxImageBytes = 10 * 1024 * 1024;

  /// GET /report-categories — the pickers' source. [role] narrows to one
  /// role's categories; omit it to get all, which is what the compose screen
  /// wants so a cleaner can still report a broken projector.
  static Future<List<ReportCategory>?> getCategories({StaffRole? role}) async {
    try {
      final uri = Uri.parse('$_host/report-categories').replace(
        queryParameters: {if (role != null) 'role': role.code},
      );
      final res = await http.get(uri, headers: await ApiService.authHeaders());
      if (await ApiService.isUnauthorized(res)) return null;
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['data'] as List<dynamic>?;
      if (list == null) return null;
      return list
          .map((e) => ReportCategory.fromJson(e as Map<String, dynamic>))
          .whereType<ReportCategory>()
          .where((c) => c.isActive)
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// GET /rooms — 28 of them, so no paging or search needed.
  static Future<List<Room>?> getRooms() async {
    try {
      final res = await http.get(
        Uri.parse('$_host/rooms'),
        headers: await ApiService.authHeaders(),
      );
      if (await ApiService.isUnauthorized(res)) return null;
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['data'] as List<dynamic>?;
      if (list == null) return null;
      return list
          .map((e) => Room.fromJson(e as Map<String, dynamic>))
          .whereType<Room>()
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// GET /reports — newest first.
  ///
  /// The backend already scopes what each role can see (own-role categories
  /// plus their own submissions; everything for an admin), so no user filter
  /// is sent and the list is never filtered again on the device.
  ///
  /// Note the envelope nests twice and reports its page flat, hence
  /// [Paged.fromFlat] rather than [Paged.fromJson].
  static Future<Paged<Report>?> getReports({
    List<ReportState> states = const [],
    int? categoryId,
    int? roomId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final uri = Uri.parse('$_host/reports').replace(queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (states.isNotEmpty) 'state': states.map((s) => s.code).join(','),
        if (categoryId != null) 'category_id': '$categoryId',
        if (roomId != null) 'room_id': '$roomId',
      });
      final res = await http.get(uri, headers: await ApiService.authHeaders());
      if (await ApiService.isUnauthorized(res)) return null;
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final inner = body['data'] as Map<String, dynamic>?;
      if (inner == null) return null;
      // A row we cannot even read an id from is dropped rather than rendered
      // as a blank card.
      final reports = (inner['data'] as List<dynamic>? ?? [])
          .map((e) => Report.fromJson(e as Map<String, dynamic>))
          .whereType<Report>()
          .toList();
      return Paged.fromFlatItems(inner, reports);
    } catch (_) {
      return null;
    }
  }

  /// GET /reports/:id — re-read one report after acting on it.
  static Future<Report?> getReport(int id) async {
    try {
      final res = await http.get(
        Uri.parse('$_host/reports/$id'),
        headers: await ApiService.authHeaders(),
      );
      if (await ApiService.isUnauthorized(res)) return null;
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      return data == null ? null : Report.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// POST /reports — file a new one. The backend needs a description or a
  /// photo; both is better.
  ///
  /// Returns the created report, or null. [ReportFailure] is not modelled
  /// because the compose screen only distinguishes "worked" from "did not".
  static Future<Report?> createReport({
    int? categoryId,
    String? description,
    String? imagePath,
    int? roomId,
  }) async {
    if (imagePath != null && await _tooLarge(imagePath)) return null;
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$_host/reports'))
        // Bearer only: MultipartRequest sets its own Content-Type carrying the
        // part boundary, and a JSON one would make the body unreadable.
        ..headers.addAll(await ApiService.bearerOnly())
        ..fields.addAll({
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          if (categoryId != null) 'category_id': '$categoryId',
          if (roomId != null) 'room_id': '$roomId',
        });
      if (imagePath != null) {
        req.files.add(await http.MultipartFile.fromPath('image', imagePath));
      }
      final res = await http.Response.fromStream(await req.send());
      if (await ApiService.isUnauthorized(res)) return null;
      if (res.statusCode != 201 && res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      return data == null ? null : Report.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// PATCH /reports/:id/state — move a report along.
  ///
  /// [confirmationDescription] and [confirmationImagePath] are only accepted
  /// by the backend when [state] closes the report, and are dropped otherwise.
  /// Sends JSON when there is no photo, multipart when there is.
  static Future<Report?> setState(
    int id, {
    required ReportState state,
    String? note,
    String? confirmationDescription,
    String? confirmationImagePath,
  }) async {
    final closing = state.isClosing;
    final imagePath = closing ? confirmationImagePath : null;
    if (imagePath != null && await _tooLarge(imagePath)) return null;

    try {
      final uri = Uri.parse('$_host/reports/$id/state');
      final http.Response res;
      if (imagePath == null) {
        res = await http.patch(
          uri,
          headers: await ApiService.authHeaders(),
          body: jsonEncode({
            'state': state.code,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
            if (closing &&
                confirmationDescription != null &&
                confirmationDescription.trim().isNotEmpty)
              'confirmation_description': confirmationDescription.trim(),
          }),
        );
      } else {
        final req = http.MultipartRequest('PATCH', uri)
          ..headers.addAll(await ApiService.bearerOnly())
          ..fields.addAll({
            'state': state.code,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
            if (confirmationDescription != null &&
                confirmationDescription.trim().isNotEmpty)
              'confirmation_description': confirmationDescription.trim(),
          })
          ..files.add(
            await http.MultipartFile.fromPath('confirmation_image', imagePath),
          );
        res = await http.Response.fromStream(await req.send());
      }

      if (await ApiService.isUnauthorized(res)) return null;
      // A 403 here means this role does not handle the category. Deliberately
      // not routed through the unauthorized path: that would sign the user out
      // for tapping something they simply are not responsible for.
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      return data == null ? null : Report.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// POST / DELETE /reports/:id/confirm — an admin's sign-off.
  ///
  /// False on failure, including the 409 the backend returns when the report
  /// is already in the state being asked for.
  static Future<bool> setConfirmed(int id, bool confirmed) async {
    try {
      final uri = Uri.parse('$_host/reports/$id/confirm');
      final headers = await ApiService.authHeaders();
      final res = confirmed
          ? await http.post(uri, headers: headers)
          : await http.delete(uri, headers: headers);
      if (await ApiService.isUnauthorized(res)) return false;
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// POST /devices — tell the backend where to send this user's pushes.
  static Future<bool> registerDevice(String token, {String platform = 'android'}) async {
    try {
      final res = await http.post(
        Uri.parse('$_host/devices'),
        headers: await ApiService.authHeaders(),
        body: jsonEncode({'token': token, 'platform': platform}),
      );
      if (await ApiService.isUnauthorized(res)) return false;
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /devices — called on sign-out, so a shared handset stops showing
  /// notifications meant for whoever used it last.
  static Future<bool> unregisterDevice(String token) async {
    try {
      final res = await http.delete(
        Uri.parse('$_host/devices'),
        headers: await ApiService.authHeaders(),
        body: jsonEncode({'token': token}),
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _tooLarge(String path) async {
    try {
      return await File(path).length() > maxImageBytes;
    } catch (_) {
      return false; // can't tell; let the server decide
    }
  }
}
