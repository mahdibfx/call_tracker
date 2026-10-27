import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:call_tracker/data/call_monitor.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/ui/views/student_detail/widgets/number_picker_sheet.dart';

Student _student({required List<StudentPhone> phones}) => Student(
      id: '102',
      name: 'مريم البتول',
      level: 'A1',
      phones: phones,
    );

/// A live two-line student: personal is primary, parent is not.
final _twoLines = _student(phones: const [
  StudentPhone(number: '0782720884', type: 'personal', isPrimary: true),
  StudentPhone(number: '0553294854', type: 'parent', isPrimary: false),
]);

final _oneLine = _student(phones: const [
  StudentPhone(number: '0672048115', type: 'personal', isPrimary: true),
]);

void main() {
  group('which line gets dialed', () {
    test('one number on file means no choice to make', () {
      // The branch that dials immediately: asking would be a tap for nothing,
      // and 96% of students are in this case.
      expect(_oneLine.phones.length, 1);
      expect(_oneLine.phones.single.number, '0672048115');
    });

    test('the suggested line for a two-number student is the parent', () {
      // Agents are calling the parent, so that is what the picker marks. This
      // is the pre-selection the sheet highlights.
      expect(_twoLines.phones.length, greaterThan(1));
      expect(_twoLines.phone, '0553294854');
      expect(
        _twoLines.phones.firstWhere((p) => p.number == _twoLines.phone).isParentLine,
        isTrue,
      );
    });

    test('a student with no numbers cannot start a call', () {
      final none = _student(phones: const []);
      expect(none.hasPhone, isFalse);
      expect(none.phone, '');
    });
  });

  group('phoneSummary', () {
    test('flags that more lines exist, so the choice is no surprise', () {
      expect(_twoLines.phoneSummary, contains('+1'));
      expect(_twoLines.phoneSummary, contains(_twoLines.phone));
    });

    test('a single line reads as just the number', () {
      expect(_oneLine.phoneSummary, '0672048115');
    });

    test('no number on file says so', () {
      expect(_student(phones: const []).phoneSummary, 'No number on file');
    });
  });

  group('the dialed number survives to reconciliation', () {
    // reconcile() finds the call in the device log by this exact string. If
    // anything re-derives it from the student record, a parent-line call is
    // looked up under the personal number, found missing, and the agent is
    // flagged for a call they really made.
    test('PendingCall round-trips the number and which line it was', () {
      final chosen = _twoLines.phones.last; // the parent line
      final pending = PendingCall(
        studentId: _twoLines.id,
        studentName: _twoLines.name,
        number: chosen.number,
        numberType: chosen.type,
        startedAtEpochMs: 1790159319150,
        reason: CallReason.paymentInquiry,
      );

      expect(pending.number, chosen.number);
      expect(pending.number, isNot(_twoLines.phones.first.number));

      final back = PendingCall.fromJson(pending.toJson());
      expect(back.number, chosen.number);
      expect(back.numberType, 'parent');
      expect(back.reason, CallReason.paymentInquiry);
      expect(back.startedAtEpochMs, 1790159319150);
    });

    test('a record written before the picker existed defaults to personal', () {
      // An upgrade mid-call: the stored blob has no numberType.
      final legacy = {
        'studentId': '1',
        'studentName': 'X',
        'number': '0555000111',
        'startedAtEpochMs': 1,
        'reason': CallReason.survey.name,
      };

      final back = PendingCall.fromJson(legacy);

      expect(back.numberType, 'personal');
      expect(back.number, '0555000111');
    });

    test('the finished-call view shows the line that was rung', () {
      // Narrowed to the dialed line, so .phone cannot drift back to the
      // precedence pick.
      final dialed = _twoLines.onlyPhone(number: '0553294854', type: 'parent');

      expect(dialed.phone, '0553294854');
      expect(dialed.phones.single.isParentLine, isTrue);
      expect(dialed.name, _twoLines.name, reason: 'identity is preserved');
      expect(dialed.id, _twoLines.id);
    });

    test('narrowing to the personal line does not resurrect the parent one', () {
      final dialed = _twoLines.onlyPhone(number: '0782720884');

      expect(dialed.phone, '0782720884');
      expect(dialed.phones.single.isParentLine, isFalse);
    });
  });

  group('the sheet', () {
    testWidgets('lists every line, labelled, with the parent marked', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showNumberPicker(context, _twoLines),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('0782720884'), findsOneWidget);
      expect(find.text('0553294854'), findsOneWidget);
      expect(find.textContaining('Personal number'), findsOneWidget);
      expect(find.textContaining("Parent's number"), findsOneWidget);
      // The parent line carries the suggestion marker.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.escalator_warning_outlined), findsOneWidget);
    });

    testWidgets('tapping a line returns it, in one tap', (tester) async {
      StudentPhone? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async =>
                    picked = await showNumberPicker(context, _twoLines),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Deliberately the line that is NOT suggested, to prove the tap decides.
      await tester.tap(find.text('0782720884'));
      await tester.pumpAndSettle();

      expect(picked, isNotNull);
      expect(picked!.number, '0782720884');
      expect(picked!.isParentLine, isFalse);
    });

    testWidgets('dismissing returns nothing, so no call is placed', (tester) async {
      StudentPhone? picked;
      var returned = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  picked = await showNumberPicker(context, _twoLines);
                  returned = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10)); // the scrim
      await tester.pumpAndSettle();

      expect(returned, isTrue);
      expect(picked, isNull);
    });
  });
}
