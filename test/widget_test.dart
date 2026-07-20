import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:call_tracker/main.dart';

void main() {
  testWidgets('agent can log in and reach the student list', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MainApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Log In'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'sara.amrani@institute.dz');
    await tester.enterText(find.byType(TextField).at(1), 'agent123');
    await tester.tap(find.text('Log In'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('All Students'), findsOneWidget);
    expect(find.text('Lina Djaafri'), findsOneWidget);
  });
}
