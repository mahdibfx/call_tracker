import 'package:flutter_test/flutter_test.dart';
import 'package:call_tracker/data/models.dart';

/// A row exactly as `GET /ManagementStudent/student-calls/:id` returns it.
Map<String, dynamic> row({
  Object? id = 1014,
  String startedAt = '1790159319150',
  String createdAt = '2026-09-23T09:28:50.882Z',
  Object? talk = 0,
  Object? calledBy = const {'name': 'Ikram B.', 'role': 'team onsite'},
}) => {
      'id': id,
      'agent_id': 4,
      'student_id': 3106,
      'student_name': 'Amine B.',
      'reason': 'Beginning of study session',
      'outcome': 'Interested',
      'notes': null,
      'really_dialed': true,
      'talk_duration_seconds': talk,
      'ring_session_seconds': 3,
      'likely_hung_up_early': true,
      'ended_quickly': false,
      'final_result': 'Agent called and cancelled almost immediately',
      'verdict': 'early_hangup',
      'started_at_epoch_ms': startedAt,
      'ended_at_epoch_ms': '1790159330411',
      'created_at': createdAt,
      'called_by': calledBy,
    };

void main() {
  test('reads the documented row, epoch arriving as a string', () {
    final call = StudentCall.fromJson(row())!;
    expect(call.id, 1014);
    expect(call.when.millisecondsSinceEpoch, 1790159319150);
    expect(call.reason, 'Beginning of study session');
    expect(call.outcome, 'Interested');
    expect(call.calledByName, 'Ikram B.');
    expect(call.wasAnswered, isFalse);
  });

  test('pre-September rows with epoch "0" fall back to created_at', () {
    final call = StudentCall.fromJson(row(startedAt: '0'))!;
    expect(call.when, DateTime.parse('2026-09-23T09:28:50.882Z'));
  });

  test('a row with no usable time is dropped rather than dated 1970', () {
    expect(StudentCall.fromJson(row(startedAt: '0', createdAt: 'not a date')), isNull);
    expect(StudentCall.fromJson(row(id: 'abc')), isNull);
  });

  test('a missing called_by is tolerated', () {
    expect(StudentCall.fromJson(row(calledBy: null))!.calledByName, isNull);
  });

  test('talk time drives answered, not the verdict fields', () {
    expect(StudentCall.fromJson(row(talk: 145))!.wasAnswered, isTrue);
    expect(StudentCall.fromJson(row(talk: 0))!.wasAnswered, isFalse);
  });
}
