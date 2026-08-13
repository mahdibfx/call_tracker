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
    required this.studentName,
    required this.parentName,
    required this.number,
    required this.startedAtEpochMs,
    required this.reason,
  });

  final String studentId;
  final String studentName;
  final String parentName;
  final String number;
  final int startedAtEpochMs;
  final CallReason reason;

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'studentName': studentName,
        'parentName': parentName,
        'number': number,
        'startedAtEpochMs': startedAtEpochMs,
        'reason': reason.name,
      };

  factory PendingCall.fromJson(Map<String, dynamic> json) => PendingCall(
        studentId: json['studentId'] as String,
        studentName: json['studentName'] as String? ?? '',
        parentName: json['parentName'] as String? ?? '',
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

  // ponytail: real-world ring/setup timing, in three bands, tunable if real-device
  // testing shows false positives/negatives:
  //  - under earlyHangupThresholdSeconds: dial setup alone takes this long, so the
  //    call couldn't possibly have rung yet — confidently "hung up before it rang".
  //  - under quickEndThresholdSeconds: might have rung once briefly — genuinely
  //    ambiguous between a fast decline and an early hangup, can't tell which
  //    without becoming the device's default dialer (see DisconnectCause discussion).
  //  - at or above quickEndThresholdSeconds: multiple ring cycles elapsed —
  //    a genuine unanswered/ring-out call.
  // ponytail: bumped from 3/8 — Infinix (and some Tecno/Samsung) dialers take
  // 3-4s of setup before the call goes off-hook, inflating ringSessionSeconds.
  static const earlyHangupThresholdSeconds = 6;
  static const quickEndThresholdSeconds = 12;

  /// Cross-checks [call] against the device's call log and clears it from
  /// the pending store. This is the only source of truth for what really
  /// happened on the line — not anything the app itself observed.
  ///
  /// How long to wait for the dialer to actually go off-hook after the intent
  /// fires. Infinix/Tecno dialers take 3-4s; 12s is slack on top of that.
  static const _dialGraceSeconds = 12;

  /// Upper bound on a single call, so a missed CALL_ENDED can't hang reconcile.
  static const _maxCallMinutes = 60;

  /// Blocks until the device's telephony state is idle, so the CallLog entry
  /// (written only on disconnect) actually exists by the time we read it.
  /// Returns how long the call was observed active, or null if it never started.
  static Future<int?> _awaitCallEnd() async {
    var waited = 0;
    while (!await NativeCallService.isCallActive()) {
      if (waited >= _dialGraceSeconds) return null; // never went off-hook
      await Future.delayed(const Duration(seconds: 1));
      waited++;
    }
    final activeSince = DateTime.now();
    for (var i = 0; i < _maxCallMinutes * 60; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!await NativeCallService.isCallActive()) break;
    }
    return DateTime.now().difference(activeSince).inSeconds;
  }

  /// [callStartedAt] is when phone_state observed the call go active, if it did.
  /// Ignored when the telephony state itself gives a better measurement.
  static Future<CallVerification> reconcile(PendingCall call, {DateTime? callStartedAt}) async {
    final since = DateTime.fromMillisecondsSinceEpoch(call.startedAtEpochMs);

    // The CallLog row does not exist until the call disconnects — reading it
    // mid-call is what produced false "no outgoing call detected" flags on
    // answered and long-ringing calls. Wait the call out first.
    final observedSeconds = await _awaitCallEnd();
    final ringSessionSeconds = observedSeconds ??
        (callStartedAt != null ? DateTime.now().difference(callStartedAt).inSeconds : null);

    // Small settle window, then a couple of retries — the row is written at
    // disconnect but not always synchronously.
    await Future.delayed(const Duration(seconds: 2));
    CallLogResult result = await NativeCallService.queryCallSince(call.number, since);
    if (!result.found) {
      for (final delay in [2, 3]) {
        await Future.delayed(Duration(seconds: delay));
        result = await NativeCallService.queryCallSince(call.number, since);
        if (result.found) break;
      }
    }
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
      if (ringSessionSeconds != null && ringSessionSeconds < earlyHangupThresholdSeconds) {
        return CallVerification(
          reallyDialed: true,
          talkDurationSeconds: 0,
          suspicious: true,
          likelyHungUpEarly: true,
          ringSessionSeconds: ringSessionSeconds,
          note: 'Call was ended after only ${ringSessionSeconds}s — too quick to have actually rung, likely hung up immediately.',
        );
      }
      if (ringSessionSeconds != null && ringSessionSeconds < quickEndThresholdSeconds) {
        return CallVerification(
          reallyDialed: true,
          talkDurationSeconds: 0,
          suspicious: true,
          endedQuickly: true,
          ringSessionSeconds: ringSessionSeconds,
          note: "Call ended quickly after ${ringSessionSeconds}s — could be a decline or an early hangup, can't tell which.",
        );
      }
      return CallVerification(
        reallyDialed: true,
        talkDurationSeconds: 0,
        suspicious: true,
        ringSessionSeconds: ringSessionSeconds,
        note: ringSessionSeconds != null
            ? 'Call rang for ${ringSessionSeconds}s but was not answered.'
            : 'Call was placed but never answered (0s talk time).',
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
