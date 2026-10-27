import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:call_tracker/data/api_service.dart';
import 'package:call_tracker/data/auth_service.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/ui/views/login/login_view.dart';

const _agent = Agent(
  id: 'a1',
  name: 'Sara',
  email: 's@institute.dz',
  role: StaffRole.teamOnsite,
  agentId: '7',
);

/// A session in the current storage format. Restoring one of these needs no
/// backend round-trip, so these tests stay offline.
String _storedSession({
  String id = 'a1',
  String role = 'team onsite',
  String? agentId = '7',
}) =>
    jsonEncode({
      'id': id,
      'name': 'Sara',
      'email': 's@institute.dz',
      'role': role,
      'agent_id': agentId,
      'v': 2,
    });

/// What the shipped pre-role build wrote: no role, no version.
const _legacySession = '{"id":"a1","name":"Sara","email":"s@institute.dz"}';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.signedIn.value = null;
    AuthService.endedReason = null;
  });

  group('session state', () {
    test('restore picks up a stored session', () async {
      SharedPreferences.setMockInitialValues({'agent_session': _storedSession()});

      await AuthService.restore();

      expect(AuthService.signedIn.value?.id, 'a1');
      expect(AuthService.signedIn.value?.role, StaffRole.teamOnsite);
      expect(AuthService.signedIn.value?.canSeeCalls, isTrue);
    });

    test('signing out clears the session and the token', () async {
      SharedPreferences.setMockInitialValues({
        'agent_session': _storedSession(),
        'jwt_token': 'stored-token',
      });
      await AuthService.restore();

      await AuthService.signOut();

      expect(AuthService.signedIn.value, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('agent_session'), isNull);
      expect(prefs.getString('jwt_token'), isNull, reason: 'token must go too');
    });

    test('a rejected token ends the session and says why', () async {
      SharedPreferences.setMockInitialValues({
        'agent_session': _storedSession(),
        'jwt_token': 'expired-token',
      });
      await AuthService.restore();

      final expired = await AuthService.expire();

      expect(expired, isTrue);
      expect(AuthService.signedIn.value, isNull);
      expect(AuthService.endedReason, isNotNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('jwt_token'), isNull);
    });

    test('concurrent 401s only end the session once', () async {
      AuthService.signedIn.value = _agent;

      expect(await AuthService.expire(), isTrue);
      // Several screens refreshing at once must not bounce the agent twice.
      expect(await AuthService.expire(), isFalse);
    });
  });

  group('upgrading an existing install', () {
    // The shipped build stored {id,name,email} and read it back with hard
    // casts, inside a restore() that main() awaits before runApp. Anything
    // that throws here leaves the app with no first frame at all.
    test('a pre-role session does not throw and does not strand the app', () async {
      SharedPreferences.setMockInitialValues({'agent_session': _legacySession});

      await AuthService.restore();

      // No token to complete it with and no backend in a unit test, so the
      // session cannot be made routable — it must end cleanly, with a reason,
      // rather than sitting on the loading state forever.
      expect(AuthService.signedIn.value, isNull);
      expect(AuthService.endedReason, isNotNull);
    });

    test('a corrupt session is discarded instead of throwing', () async {
      for (final blob in ['not json at all', '{"id":', '[]', '{"id":{"nested":1}}']) {
        SharedPreferences.setMockInitialValues({'agent_session': blob});
        AuthService.signedIn.value = null;

        await AuthService.restore();

        expect(AuthService.signedIn.value, isNull, reason: 'blob: $blob');
      }
    });

    test('a corrupt session is wiped from storage, not left to fail again', () async {
      SharedPreferences.setMockInitialValues({'agent_session': 'not json at all'});

      await AuthService.currentAgent();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('agent_session'), isNull);
    });

    test('a non-agent session restores without the calls area', () async {
      SharedPreferences.setMockInitialValues({
        'agent_session': _storedSession(role: 'cleaner', agentId: null),
      });

      await AuthService.restore();

      expect(AuthService.signedIn.value?.role, StaffRole.cleaner);
      expect(AuthService.signedIn.value?.canSeeCalls, isFalse);
    });
  });

  group('login screen', () {
    testWidgets('explains why a session ended, once', (tester) async {
      AuthService.endedReason = 'Your session ended. Please sign in again.';

      await tester.pumpWidget(const MaterialApp(home: LoginView()));
      await tester.pump();

      expect(find.text('Your session ended. Please sign in again.'), findsOneWidget);
      expect(AuthService.endedReason, isNull, reason: 'cleared after showing');
    });

    testWidgets('does not blame the password for other failures', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginView()));
      await tester.pump();

      expect(find.textContaining('Incorrect email or password'), findsNothing);
    });
  });

  test('each login failure carries its own message', () {
    final messages = LoginFailure.values.map((f) => f.message).toSet();

    expect(
      messages.length,
      LoginFailure.values.length,
      reason: 'a blocked account and a dead connection must not read alike',
    );
    expect(LoginFailure.blocked.message, contains('blocked'));
    expect(LoginFailure.network.message, contains('connection'));
  });

  test('a teacher is told which app to use instead', () {
    // Teachers have their own app; signing in here must not look like a
    // password problem.
    expect(LoginFailure.teacherAccount.message, contains('Teachers'));
    expect(LoginFailure.teacherAccount.message.toLowerCase(), contains('app'));
    expect(LoginFailure.unsupportedRole.message, isNotEmpty);
  });
}
