import 'package:flutter/services.dart';
import 'package:call_tracker/data/models.dart';

/// A call somebody made *to* the agent, already finished, as the native
/// receiver recorded it. Produced whether or not the app was running at the
/// time — that is the whole point of it living in native code.
class IncomingCallEvent {
  const IncomingCallEvent({
    required this.id,
    required this.number,
    required this.startedAtEpochMs,
    required this.endedAtEpochMs,
    required this.answered,
    required this.talkDurationSeconds,
    required this.fromCallLog,
  });

  final String id;
  final String number;
  final int startedAtEpochMs;
  final int endedAtEpochMs;
  final bool answered;
  final int talkDurationSeconds;

  /// False when the call log couldn't be read and the numbers came from the
  /// app's own observation of the ring instead.
  final bool fromCallLog;

  static IncomingCallEvent? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final number = raw['number'] as String? ?? '';
    if (number.isEmpty) return null;
    return IncomingCallEvent(
      id: raw['id'] as String? ?? '',
      number: number,
      startedAtEpochMs: (raw['startedAtEpochMs'] as num?)?.toInt() ?? 0,
      endedAtEpochMs: (raw['endedAtEpochMs'] as num?)?.toInt() ?? 0,
      answered: raw['answered'] as bool? ?? false,
      talkDurationSeconds: (raw['talkDurationSeconds'] as num?)?.toInt() ?? 0,
      fromCallLog: raw['source'] == 'call_log',
    );
  }
}

/// The OS's own record of the most recent outgoing call to a number.
/// This is ground truth: it comes from the Android call log, not from
/// anything our app claims happened.
class CallLogResult {
  const CallLogResult({required this.found, this.durationSeconds});

  final bool found;
  final int? durationSeconds;
}

/// Bridges to Android's native dialer (direct ACTION_CALL) and call log.
/// Android-only: on other platforms every call resolves to a "not found" result.
class NativeCallService {
  static const _channel = MethodChannel('call_tracker/native_call');

  static Future<bool> placeCall(String number) async {
    try {
      final ok = await _channel.invokeMethod<bool>('placeCall', {
        'number': number,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// True while the device is ringing or in a call. Android writes the call-log
  /// entry only on disconnect, so this gates when reconciling is meaningful.
  /// Defaults to false (idle) on any failure so reconcile can never hang.
  static Future<bool> isCallActive() async {
    try {
      return await _channel.invokeMethod<bool>('isCallActive') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<CallLogResult> queryCallSince(
    String number,
    DateTime since,
  ) async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>(
        'queryCallSince',
        {'number': number, 'sinceEpochMs': since.millisecondsSinceEpoch},
      );
      if (map == null) return const CallLogResult(found: false);
      return CallLogResult(
        found: map['found'] as bool? ?? false,
        durationSeconds: map['durationSeconds'] as int?,
      );
    } on PlatformException {
      return const CallLogResult(found: false);
    } on MissingPluginException {
      return const CallLogResult(found: false);
    }
  }

  /// Takes every finished incoming call the native receiver has queued and
  /// empties the queue. Destructive by design: whatever this returns is the
  /// app's responsibility from here on.
  static Future<List<IncomingCallEvent>> drainIncomingCalls() async {
    try {
      final raw = await _channel.invokeListMethod<Object?>('drainIncomingCalls');
      if (raw == null) return const [];
      return raw
          .map(IncomingCallEvent.tryParse)
          .whereType<IncomingCallEvent>()
          .toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Pushes the roster into native storage so the receiver can name the caller
  /// with no network and no Flutter engine.
  static Future<void> cacheStudents(List<Student> students) async {
    try {
      await _channel.invokeMethod<bool>('cacheStudents', {
        'students': students
            .map((s) => {
                  'id': s.id,
                  'name': s.name,
                  'phone': s.phone,
                  'level': s.level,
                  'parentName': s.parentName,
                  'studentId': s.studentId,
                })
            .toList(),
      });
    } on PlatformException {
      // Best-effort cache; a miss only costs a backend lookup later.
    } on MissingPluginException {
      // Not Android.
    }
  }

  /// The roster as the receiver last saw it — lets a cold start resolve a
  /// caller before the students list has come back from the network.
  static Future<List<Student>> cachedStudents() async {
    try {
      final raw = await _channel.invokeListMethod<Object?>('cachedStudents');
      if (raw == null) return const [];
      return raw.whereType<Map>().map((m) {
        return Student(
          id: m['id'] as String? ?? '',
          name: m['name'] as String? ?? '',
          phone: m['phone'] as String? ?? '',
          level: m['level'] as String? ?? '',
          parentName: m['parentName'] as String? ?? '',
          studentId: m['studentId'] as String? ?? '',
        );
      }).toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Fires when a call the agent received has just ended while the app is
  /// alive, so the summary screen can appear without waiting for a resume.
  static void setIncomingCallListener(void Function()? onEnded) {
    if (onEnded == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onIncomingCallEnded') onEnded();
      return null;
    });
  }
}
