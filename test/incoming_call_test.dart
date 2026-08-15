import 'package:flutter_test/flutter_test.dart';
import 'package:call_tracker/data/incoming_call_service.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/test_mode.dart';

/// Pins the incoming-call side: how a caller's number is matched to a student,
/// and how a call the agent *received* is described and judged differently from
/// one he placed.
CallRecord incoming({
  required int talkDurationSeconds,
  CallOutcome? outcome,
}) => CallRecord(
  studentId: '1',
  studentName: 'Test Student',
  reason: CallReason.returnedOurCall,
  direction: CallDirection.incoming,
  outcome: outcome,
  reallyDialed: true,
  talkDurationSeconds: talkDurationSeconds,
  timestampEpochMs: 0,
);

void main() {
  // drain() reaches for the native queue and the cached roster; with no
  // handlers registered both fail cleanly, which is what a test wants.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('caller matching', () {
    test('the same number in three formats is one student', () {
      // What the backend stores, what the network reports, and what a human
      // typed with spaces — all the same parent.
      const key = '612345678';
      expect(IncomingCallService.phoneKey('0612345678'), key);
      expect(IncomingCallService.phoneKey('+212612345678'), key);
      expect(IncomingCallService.phoneKey('+212 612-345-678'), key);
      expect(IncomingCallService.phoneKey('00212612345678'), key);
    });

    test('two genuinely different numbers do not collide', () {
      expect(
        IncomingCallService.phoneKey('0612345678'),
        isNot(IncomingCallService.phoneKey('0698765432')),
      );
    });

    test('a withheld or empty number yields no key to match on', () {
      expect(IncomingCallService.phoneKey(''), isEmpty);
      expect(IncomingCallService.phoneKey('unknown'), isEmpty);
    });

    test('a short number is used whole rather than padded', () {
      expect(IncomingCallService.phoneKey('112'), '112');
    });
  });

  group('incoming call records', () {
    test('an answered incoming call is never described as agent-placed', () {
      final r = incoming(
        talkDurationSeconds: 145,
        outcome: CallOutcome.interested,
      );
      expect(r.finalResult, contains('Parent called the agent'));
      expect(r.finalResult, contains('2min 25s'));
      expect(r.finalResult, isNot(contains('Agent called')));
    });

    test('a missed incoming call reads as not answered', () {
      final r = incoming(
        talkDurationSeconds: 0,
        outcome: CallOutcome.couldNotReach,
      );
      expect(r.finalResult, contains('not answered'));
      expect(r.verdictKind, CallVerdictKind.notAnsweredMatch);
      expect(r.isFlagged, isFalse);
    });

    test('claiming contact on a call that was never answered is still a lie', () {
      // The agent didn't place this one, but he can still overclaim on it.
      final r = incoming(
        talkDurationSeconds: 0,
        outcome: CallOutcome.interested,
      );
      expect(r.verdictKind, CallVerdictKind.mismatchOverclaimed);
      expect(r.isFlagged, isTrue);
    });

    test('an incoming call is never flagged for the early-hangup signature', () {
      // Those checks are about how the agent dialled; there is no dialling here.
      final r = incoming(talkDurationSeconds: 0);
      expect(r.likelyHungUpEarly, isFalse);
      expect(r.endedQuickly, isFalse);
      expect(r.verdictKind, isNot(CallVerdictKind.earlyHangup));
      expect(r.verdictKind, isNot(CallVerdictKind.noCallDetected));
    });

    test('direction survives a round trip through storage', () {
      final r = incoming(
        talkDurationSeconds: 30,
        outcome: CallOutcome.interested,
      );
      final back = CallRecord.fromJson(r.toJson());
      expect(back.direction, CallDirection.incoming);
      expect(back.reason, CallReason.returnedOurCall);
    });

    test('a record stored before incoming calls existed reads as outgoing', () {
      final legacy = incoming(talkDurationSeconds: 30).toJson()
        ..remove('direction');
      expect(CallRecord.fromJson(legacy).direction, CallDirection.outgoing);
    });
  });

  // These pin the test-mode flag itself. They are skipped rather than inverted
  // when it is turned off, so switching it off before shipping stays a
  // one-line change that doesn't take a red test with it.
  group(
    'incoming-call test mode',
    skip: kIncomingCallTestMode ? null : 'kIncomingCallTestMode is off',
    () {
      test('a simulated answered call comes back as the mock caller', () async {
        IncomingCallService.simulate(
          number: '+213 555 00 00 00',
          talkDurationSeconds: 105,
        );
        final calls = await IncomingCallService.drain();

        expect(calls, hasLength(1));
        expect(calls.single.event.talkDurationSeconds, 105);
        expect(calls.single.event.answered, isTrue);
        // Matched nothing, so it must have fallen through to the stand-in
        // rather than being dropped the way it would be in production.
        expect(calls.single.student.id, 'test-mode');
      });

      test('a simulated missed call is answered:false with no talk time', () async {
        IncomingCallService.simulate(
          number: '+213 555 00 00 00',
          talkDurationSeconds: 0,
        );
        final calls = await IncomingCallService.drain();

        expect(calls.single.event.answered, isFalse);
        expect(calls.single.event.talkDurationSeconds, 0);
      });

      test('draining twice does not ask about the same call again', () async {
        IncomingCallService.simulate(
          number: '+213 555 00 00 00',
          talkDurationSeconds: 30,
        );
        expect(await IncomingCallService.drain(), hasLength(1));
        expect(await IncomingCallService.drain(), isEmpty);
      });

      test('the mock caller keeps the number that actually rang', () {
        final student = IncomingCallService.mockCaller('+213 555 00 00 00');
        expect(student.phone, '+213 555 00 00 00');
        // Anything this submits has to be obviously a test row.
        expect(student.name.toLowerCase(), contains('mock'));
      });

      test('a withheld number still reaches the agent, labelled as unknown', () {
        expect(IncomingCallService.mockCaller('').phone, 'Unknown number');
      });
    },
  );

  test('the outbound reason picker never offers an incoming-only reason', () {
    expect(CallReason.outgoing, isNot(contains(CallReason.returnedOurCall)));
    expect(CallReason.outgoing, contains(CallReason.paymentInquiry));
    expect(CallReason.outgoing.length, CallReason.values.length - 1);
  });
}
