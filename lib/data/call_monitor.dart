import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/native_call_service.dart';

/// A call that was placed but not yet reconciled against the call log.
/// Persisted to disk so a call survives the app process being killed while
/// the native dialer owns the screen.
class PendingCall {
  const PendingCall({
    required this.studentId,
    required this.number,
    required this.startedAtEpochMs,
    required this.reason,
  });

  final String studentId;
  final String number;
  final int startedAtEpochMs;
  final CallReason reason;

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'number': number,
        'startedAtEpochMs': startedAtEpochMs,
        'reason': reason.name,
      };

  factory PendingCall.fromJson(Map<String, dynamic> json) => PendingCall(
        studentId: json['studentId'] as String,
        number: json['number'] as String,
        startedAtEpochMs: json['startedAtEpochMs'] as int,
        reason: CallReason.values.byName(json['reason'] as String),
      );
}

class CallMonitor {
  static const _prefsKey = 'pending_call';

  static Future<void> savePending(PendingCall call) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(call.toJson()));
  }

  static Future<PendingCall?> readPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return null;
    return PendingCall.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// Cross-checks [call] against the device's call log and clears it from
  /// the pending store. This is the only source of truth for what really
  /// happened on the line — not anything the app itself observed.
  static Future<CallVerification> reconcile(PendingCall call) async {
    final since = DateTime.fromMillisecondsSinceEpoch(call.startedAtEpochMs);
    final result = await NativeCallService.queryCallSince(call.number, since);
    await clearPending();

    if (!result.found) {
      return const CallVerification(
        reallyDialed: false,
        talkDurationSeconds: 0,
        suspicious: true,
        note: 'No outgoing call was detected on this device for this number.',
      );
    }

    final duration = result.durationSeconds ?? 0;
    if (duration <= 0) {
      return const CallVerification(
        reallyDialed: true,
        talkDurationSeconds: 0,
        suspicious: true,
        note: 'Call was placed but never answered (0s talk time).',
      );
    }

    return CallVerification(
      reallyDialed: true,
      talkDurationSeconds: duration,
      suspicious: false,
      note: 'Call connected and lasted ${duration}s.',
    );
  }
}
