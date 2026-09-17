import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:call_tracker/data/models.dart';

/// Shapes below are copied verbatim from live responses, so a backend field
/// rename shows up here rather than as an empty screen on a device.
void main() {
  group('Student.fromJson', () {
    test('maps the live /call-tracker/students shape', () {
      final json = jsonDecode('''
      {
        "student_id": 811,
        "first_name": "Omar",
        "last_name": "Benali",
        "level": "A1",
        "phone_numbers": [
          {"id": 44, "number": "0600000001", "type": "personal", "is_primary": true, "label": null}
        ],
        "last_call": {
          "id": 5002, "date": "2027-01-02T10:32:00.000Z",
          "reason": "Payment inquiry", "outcome": "Interested",
          "final_result": "...", "verdict": "answered_match", "summary": "note"
        }
      }''') as Map<String, dynamic>;

      final student = Student.fromJson(json);

      expect(student.id, '811');
      expect(student.name, 'Omar Benali');
      expect(student.level, 'A1');
      expect(student.phone, '0600000001');
      expect(student.lastCall!.date.toUtc().year, 2027);
      expect(student.lastCall!.outcome, 'Interested');
    });

    test('a student with no phone or no call does not blow up', () {
      final student = Student.fromJson({
        'student_id': 812,
        'first_name': 'Yasmine',
        'last_name': 'Kaci',
        'level': null,
        'phone_numbers': <dynamic>[],
        'last_call': null,
      });

      expect(student.phone, '');
      expect(student.hasPhone, isFalse);
      expect(student.level, 'Unknown');
      expect(student.lastCall, isNull);
    });

    test("dials the parent's line ahead of the personal one", () {
      final student = Student.fromJson({
        'student_id': 1,
        'first_name': 'A',
        'last_name': 'B',
        'phone_numbers': [
          {'number': '0600000001', 'type': 'personal', 'is_primary': true},
          {'number': '0611223344', 'type': 'parent', 'is_primary': false, 'label': 'father'},
        ],
      });

      expect(student.phone, '0611223344');
    });
  });

  test('Group.fromJson keeps type, category and teacher', () {
    final group = Group.fromJson({
      'id': 241,
      'name': 'English B1 - Evening',
      'state': 'running',
      'type': 'Onsite',
      'category': 'Language Level',
      'teacher_name': 'Fatima Benloucif',
      'studentCount': 14,
    });

    expect(group.id, '241');
    expect(group.type, 'Onsite');
    expect(group.category, 'Language Level');
    expect(group.teacherName, 'Fatima Benloucif');
    expect(group.studentCount, 14);
  });

  test('Paged reads the pagination block', () {
    final page = Paged.fromJson<Student>({
      'data': [
        {'student_id': 1, 'first_name': 'A', 'last_name': 'B', 'phone_numbers': <dynamic>[]},
      ],
      'pagination': {'page': 2, 'limit': 100, 'total': 2227, 'totalPages': 23},
    }, Student.fromJson);

    expect(page.items.single.id, '1');
    expect(page.page, 2);
    expect(page.totalPages, 23);
    expect(page.hasMore, isTrue);
  });

  test('LastCall formats the date the way both lists show it', () {
    final student = Student.fromJson({
      'student_id': 1,
      'first_name': 'A',
      'last_name': 'B',
      'phone_numbers': <dynamic>[],
      'last_call': {'date': '2027-01-02T10:32:00.000Z'},
    });

    expect(student.lastCall!.formattedDate, '02/01/2027');
  });
}
