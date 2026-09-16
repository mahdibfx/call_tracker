import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:call_tracker/data/call_history_store.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/ui/views/history/history_view.dart';

CallRecord _record({
  required String studentName,
  String? agentId,
  CallOutcome? outcome = CallOutcome.interested,
  int talkDurationSeconds = 0,
  bool likelyHungUpEarly = false,
}) =>
    CallRecord(
      studentId: '1',
      studentName: studentName,
      reason: CallReason.paymentInquiry,
      outcome: outcome,
      agentId: agentId,
      agentName: 'Someone',
      reallyDialed: true,
      talkDurationSeconds: talkDurationSeconds,
      timestampEpochMs: DateTime(2027, 1, 2, 14, 32).millisecondsSinceEpoch,
      likelyHungUpEarly: likelyHungUpEarly,
    );

Future<void> _pumpHistory(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: HistoryView()));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('lists a finished call with what the agent reported', (tester) async {
    await CallHistoryStore.add(_record(studentName: 'Omar Benali', talkDurationSeconds: 92));
    await _pumpHistory(tester);

    expect(find.text('Omar Benali'), findsOneWidget);
    expect(find.text('Payment inquiry'), findsOneWidget);
    expect(find.text('Interested'), findsOneWidget);
    expect(find.text('1min 32s'), findsOneWidget);
  });

  testWidgets('never shows the call-log verdict to the agent', (tester) async {
    // A call the checker would flag hard: claimed contact, nothing on the line.
    final flagged = _record(studentName: 'Yasmine Kaci', likelyHungUpEarly: true);
    expect(flagged.isFlagged, isTrue, reason: 'fixture must be a flagged call');

    await CallHistoryStore.add(flagged);
    await _pumpHistory(tester);

    expect(find.text('Yasmine Kaci'), findsOneWidget);
    for (final leak in [
      flagged.verdictLabel,
      flagged.finalResult,
      'Flagged',
      'flagged',
      'verdict',
    ]) {
      expect(find.textContaining(leak), findsNothing, reason: 'leaked "$leak"');
    }
  });

  testWidgets("hides another agent's calls on a shared handset", (tester) async {
    await CallHistoryStore.add(_record(studentName: 'Mine', agentId: 'a1'));
    await CallHistoryStore.add(_record(studentName: 'Theirs', agentId: 'a2'));
    SharedPreferences.setMockInitialValues({
      'agent_session': '{"id":"a1","name":"Sara","email":"s@x.dz"}',
    });
    // Re-add: setMockInitialValues wiped the store along with the session.
    await CallHistoryStore.add(_record(studentName: 'Mine', agentId: 'a1'));
    await CallHistoryStore.add(_record(studentName: 'Theirs', agentId: 'a2'));

    await _pumpHistory(tester);

    expect(find.text('Mine'), findsOneWidget);
    expect(find.text('Theirs'), findsNothing);
  });
}
