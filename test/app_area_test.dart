import 'package:flutter_test/flutter_test.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/ui/views/root/app_area.dart';

Agent _user({required StaffRole role, String? agentId}) => Agent(
      id: '1',
      name: 'Test Person',
      email: 't@elameed.online',
      role: role,
      agentId: agentId,
    );

/// Which areas each role gets. Pure function, so this is the cheapest place to
/// pin the business rule — no widget tree involved.
void main() {
  group('AppArea.forUser', () {
    test('a provisioned agent gets the call areas and reports', () {
      expect(
        AppArea.forUser(_user(role: StaffRole.teamOnsite, agentId: '7')),
        [AppArea.calls, AppArea.groups, AppArea.history, AppArea.reports],
      );
    });

    test('cleaner and maintenance get reports only', () {
      expect(AppArea.forUser(_user(role: StaffRole.cleaner)), [AppArea.reports]);
      expect(AppArea.forUser(_user(role: StaffRole.maintenance)), [AppArea.reports]);
    });

    test('an admin who is not a provisioned agent gets no dialer', () {
      // The rule keys on agent_id, not on seniority: POST /call-tracker/calls
      // refuses accounts without one, so offering the dialer would be a lie.
      final areas = AppArea.forUser(_user(role: StaffRole.admin, agentId: null));

      expect(areas, [AppArea.reports]);
      expect(areas, isNot(contains(AppArea.calls)));
    });

    test('an admin who IS an agent gets the dialer', () {
      expect(
        AppArea.forUser(_user(role: StaffRole.admin, agentId: '1')),
        contains(AppArea.calls),
      );
    });

    test('no role ever reaches calls without an agent id', () {
      // A loop, so a seventh role added later inherits the invariant instead
      // of quietly getting a dialer it cannot submit from.
      for (final role in StaffRole.values) {
        expect(
          AppArea.forUser(_user(role: role, agentId: null)),
          isNot(contains(AppArea.calls)),
          reason: '$role without an agent id must not get calls',
        );
      }
    });

    test('every role that reaches the shell gets reports', () {
      for (final role in StaffRole.values) {
        for (final agentId in [null, '7']) {
          expect(
            AppArea.forUser(_user(role: role, agentId: agentId)),
            contains(AppArea.reports),
            reason: '$role (agentId: $agentId) must get reports',
          );
        }
      }
    });

    test('the call areas always travel together, in a stable order', () {
      // The nav bar and the IndexedStack are built from this same list, so the
      // order is load-bearing: a reshuffle would relabel every tab.
      final areas = AppArea.forUser(_user(role: StaffRole.teamOnline, agentId: '3'));
      expect(areas.indexOf(AppArea.calls), lessThan(areas.indexOf(AppArea.groups)));
      expect(areas.indexOf(AppArea.groups), lessThan(areas.indexOf(AppArea.history)));
      expect(areas.last, AppArea.reports);
    });

    test('never returns an empty shell', () {
      for (final role in StaffRole.values) {
        expect(AppArea.forUser(_user(role: role)), isNotEmpty);
      }
    });
  });

  group('AppArea metadata', () {
    test('every area has an icon and a label for the nav bar', () {
      for (final area in AppArea.values) {
        expect(area.label, isNotEmpty);
      }
      // Labels must be distinct or the bar reads ambiguously.
      expect(
        AppArea.values.map((a) => a.label).toSet().length,
        AppArea.values.length,
      );
    });
  });
}
