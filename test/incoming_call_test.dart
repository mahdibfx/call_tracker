import 'package:flutter_test/flutter_test.dart';
import 'package:call_tracker/data/incoming_call_service.dart';
import 'package:call_tracker/data/models.dart';

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

  test('the outbound reason picker never offers an incoming-only reason', () {
    expect(CallReason.outgoing, isNot(contains(CallReason.returnedOurCall)));
    expect(CallReason.outgoing, contains(CallReason.paymentInquiry));
    expect(CallReason.outgoing.length, CallReason.values.length - 1);
  });
}
