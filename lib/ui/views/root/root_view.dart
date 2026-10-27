import 'package:flutter/material.dart';
import 'package:call_tracker/data/call_monitor.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/refresh_signal.dart';
import 'package:call_tracker/ui/views/call_summary/call_summary_view.dart';
import 'package:call_tracker/ui/views/root/app_area.dart';
import 'package:call_tracker/ui/widgets/bottom_nav_bar.dart';

class RootView extends StatefulWidget {
  const RootView({super.key, required this.areas});

  /// From `AppArea.forUser`, so the shell shows exactly what this role has.
  final List<AppArea> areas;

  @override
  State<RootView> createState() => _RootViewState();
}

class _RootViewState extends State<RootView> with WidgetsBindingObserver {
  int _index = 0;

  bool get _hasCalls => widget.areas.contains(AppArea.calls);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A call placed before the app process was killed mid-call still needs
    // reconciling against the call log so the agent can't dodge it by
    // force-closing the app. Nobody without the calls area can have one.
    if (_hasCalls) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resumePendingCall());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the background is the moment a list is most likely to be
  /// stale — the agent has usually just been told about a new student.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) RefreshSignal.fire();
  }

  void _onTabTap(int index) {
    if (index != _index) RefreshSignal.fire();
    setState(() => _index = index);
  }

  Future<void> _resumePendingCall() async {
    final pending = await CallMonitor.readPending();
    if (pending == null) return;
    final verification = await CallMonitor.reconcile(pending);
    if (!mounted) return;
    // Rebuilt from what was stored when the call was placed — the roster isn't
    // refetched here, so this works even with no connection after the call.
    final student = Student(
      id: pending.studentId,
      name: pending.studentName,
      level: '',
      phones: [
        StudentPhone(
          number: pending.number,
          // The line that was actually dialed, not an assumption.
          type: pending.numberType,
          isPrimary: true,
        ),
      ],
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallSummaryView(
          student: student,
          reason: pending.reason,
          durationSeconds: verification.talkDurationSeconds,
          verification: verification,
          startedAtEpochMs: pending.startedAtEpochMs,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A single-item nav bar is a tappable no-op taking up 60dp and implying
    // something is missing, so roles with one area (cleaner, maintenance) get
    // the screen on its own.
    //
    // ponytail: that also means `RefreshSignal` never fires from a tab change
    // for them — their only refresh paths are app-resume and pull-to-refresh,
    // so Reports must keep its RefreshIndicator.
    if (widget.areas.length == 1) return widget.areas.single.screen;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (final area in widget.areas) area.screen],
      ),
      bottomNavigationBar: BottomNavBar(
        areas: widget.areas,
        currentIndex: _index,
        onTap: _onTabTap,
      ),
    );
  }
}
