import 'package:flutter/services.dart';

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
      final ok = await _channel.invokeMethod<bool>('placeCall', {'number': number});
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<CallLogResult> queryCallSince(String number, DateTime since) async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('queryCallSince', {
        'number': number,
        'sinceEpochMs': since.millisecondsSinceEpoch,
      });
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
}
