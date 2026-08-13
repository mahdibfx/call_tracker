import 'package:flutter_test/flutter_test.dart';
import 'package:call_tracker/data/models.dart';

/// Pins the anti-fraud classification — the logic that decides whether an
/// agent's reported outcome is backed up by the device's call log.
CallRecord record({
  required bool reallyDialed,
  required int talkDurationSeconds,
  CallOutcome? outcome,
  bool likelyHungUpEarly = false,
  bool endedQuickly = false,
  int? ringSessionSeconds,
}) =>
    CallRecord(
      studentId: '1',
      studentName: 'Test Student',
      reason: CallReason.survey,
      outcome: outcome,
      reallyDialed: reallyDialed,
      talkDurationSeconds: talkDurationSeconds,
      timestampEpochMs: 0,
      likelyHungUpEarly: likelyHungUpEarly,
      endedQuickly: endedQuickly,
      ringSessionSeconds: ringSessionSeconds,
    );

void main() {
  test('no call in the log is flagged regardless of what the agent claimed', () {
    final r = record(reallyDialed: false, talkDurationSeconds: 0, outcome: CallOutcome.interested);
    expect(r.verdictKind, CallVerdictKind.noCallDetected);
    expect(r.isFlagged, isTrue);
  });

  test('answered call matching a reached outcome is clean', () {
    final r = record(reallyDialed: true, talkDurationSeconds: 145, outcome: CallOutcome.interested);
    expect(r.verdictKind, CallVerdictKind.answeredMatch);
    expect(r.isFlagged, isFalse);
  });

  test('claiming contact on an unanswered call is flagged as overclaiming', () {
    final r = record(reallyDialed: true, talkDurationSeconds: 0, outcome: CallOutcome.interested);
    expect(r.verdictKind, CallVerdictKind.mismatchOverclaimed);
    expect(r.isFlagged, isTrue);
  });

  test('unanswered call reported as unreachable is clean', () {
    final r = record(reallyDialed: true, talkDurationSeconds: 0, outcome: CallOutcome.couldNotReach);
    expect(r.verdictKind, CallVerdictKind.notAnsweredMatch);
    expect(r.isFlagged, isFalse);
  });

  test('hanging up before it could ring is flagged', () {
    final r = record(
      reallyDialed: true,
      talkDurationSeconds: 0,
      outcome: CallOutcome.couldNotReach,
      likelyHungUpEarly: true,
      ringSessionSeconds: 2,
    );
    expect(r.verdictKind, CallVerdictKind.earlyHangup);
    expect(r.isFlagged, isTrue);
  });

  test('ambiguous quick end is review-only, not a confirmed flag', () {
    final r = record(
      reallyDialed: true,
      talkDurationSeconds: 0,
      outcome: CallOutcome.couldNotReach,
      endedQuickly: true,
      ringSessionSeconds: 9,
    );
    expect(r.verdictKind, CallVerdictKind.endedQuickly);
    expect(r.isFlagged, isFalse);
    expect(r.needsReview, isTrue);
  });

  test('a connected call is never described as never placed', () {
    // The regression that made the demo fail: answered calls reported as
    // "no outgoing call detected".
    final r = record(reallyDialed: true, talkDurationSeconds: 145, outcome: CallOutcome.interested);
    expect(r.finalResult, contains('answered'));
    expect(r.finalResult, isNot(contains('never actually placed')));
  });
}
