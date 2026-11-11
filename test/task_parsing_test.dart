import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/task_models.dart';

/// Shapes taken from the live `GET /tasks` and `GET /tasks/:id` payloads.
void main() {
  group('Task.fromJson', () {
    test('reads a full task', () {
      final task = Task.fromJson(jsonDecode('''
        {
          "id": 12, "title": "Call the absents", "description": "ENG 3AS G1",
          "status": "in_progress", "priority": "urgent",
          "due_date": "2026-11-05T16:00:00.000Z", "overdue": false,
          "type": {"id": 1, "code": "call_student", "name": "Call students"},
          "created_by": {"account_id": 2, "name": "Mouna K."},
          "targets_summary": {"total": 8, "pending": 3, "done": 4, "no_answer": 1, "skipped": 0}
        }
      ''') as Map<String, dynamic>)!;

      expect(task.id, 12);
      expect(task.status, TaskStatus.inProgress);
      expect(task.priority, TaskPriority.urgent);
      expect(task.createdByName, 'Mouna K.');
      expect(task.summary.handled, 5);
      expect(task.isOpen, isTrue);
    });

    test('survives every nullable field being absent', () {
      final task = Task.fromJson({'id': 4})!;
      expect(task.title, 'Task #4');
      expect(task.status, isNull);
      expect(task.priority, isNull);
      expect(task.dueDate, isNull);
      expect(task.summary.total, 0);
      expect(task.targets, isEmpty);
    });

    test('a row with no id is dropped rather than rendered blank', () {
      expect(Task.fromJson({'title': 'orphan'}), isNull);
    });

    test('an unknown status or priority reads as null, not a crash', () {
      final task = Task.fromJson({'id': 1, 'status': 'archived', 'priority': 'huge'})!;
      expect(task.status, isNull);
      expect(task.priority, isNull);
      expect(task.isOpen, isFalse);
    });
  });

  group('targets', () {
    test('are sorted by position and read their student', () {
      final task = Task.fromJson(jsonDecode('''
        {
          "id": 12, "title": "t", "targets": [
            {"id": 52, "position": 1, "status": "pending",
             "student": {"id": 321, "name": "Bilal R.", "phone_number": "0551112223"}},
            {"id": 51, "position": 0, "status": "done", "result_note": "will pay Sunday",
             "student": {"id": 320, "name": "Amine S.", "phone_number": "0550000000"},
             "done_by": {"account_id": 14, "name": "Mouna K."},
             "done_at": "2026-11-04T10:12:00.000Z"}
          ]
        }
      ''') as Map<String, dynamic>)!;

      expect(task.targets.map((t) => t.id), [51, 52]);
      expect(task.targets.first.studentId, '320');
      expect(task.targets.first.status, TargetStatus.done);
      expect(task.targets.first.resultNote, 'will pay Sunday');
      expect(task.targets.first.doneByName, 'Mouna K.');
      // The next student to ring is the first still pending, in office order.
      expect(task.nextUp?.id, 52);
    });

    test('an unknown target status reads as pending, never as finished', () {
      expect(TargetStatus.parse('escalated'), TargetStatus.pending);
      expect(TargetStatus.parse(null), TargetStatus.pending);
    });

    test('a student with no number is still listed, but cannot be called', () {
      final target = TaskTarget.fromJson({
        'id': 9,
        'status': 'pending',
        'student': {'id': 1, 'name': 'No Phone'},
      })!;
      expect(target.hasPhone, isFalse);
    });
  });

  group('progress', () {
    test('an empty task is 0%, not NaN', () {
      const summary = TargetsSummary(
          total: 0, pending: 0, done: 0, noAnswer: 0, skipped: 0);
      expect(summary.progress, 0);
      expect(summary.progress.isNaN, isFalse);
    });

    test('counts every recorded result as handled, not just the reached ones', () {
      const summary = TargetsSummary(
          total: 4, pending: 1, done: 1, noAnswer: 1, skipped: 1);
      expect(summary.handled, 3);
      expect(summary.progress, 0.75);
    });
  });

  group('pagination', () {
    // /tasks pages with a `pagination` object; /reports puts its numbers flat.
    // Reading one with the other's parser silently yields a single page, which
    // is how an infinite scroll ends up stranded on page 1.
    test('reads the tasks envelope, which /reports\' parser would not', () {
      final inner = jsonDecode('''
        {"scope": "mine", "data": [],
         "pagination": {"page": 2, "limit": 20, "total": 45, "totalPages": 3,
                        "hasNext": true, "hasPrev": true}}
      ''') as Map<String, dynamic>;

      final page = Paged.fromJsonItems<Task>(inner, const []);
      expect(page.page, 2);
      expect(page.totalPages, 3);
      expect(page.hasMore, isTrue);

      // The flat parser finds no `total`/`limit` here and strands the scroll.
      expect(Paged.fromFlatItems<Task>(inner, const []).totalPages, 1);
    });
  });

  group('counts', () {
    test('drive the tab numbers, with the open tabs summed', () {
      final counts = TaskCounts.fromJson(jsonDecode(
        '{"pending": 2, "in_progress": 1, "done": 4, "cancelled": 0, "overdue": 1}',
      ) as Map<String, dynamic>);

      expect(counts.open, 3);
      expect(counts.forStatus(TaskStatus.done), 4);
      expect(counts.overdue, 1);
    });

    test('an absent counts block is zeros, not a crash', () {
      const counts = TaskCounts();
      expect(counts.open, 0);
      expect(TaskCounts.fromJson(null).done, 0);
    });
  });
}
