import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:call_tracker/firebase_options.dart';
import 'package:call_tracker/data/refresh_signal.dart';
import 'package:call_tracker/data/report_api.dart';

/// Server-sent pushes: a new report for your role, or a decision on one you
/// filed. Without them a broken AC sits unseen until somebody happens to open
/// the app, which is most of the reason a cleaner would install this at all.
///
/// Firebase project `elameed-system` — the same one the Teachers App uses, as
/// the `com.elameed.staff` Android app. If Firebase fails to start, every call
/// here becomes a no-op and the rest of the app carries on working.
///
/// The backend sends `notification` payloads with a title and body, so Android
/// draws the tray entry itself while the app is backgrounded or killed. Nothing
/// here has to render a notification, which is why there is no local-
/// notifications plugin.
class PushService {
  PushService._();

  static bool _available = false;
  static String? _token;

  /// What a tapped notification wants us to open, parked until the navigator
  /// exists. A cold start delivers the tap before `runApp`, so there is no
  /// context to push onto yet.
  static int? _pendingReportId;

  /// Called once from `main()`, before `runApp`.
  static Future<void> start() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
      _available = true;
    } catch (e) {
      debugPrint('[Push] Firebase did not start — pushes are off ($e)');
      return;
    }
    // In the foreground Android suppresses the tray entry, so the useful thing
    // is to make the open screen current rather than to draw a banner.
    FirebaseMessaging.onMessage.listen((_) => RefreshSignal.fire());
    FirebaseMessaging.onMessageOpenedApp.listen(_openFromTap);
    FirebaseMessaging.instance.onTokenRefresh.listen(_sendToken);

    // The app was launched *by* a notification tap.
    final launchedBy = await FirebaseMessaging.instance.getInitialMessage();
    if (launchedBy != null) _openFromTap(launchedBy);
  }

  /// After signing in, and on every start that restores a session: ask for
  /// permission (Android 13+ needs it) and hand the backend this device.
  static Future<void> register() async {
    if (!_available) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _sendToken(token);
    } catch (e) {
      debugPrint('[Push] register failed: $e');
    }
  }

  /// On sign-out, so a shared handset stops showing the last user's reports.
  /// Call this *before* the session is cleared — unregistering needs the token
  /// that is about to be thrown away.
  static Future<void> unregister() async {
    final token = _token;
    _token = null;
    if (!_available || token == null) return;
    await ReportApi.unregisterDevice(token);
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[Push] deleteToken failed: $e');
    }
  }

  static Future<void> _sendToken(String token) async {
    _token = token;
    await ReportApi.registerDevice(token);
  }

  /// Every value in an FCM `data` payload arrives as a string, so the id is
  /// parsed rather than cast.
  static void _openFromTap(RemoteMessage message) {
    final id = int.tryParse('${message.data['report_id']}');
    if (id == null) return;
    _pendingReportId = id;
    _drainPending?.call();
  }

  /// Set by the shell once it can navigate. Kept as a callback so this file
  /// stays free of widgets and can be unit-tested.
  static VoidCallback? _drainPending;

  static set onReportTapped(VoidCallback? handler) {
    _drainPending = handler;
    if (handler != null && _pendingReportId != null) handler();
  }

  /// Consumes the parked report id, if there is one.
  static int? takePendingReportId() {
    final id = _pendingReportId;
    _pendingReportId = null;
    return id;
  }
}
