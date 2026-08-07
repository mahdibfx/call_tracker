import 'package:flutter/material.dart';
import 'package:call_tracker/data/call_monitor.dart';
import 'package:call_tracker/data/models.dart';
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

class _RootViewState extends State<RootView> {
  int _index = 0;

  static const _tabs = [
    StudentsView(),
    GroupsView(),
    HistoryView(),
    DashboardView(),
  ];

  @override
  void initState() {
    super.initState();
    // A call placed before the app process was killed mid-call still needs
    // reconciling against the call log so the agent can't dodge it by
    // force-closing the app.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumePendingCall());
  }

  Future<void> _resumePendingCall() async {
    final pending = await CallMonitor.readPending();
    if (pending == null) return;
    Student? student;
    for (final s in dummyStudents) {
      if (s.id == pending.studentId) {
        student = s;
        break;
      }
    }
    final verification = await CallMonitor.reconcile(pending);
    final resolvedStudent = student;
    if (resolvedStudent == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallSummaryView(
          student: resolvedStudent,
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
      bottomNavigationBar: BottomNavBar(currentIndex: _index, onTap: (i) => setState(() => _index = i)),
    );
  }
}
