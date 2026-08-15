import 'package:flutter/material.dart';
import 'package:call_tracker/data/call_monitor.dart';
import 'package:call_tracker/data/incoming_call_service.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/native_call_service.dart';
import 'package:call_tracker/data/refresh_signal.dart';
import 'package:call_tracker/ui/views/call_summary/call_summary_view.dart';
import 'package:call_tracker/ui/views/dashboard/dashboard_view.dart';
import 'package:call_tracker/ui/views/groups/groups_view.dart';
import 'package:call_tracker/ui/views/history/history_view.dart';
import 'package:call_tracker/ui/views/students/students_view.dart';
import 'package:call_tracker/ui/widgets/bottom_nav_bar.dart';

class RootView extends StatefulWidget {
  const RootView({super.key});

  @override
  State<RootView> createState() => _RootViewState();
}

class _RootViewState extends State<RootView> with WidgetsBindingObserver {
  int _index = 0;

  /// One summary screen at a time. Resume, a tab tap and the native ping can
  /// all land within a frame of each other, and each of them would otherwise
  /// push its own copy.
  bool _presenting = false;

  static const _tabs = [
    StudentsView(),
    GroupsView(),
    HistoryView(),
    DashboardView(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fires when a call the agent received ends while the app is alive — no
    // need to wait for a resume that may never come if he is already looking
    // at the app.
    NativeCallService.setIncomingCallListener(_presentIncomingCalls);
    // A call placed before the app process was killed mid-call still needs
    // reconciling against the call log so the agent can't dodge it by
    // force-closing the app.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumeOnStart());
  }

  @override
  void dispose() {
    NativeCallService.setIncomingCallListener(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the background is the moment a list is most likely to be
  /// stale — the agent has usually just been told about a new student.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    RefreshSignal.fire();
    // Deliberately not _resumePendingCall(): an outgoing call already has
    // CallView sitting on top of this route doing its own reconcile, and both
    // reading the same pending record would resolve it twice.
    _presentIncomingCalls();
  }

  void _onTabTap(int index) {
    if (index != _index) RefreshSignal.fire();
    setState(() => _index = index);
  }

  Future<void> _resumeOnStart() async {
    if (_presenting) return;
    _presenting = true;
    try {
      await _resumePendingCall();
      await _drainIncomingCalls();
    } finally {
      _presenting = false;
    }
  }

  Future<void> _presentIncomingCalls() async {
    if (_presenting) return;
    _presenting = true;
    try {
      await _drainIncomingCalls();
    } finally {
      _presenting = false;
    }
  }

  /// True only when this route is the visible one. Draining while the agent is
  /// mid-flow somewhere else would shove a summary screen on top of whatever
  /// he was doing — and, worse, empty the native queue to do it. Leaving the
  /// calls queued costs nothing: the next resume or app open picks them up.
  bool get _canPresent {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  Future<void> _drainIncomingCalls() async {
    if (!_canPresent) return;
    final calls = await IncomingCallService.drain();
    for (final call in calls) {
      if (!mounted) return;
      // Awaited so several queued calls are logged one after another rather
      // than stacking every summary screen on top of each other at once.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallSummaryView(
            student: call.student,
            reason: CallReason.returnedOurCall,
            direction: CallDirection.incoming,
            durationSeconds: call.event.talkDurationSeconds,
          ),
        ),
      );
    }
  }

  Future<void> _resumePendingCall() async {
    final pending = await CallMonitor.readPending();
    if (pending == null) return;
    final verification = await CallMonitor.reconcile(pending);
    if (!mounted) return;
    final student = Student(
      id: pending.studentId,
      name: pending.studentName,
      phone: pending.number,
      level: '',
      parentName: pending.parentName,
      studentId: '',
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallSummaryView(
          student: student,
          reason: pending.reason,
          durationSeconds: verification.talkDurationSeconds,
          verification: verification,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavBar(currentIndex: _index, onTap: _onTabTap),
    );
  }
}
