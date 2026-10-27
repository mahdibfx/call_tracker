import 'package:flutter_test/flutter_test.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/report_models.dart';

/// Shapes copied from live production responses, not from the docs — the docs
/// are wrong in three places and those are pinned below.
Map<String, dynamic> _reportJson({
  Object? state = 'review',
  Object? category = const {
    'id': 1,
    'code': 'other',
    'name': 'Other',
    'name_ar': 'أخرى',
    'role': 'admin',
  },
  Object? room,
  Object? description = 'je ne peu pa valider les séances.',
  Object? imageUrl,
}) => {
      'id': 7,
      'category_id': 1,
      'category': category,
      'state': state,
      'state_note': null,
      'state_changed_at': null,
      'state_changed_by': null,
      'confirmation_image_url': null,
      'confirmation_description': null,
      'description': description,
      'image_url': imageUrl,
      'reported_at': '2026-10-24T12:38:44.808Z',
      'room_id': null,
      'room': room,
      'reported_by': {
        'user_id': 2966,
        'account_id': 37,
        'name': 'Chahrazed Amarouayache',
        'role': 'teacher',
      },
      'confirmed': false,
      'confirmed_at': null,
      'confirmed_by': null,
      'created_at': '2026-10-24T12:38:44.808Z',
      'updated_at': '2026-10-24T12:38:44.808Z',
    };

Agent _user({required StaffRole role}) =>
    Agent(id: '1', name: 'N', email: 'n@e.com', role: role);

void main() {
  group('ReportState', () {
    test('parses every documented state', () {
      expect(ReportState.parse('review'), ReportState.review);
      expect(ReportState.parse('processing'), ReportState.processing);
      expect(ReportState.parse('complete'), ReportState.complete);
      expect(ReportState.parse('not_complete'), ReportState.notComplete);
    });

    test('an unknown state is null rather than a crash', () {
      expect(ReportState.parse('escalated'), isNull);
      expect(ReportState.parse(null), isNull);
      expect(ReportState.parse(''), isNull);
    });

    test('only the closing states accept a result', () {
      // The backend ignores confirmation_description / _image otherwise.
      expect(ReportState.complete.isClosing, isTrue);
      expect(ReportState.notComplete.isClosing, isTrue);
      expect(ReportState.review.isClosing, isFalse);
      expect(ReportState.processing.isClosing, isFalse);
    });

    test('each state is visually distinct', () {
      final colors = ReportState.values.map((s) => s.color).toSet();
      expect(colors.length, ReportState.values.length);
      for (final s in ReportState.values) {
        expect(s.label, isNotEmpty);
      }
    });
  });

  group('Report.fromJson', () {
    test('reads a live report', () {
      final r = Report.fromJson(_reportJson())!;
      expect(r.id, 7);
      expect(r.state, ReportState.review);
      expect(r.category?.code, 'other');
      expect(r.category?.role, StaffRole.admin);
      expect(r.description, contains('séances'));
      expect(r.reportedBy?.name, 'Chahrazed Amarouayache');
      expect(r.reportedBy?.role, StaffRole.teacher);
      expect(r.confirmed, isFalse);
      expect(r.reportedAt, DateTime.parse('2026-10-24T12:38:44.808Z'));
      expect(r.hasResult, isFalse);
    });

    test('survives every nullable field being absent', () {
      final r = Report.fromJson(_reportJson(
        state: null,
        category: null,
        room: null,
        description: null,
        imageUrl: null,
      ))!;
      expect(r.state, isNull);
      expect(r.category, isNull);
      expect(r.room, isNull);
      expect(r.description, isNull);
      expect(r.imageUrl, isNull);
      // Still renders something rather than an empty card.
      expect(r.summaryLine, 'Report #7');
    });

    test('a row with no usable id is dropped, not rendered blank', () {
      expect(Report.fromJson({'id': null}), isNull);
      expect(Report.fromJson({'id': 'abc'}), isNull);
      expect(Report.fromJson({}), isNull);
    });

    test('an unknown state does not take the report down with it', () {
      final r = Report.fromJson(_reportJson(state: 'escalated'))!;
      expect(r.id, 7);
      expect(r.state, isNull);
    });

    test('reads the room when one is attached', () {
      final r = Report.fromJson(_reportJson(
        room: {'id': 4, 'room_index': 'R02', 'floor_number': 1},
      ))!;
      expect(r.room?.roomIndex, 'R02');
      expect(r.room?.display, 'R02 · Floor 1');
    });

    test('falls back to created_at when reported_at is missing', () {
      final json = _reportJson()..remove('reported_at');
      expect(Report.fromJson(json)!.reportedAt, isNotNull);
    });

    test('the summary line prefers the description', () {
      expect(Report.fromJson(_reportJson())!.summaryLine, contains('séances'));
      // With no description it names the category instead of going blank.
      expect(Report.fromJson(_reportJson(description: null))!.summaryLine, 'Other');
    });
  });

  group('who may handle a report', () {
    test('the role owning the category may', () {
      final plumbing = Report.fromJson(_reportJson(category: const {
        'id': 11,
        'code': 'plumbing',
        'name': 'Water leak / plumbing',
        // Underscored here, spaced at login — the normaliser reconciles them.
        'role': 'maintenance',
      }))!;

      expect(plumbing.canBeHandledBy(_user(role: StaffRole.maintenance)), isTrue);
      expect(plumbing.canBeHandledBy(_user(role: StaffRole.cleaner)), isFalse);
      expect(plumbing.canBeHandledBy(_user(role: StaffRole.teacher)), isFalse);
    });

    test('an admin may handle anything', () {
      final r = Report.fromJson(_reportJson(category: const {
        'id': 3,
        'code': 'dirty_room',
        'name': 'Dirty room',
        'role': 'cleaner',
      }))!;
      expect(r.canBeHandledBy(_user(role: StaffRole.admin)), isTrue);
    });

    test('the two role spellings agree at the real integration point', () {
      // category.role arrives underscored; a team onsite login arrives spaced.
      final r = Report.fromJson(_reportJson(category: const {
        'id': 20,
        'code': 'room_schedule',
        'name': 'Room or schedule problem',
        'role': 'team_onsite',
      }))!;

      expect(r.category?.role, StaffRole.teamOnsite);
      expect(r.canBeHandledBy(_user(role: StaffRole.teamOnsite)), isTrue);
      expect(r.canBeHandledBy(_user(role: StaffRole.teamOnline)), isFalse);
    });

    test('a category with no role is handled by nobody but an admin', () {
      final r = Report.fromJson(_reportJson(category: null))!;
      expect(r.canBeHandledBy(_user(role: StaffRole.cleaner)), isFalse);
      expect(r.canBeHandledBy(_user(role: StaffRole.admin)), isTrue);
    });
  });

  group('pagination', () {
    test('the flat reports envelope yields a real page count', () {
      // The regression that would otherwise strand every page after the first:
      // /reports has no `pagination` object and no totalPages.
      final page = Paged.fromFlat<Report>(
        {'data': [_reportJson()], 'total': 120, 'page': 2, 'limit': 50},
        (e) => Report.fromJson(e)!,
      );

      expect(page.page, 2);
      expect(page.totalPages, 3);
      expect(page.hasMore, isTrue);
      expect(page.items.length, 1);
    });

    test('the last page knows it is last', () {
      final page = Paged.fromFlat<Report>(
        {'data': const [], 'total': 120, 'page': 3, 'limit': 50},
        (e) => Report.fromJson(e)!,
      );
      expect(page.hasMore, isFalse);
    });

    test('an empty result is a single page, not zero', () {
      final page = Paged.fromFlat<Report>(
        {'data': const [], 'total': 0, 'page': 1, 'limit': 50},
        (e) => Report.fromJson(e)!,
      );
      expect(page.totalPages, 1);
      expect(page.hasMore, isFalse);
    });

    test('the nested envelope still works for students', () {
      // Guards against anyone "unifying" the two readers.
      final page = Paged.fromJson<String>(
        {
          'data': [
            {'student_id': 1, 'first_name': 'A', 'last_name': 'B'},
          ],
          'pagination': {'page': 2, 'limit': 100, 'total': 250, 'totalPages': 3},
        },
        (e) => '${e['student_id']}',
      );
      expect(page.page, 2);
      expect(page.totalPages, 3);
      expect(page.hasMore, isTrue);
    });
  });

  group('ReportMetrics', () {
    test('reads the category code from the key the API actually sends', () {
      // The payload says `category`; the docs claim `category_code`.
      final m = ReportMetrics.fromJson({
        'category_id': 1,
        'category': 'other',
        'category_name': 'Other',
        'category_role': 'admin',
        'total': 4,
        'unconfirmed': 4,
        'review': 4,
        'processing': 0,
        'complete': 0,
        'not_complete': 0,
      })!;

      expect(m.categoryCode, 'other');
      expect(m.categoryName, 'Other');
      expect(m.categoryRole, StaffRole.admin);
      expect(m.total, 4);
      expect(m.open, 4);
    });

    test('still reads the documented key if the API ever sends it', () {
      final m = ReportMetrics.fromJson({
        'category_id': 2,
        'category_code': 'plumbing',
        'category_name': 'Plumbing',
        'review': 1,
        'processing': 2,
      })!;
      expect(m.categoryCode, 'plumbing');
      expect(m.open, 3);
    });
  });

  group('Room', () {
    test('room_index is a label, not a number', () {
      final room = Room.fromJson({
        'id': 3,
        'room_index': 'R01',
        'floor_number': 0,
        'capacity': 12,
        'type': 'Classroom',
      })!;
      expect(room.roomIndex, 'R01');
      expect(room.display, 'R01 · Floor 0');
      expect(room.capacity, 12);
    });

    test('no floor means no floor in the label', () {
      final room = Room.fromJson({'id': 1, 'room_index': 'B2'})!;
      expect(room.display, 'B2');
    });
  });

  group('ReportCategory', () {
    test('reads a live category', () {
      final c = ReportCategory.fromJson({
        'id': 11,
        'code': 'air_conditioning',
        'name': 'Air conditioning / heating',
        'name_ar': 'التكييف والتدفئة',
        'role': 'maintenance',
        'is_active': true,
        'reports_count': 0,
      })!;
      expect(c.code, 'air_conditioning');
      expect(c.nameAr, isNotEmpty);
      expect(c.role, StaffRole.maintenance);
      expect(c.isActive, isTrue);
    });

    test('a category with an unknown role still loads', () {
      final c = ReportCategory.fromJson({'id': 1, 'code': 'x', 'name': 'X', 'role': 'ops'})!;
      expect(c.role, isNull);
    });

    test('null in, null out', () {
      expect(ReportCategory.fromJson(null), isNull);
      expect(ReportCategory.fromJson({'code': 'x'}), isNull);
    });
  });
}
