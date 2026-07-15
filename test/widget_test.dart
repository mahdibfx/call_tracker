import 'package:flutter_test/flutter_test.dart';

import 'package:call_tracker/main.dart';

void main() {
  testWidgets('app boots to student list', (WidgetTester tester) async {
    await tester.pumpWidget(const MainApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('All Students'), findsOneWidget);
    expect(find.text('Lina Djaafri'), findsOneWidget);
  });
}
