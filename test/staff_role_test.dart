import 'package:flutter_test/flutter_test.dart';
import 'package:call_tracker/data/models.dart';

/// The backend spells a role two ways: `/Auth/login` returns `team onsite`,
/// `report_categories.role` returns `team_onsite`. These tests pin the single
/// normaliser that keeps the two from ever being compared as raw strings.
void main() {
  group('StaffRole.parse', () {
    test('the two wire spellings resolve to the same role', () {
      expect(StaffRole.parse('team onsite'), StaffRole.teamOnsite);
      expect(StaffRole.parse('team_onsite'), StaffRole.teamOnsite);
      expect(StaffRole.parse('team onsite'), StaffRole.parse('team_onsite'));
      expect(StaffRole.parse('team online'), StaffRole.parse('team_online'));
    });

    test('casing and hyphens are tolerated', () {
      expect(StaffRole.parse('Team Onsite'), StaffRole.teamOnsite);
      expect(StaffRole.parse('TEAM-ONSITE'), StaffRole.teamOnsite);
      expect(StaffRole.parse('  admin  '), StaffRole.admin);
      expect(StaffRole.parse('MAINTENANCE'), StaffRole.maintenance);
    });

    test('every documented role is recognised', () {
      expect(StaffRole.parse('admin'), StaffRole.admin);
      expect(StaffRole.parse('teacher'), StaffRole.teacher);
      expect(StaffRole.parse('cleaner'), StaffRole.cleaner);
      expect(StaffRole.parse('maintenance'), StaffRole.maintenance);
    });

    test('an unknown role is null rather than a crash', () {
      // A seventh role added server-side must not break installed apps.
      expect(StaffRole.parse('principal'), isNull);
      expect(StaffRole.parse(''), isNull);
      expect(StaffRole.parse(null), isNull);
      expect(StaffRole.parse(42), isNull);
    });

    test('code emits the underscored form that report categories use', () {
      expect(StaffRole.teamOnsite.code, 'team_onsite');
      expect(StaffRole.teamOnline.code, 'team_online');
      expect(StaffRole.cleaner.code, 'cleaner');
      // Round-trips: the persisted form parses back to the same role.
      for (final role in StaffRole.values) {
        expect(StaffRole.parse(role.code), role);
        expect(StaffRole.parse(role.label), role);
      }
    });
  });

  group('Agent.fromAuthPayload', () {
    /// The inner `data.data` object of /Auth/login, as production returns it.
    Map<String, dynamic> payload({
      Object? role = 'team onsite',
      Object? agentId = 7,
    }) => {
          'account_id': 14,
          'user_id': 2031,
          'email': 'amina@elameed.online',
          'name': 'Amina Bouzid',
          'job': 'Secretary',
          'country': 'Algeria',
          'Role': role,
          'role': role,
          'agent_id': agentId,
          'permissions': ['groups.read', 'students.read'],
          'scopes': {'course_type': {'values': ['Onsite']}},
        };

    test('reads the live payload', () {
      final a = Agent.fromAuthPayload(payload());
      expect(a.id, '14'); // account_id, stringified
      expect(a.userId, '2031');
      expect(a.name, 'Amina Bouzid');
      expect(a.email, 'amina@elameed.online');
      expect(a.role, StaffRole.teamOnsite);
      expect(a.agentId, '7');
      expect(a.job, 'Secretary');
      expect(a.permissions, ['groups.read', 'students.read']);
      expect(a.canSeeCalls, isTrue);
    });

    test('a null agent_id means no calls area', () {
      final a = Agent.fromAuthPayload(payload(agentId: null));
      expect(a.agentId, isNull);
      expect(a.canSeeCalls, isFalse);
    });

    test('falls back to the capitalised Role key', () {
      final p = payload()..remove('role');
      expect(Agent.fromAuthPayload(p).role, StaffRole.teamOnsite);
    });

    test('an unknown role parses to null rather than throwing', () {
      expect(Agent.fromAuthPayload(payload(role: 'principal')).role, isNull);
    });

    test('isAdmin only for admin', () {
      expect(Agent.fromAuthPayload(payload(role: 'admin')).isAdmin, isTrue);
      expect(Agent.fromAuthPayload(payload(role: 'cleaner')).isAdmin, isFalse);
    });

    test('a sparse payload does not throw', () {
      expect(Agent.fromAuthPayload({}).role, isNull);
      expect(Agent.fromAuthPayload({}).permissions, isEmpty);
      expect(Agent.fromAuthPayload({'account_id': 3}).id, '3');
    });
  });

  group('session storage', () {
    test('round-trips the role, agent id and permissions', () {
      const a = Agent(
        id: '14',
        name: 'Amina',
        email: 'a@elameed.online',
        role: StaffRole.teamOnsite,
        userId: '2031',
        agentId: '7',
        job: 'Secretary',
        permissions: ['groups.read'],
      );
      final back = Agent.fromJson(a.toJson());
      expect(back.id, a.id);
      expect(back.role, StaffRole.teamOnsite);
      expect(back.userId, '2031');
      expect(back.agentId, '7');
      expect(back.job, 'Secretary');
      expect(back.permissions, ['groups.read']);
    });

    test('round-trips nulls', () {
      const a = Agent(id: '1', name: 'X', email: 'x@y.z');
      final back = Agent.fromJson(a.toJson());
      expect(back.role, isNull);
      expect(back.agentId, isNull);
      expect(back.canSeeCalls, isFalse);
      expect(back.permissions, isEmpty);
    });

    test('the pre-role blob is readable and flagged as legacy', () {
      // Exactly what the shipped build wrote: id, name, email, no version.
      final old = {'id': 'a1', 'name': 'Sara Amrani', 'email': 'sara@institute.dz'};
      expect(Agent.isLegacyBlob(old), isTrue);
      final a = Agent.fromJson(old); // must not throw
      expect(a.name, 'Sara Amrani');
      expect(a.role, isNull);
    });

    test('a current blob is not flagged as legacy', () {
      const a = Agent(id: '1', name: 'X', email: 'x@y.z', role: StaffRole.cleaner);
      expect(Agent.isLegacyBlob(a.toJson()), isFalse);
    });

    test('a numeric id stored by the login path is read back as a string', () {
      // The old build built id via .toString() but read it with `as String`.
      expect(Agent.fromJson({'id': 5, 'name': 'X', 'email': 'x@y.z'}).id, '5');
    });

    test('a blob missing every field does not throw', () {
      final a = Agent.fromJson({});
      expect(a.id, '');
      expect(a.role, isNull);
    });
  });
}
