import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:call_tracker/data/api_service.dart';
import 'package:call_tracker/data/auth_service.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/ui/views/login/login_view.dart';

const _agent = Agent(id: 'a1', name: 'Sara', email: 's@institute.dz');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.signedIn.value = null;
    AuthService.endedReason = null;
  });

  group('session state', () {
    test('restore picks up a stored session', () async {
      SharedPreferences.setMockInitialValues({
        'agent_session': '{"id":"a1","name":"Sara","email":"s@institute.dz"}',
      });

      await AuthService.restore();

      expect(AuthService.signedIn.value?.id, 'a1');
    });

    test('signing out clears the session and the token', () async {
      SharedPreferences.setMockInitialValues({
        'agent_session': '{"id":"a1","name":"Sara","email":"s@institute.dz"}',
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
        'agent_session': '{"id":"a1","name":"Sara","email":"s@institute.dz"}',
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
}
