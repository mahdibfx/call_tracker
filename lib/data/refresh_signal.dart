import 'package:flutter/foundation.dart';

/// Tells every live screen to re-fetch its data.
///
/// The tabs live inside an [IndexedStack], so each tab's `initState` runs once
/// per session and never again. Without this signal a student or group added
/// on the backend only appeared after killing and reopening the app.
///
/// Fired when the agent switches tab, when the app comes back to the
/// foreground, and after a call is submitted.
class RefreshSignal {
  RefreshSignal._();

  static final ValueNotifier<int> _tick = ValueNotifier(0);

  static Listenable get listenable => _tick;

  static void fire() => _tick.value++;
}
