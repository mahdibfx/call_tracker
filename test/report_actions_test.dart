import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:call_tracker/data/auth_service.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/report_models.dart';
import 'package:call_tracker/ui/views/reports/report_detail_view.dart';

Agent _user({required StaffRole role}) =>
    Agent(id: '1', name: 'Test Person', email: 't@e.com', role: role);

/// A plumbing report, so `maintenance` owns it and nobody else does.
Report _plumbing({ReportState state = ReportState.review, bool confirmed = false}) =>
    Report(
      id: 21,
      state: state,
      confirmed: confirmed,
      description: 'Water leaking under the sink',
      category: const ReportCategory(
        id: 11,
        code: 'plumbing',
        name: 'Water leak / plumbing',
        role: StaffRole.maintenance,
      ),
      reportedBy: const ReportPerson(name: 'Amine K.', role: StaffRole.teacher),
      reportedAt: DateTime(2026, 10, 24, 12, 38),
    );

Future<void> _pump(WidgetTester tester, Report report, {required StaffRole as}) async {
  AuthService.signedIn.value = _user(role: as);
  await tester.pumpWidget(MaterialApp(home: ReportDetailView(report: report)));
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.signedIn.value = null;
  });

  tearDown(() => AuthService.signedIn.value = null);

  group('who is offered the handling actions', () {
    testWidgets('the role that owns the category is', (tester) async {
      await _pump(tester, _plumbing(), as: StaffRole.maintenance);

      expect(find.text('What now?'), findsOneWidget);
      expect(find.text('Start work'), findsOneWidget);
      expect(find.text('Close this report'), findsOneWidget);
    });

    testWidgets('a role that does not own it is offered nothing', (tester) async {
      // A cleaner opening a plumbing report can read it but not act. Better to
      // show no buttons than buttons that 403.
      await _pump(tester, _plumbing(), as: StaffRole.cleaner);

      expect(find.text('What now?'), findsNothing);
      expect(find.text('Start work'), findsNothing);
      expect(find.text('Close this report'), findsNothing);
      // The report itself is still readable.
      expect(find.textContaining('Water leaking'), findsOneWidget);
    });

    testWidgets('an admin is offered them on any category', (tester) async {
      await _pump(tester, _plumbing(), as: StaffRole.admin);

      expect(find.text('Start work'), findsOneWidget);
      expect(find.text('Close this report'), findsOneWidget);
    });
  });

  group('the offered actions follow the state', () {
    testWidgets('a report in review can be started or closed', (tester) async {
      await _pump(tester, _plumbing(state: ReportState.review), as: StaffRole.maintenance);

      expect(find.text('Start work'), findsOneWidget);
      expect(find.text('Close this report'), findsOneWidget);
      expect(find.text('Reopen'), findsNothing);
    });

    testWidgets('a report in progress can only be closed', (tester) async {
      await _pump(
        tester,
        _plumbing(state: ReportState.processing),
        as: StaffRole.maintenance,
      );

      expect(find.text('Start work'), findsNothing, reason: 'already started');
      expect(find.text('Close this report'), findsOneWidget);
    });

    testWidgets('a closed report can be reopened', (tester) async {
      await _pump(
        tester,
        _plumbing(state: ReportState.complete),
        as: StaffRole.maintenance,
      );

      expect(find.text('Reopen'), findsOneWidget);
      expect(find.text('Close this report'), findsNothing);
      expect(find.text('Start work'), findsNothing);
    });

    testWidgets('a state this build does not know offers no transition', (tester) async {
      // Rather than guessing where an unrecognised state should go next.
      final unknown = Report(
        id: 21,
        state: null,
        category: _plumbing().category,
        reportedAt: DateTime(2026, 10, 24),
      );

      await _pump(tester, unknown, as: StaffRole.maintenance);

      expect(find.text('Start work'), findsNothing);
      expect(find.text('Close this report'), findsNothing);
      expect(find.textContaining('does not recognise'), findsOneWidget);
    });
  });

  group('sign-off is admin only', () {
    testWidgets('an admin can sign off', (tester) async {
      await _pump(tester, _plumbing(), as: StaffRole.admin);
      expect(find.text('Sign off'), findsOneWidget);
    });

    testWidgets('and can take it back once given', (tester) async {
      await _pump(tester, _plumbing(confirmed: true), as: StaffRole.admin);
      expect(find.text('Take back sign-off'), findsOneWidget);
      expect(find.text('Sign off'), findsNothing);
    });

    testWidgets('the handling role cannot sign off', (tester) async {
      await _pump(tester, _plumbing(), as: StaffRole.maintenance);

      expect(find.text('Sign off'), findsNothing);
      expect(find.text('Take back sign-off'), findsNothing);
      // ...but can still do its own job.
      expect(find.text('Start work'), findsOneWidget);
    });
  });

  group('what the detail screen shows', () {
    testWidgets('names who reported it and who handles it', (tester) async {
      await _pump(tester, _plumbing(), as: StaffRole.admin);

      expect(find.text('Reported by'), findsOneWidget);
      expect(find.textContaining('Amine K.'), findsOneWidget);
      expect(find.text('Handled by'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
    });

    testWidgets('shows the state, and no result section while open', (tester) async {
      await _pump(tester, _plumbing(), as: StaffRole.admin);

      expect(find.text('In review'), findsOneWidget);
      expect(find.text('Result'), findsNothing);
    });

    testWidgets('shows the result once the report is closed', (tester) async {
      final closed = Report(
        id: 21,
        state: ReportState.complete,
        category: _plumbing().category,
        confirmationDescription: 'Replaced the washer.',
        reportedAt: DateTime(2026, 10, 24),
      );

      await _pump(tester, closed, as: StaffRole.admin);

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Result'), findsOneWidget);
      expect(find.text('Replaced the washer.'), findsOneWidget);
    });
  });
}
