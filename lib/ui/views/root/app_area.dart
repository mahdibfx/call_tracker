import 'package:flutter/material.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/ui/views/groups/groups_view.dart';
import 'package:call_tracker/ui/views/history/history_view.dart';
import 'package:call_tracker/ui/views/reports/reports_view.dart';
import 'package:call_tracker/ui/views/students/students_view.dart';

/// One top-level area of the app.
///
/// The nav bar and the `IndexedStack` are both built from the same list, so a
/// tab index can never point at a different screen than the one it labels.
enum AppArea {
  calls(Icons.call, 'Calls'),
  groups(Icons.groups, 'Groups'),
  history(Icons.history, 'History'),
  reports(Icons.assignment_outlined, 'Reports');

  const AppArea(this.icon, this.label);

  final IconData icon;
  final String label;

  /// Const per arm, which keeps the areas cheap to hold in an `IndexedStack`
  /// — and means each area's `initState` runs once per session, so anything
  /// that needs to re-fetch has to listen to `RefreshSignal`.
  Widget get screen => switch (this) {
        AppArea.calls => const StudentsView(),
        AppArea.groups => const GroupsView(),
        AppArea.history => const HistoryView(),
        AppArea.reports => const ReportsView(),
      };

  /// Which areas this staff member gets, in tab order.
  ///
  /// Calls (and the student/group lists and history that serve it) appear only
  /// for a registered call-tracker agent: `POST /call-tracker/calls` refuses
  /// anyone without an `agent_id`, so offering the dialer and then failing the
  /// submit would be worse than not offering it. Note this keys on `agent_id`,
  /// not on role — an admin who is not a provisioned agent gets no dialer.
  ///
  /// Reports is available to every role that can reach this app at all.
  /// Teachers never get here: they are refused at login and on restore.
  static List<AppArea> forUser(Agent user) => [
        if (user.canSeeCalls) ...[calls, groups, history],
        reports,
      ];
}
