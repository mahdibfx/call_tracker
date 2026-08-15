import 'package:call_tracker/data/refresh_signal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens subscribe with a method tear-off and unsubscribe with the same one.
/// If those two tear-offs were not equal the listener would survive dispose and
/// a dead screen would keep re-fetching, so this pins the contract down.
int _loads = 0;

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _load();
    RefreshSignal.listenable.addListener(_load);
  }

  @override
  void dispose() {
    RefreshSignal.listenable.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async => _loads++;

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  setUp(() => _loads = 0);

  testWidgets('a mounted screen reloads every time the signal fires', (tester) async {
    await tester.pumpWidget(const _Probe());
    expect(_loads, 1);

    RefreshSignal.fire();
    await tester.pump();
    expect(_loads, 2);

    RefreshSignal.fire();
    await tester.pump();
    expect(_loads, 3);
  });

  testWidgets('a disposed screen stops reloading', (tester) async {
    await tester.pumpWidget(const _Probe());
    await tester.pumpWidget(const SizedBox());

    RefreshSignal.fire();
    await tester.pump();
    expect(_loads, 1);
  });
}
