enum CallReason {
  paymentInquiry('Payment inquiry', 'Payment Due'),
  beginningOfSession('Beginning of study session', 'New Session'),
  teacherAbsence('Teacher absence notification', 'Teacher Absent'),
  inquiryOnAbsences('Inquiry on absences', 'Absence Inquiry'),
  survey('Survey', 'Survey'),
  parentDidNotPickUp("Parent didn't pick up child", 'Pickup Missed');

  const CallReason(this.label, this.chipLabel);
  final String label;
  final String chipLabel;
}

enum CallOutcome {
  interested('Interested'),
  notInterested('Not Interested'),
  comingToInstitute('Coming to institute'),
  informationDiscussed('Information discussed'),
  couldNotReach("Couldn't reach"),
  followUpRequired('Follow-up required');

  const CallOutcome(this.label);
  final String label;
}

class Student {
  const Student({
    required this.id,
    required this.name,
    required this.phone,
    required this.level,
    required this.parentName,
    required this.studentId,
  });

  final String id;
  final String name;
  final String phone;
  final String level;
  final String parentName;
  final String studentId;
}

/// Result of cross-checking a call against the device's own call log —
/// this is what tells us whether an agent actually placed the call.
class CallVerification {
  const CallVerification({
    required this.reallyDialed,
    required this.talkDurationSeconds,
    required this.suspicious,
    required this.note,
  });

  final bool reallyDialed;
  final int talkDurationSeconds;
  final bool suspicious;
  final String note;
}

enum CallVerdictKind { answeredMatch, notAnsweredMatch, noCallDetected, mismatchOverclaimed, mismatchUnderclaimed }

/// A finished, agent-reported call cross-checked against the call log —
/// this is the record the test-mode monitor screen reads.
class CallRecord {
  const CallRecord({
    required this.studentId,
    required this.studentName,
    required this.reason,
    required this.outcome,
    required this.reallyDialed,
    required this.talkDurationSeconds,
    required this.timestampEpochMs,
  });

  final String studentId;
  final String studentName;
  final CallReason reason;
  final CallOutcome? outcome;
  final bool reallyDialed;
  final int talkDurationSeconds;
  final int timestampEpochMs;

  /// True when the call log doesn't back up what the agent reported —
  /// this is the "agent is lying" signal.
  CallVerdictKind get verdictKind {
    if (!reallyDialed) return CallVerdictKind.noCallDetected;
    final answered = talkDurationSeconds > 0;
    final claimedReached = outcome != null && outcome != CallOutcome.couldNotReach;
    if (answered && claimedReached) return CallVerdictKind.answeredMatch;
    if (answered && !claimedReached) return CallVerdictKind.mismatchUnderclaimed;
    if (!answered && !claimedReached) return CallVerdictKind.notAnsweredMatch;
    return CallVerdictKind.mismatchOverclaimed;
  }

  bool get isFlagged =>
      verdictKind == CallVerdictKind.noCallDetected || verdictKind == CallVerdictKind.mismatchOverclaimed;

  String get verdictLabel => switch (verdictKind) {
        CallVerdictKind.answeredMatch => 'Answered — talked ${talkDurationSeconds}s, matches agent report',
        CallVerdictKind.notAnsweredMatch => 'Not answered — matches agent report',
        CallVerdictKind.noCallDetected => 'No call was ever placed to this number',
        CallVerdictKind.mismatchUnderclaimed =>
          "Call connected (${talkDurationSeconds}s) but agent marked '${outcome?.label ?? '—'}'",
        CallVerdictKind.mismatchOverclaimed =>
          "Not answered, but agent marked '${outcome?.label ?? '—'}' — flagged as lying",
      };

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'studentName': studentName,
        'reason': reason.name,
        'outcome': outcome?.name,
        'reallyDialed': reallyDialed,
        'talkDurationSeconds': talkDurationSeconds,
        'timestampEpochMs': timestampEpochMs,
      };

  factory CallRecord.fromJson(Map<String, dynamic> json) => CallRecord(
        studentId: json['studentId'] as String,
        studentName: json['studentName'] as String,
        reason: CallReason.values.byName(json['reason'] as String),
        outcome: json['outcome'] != null ? CallOutcome.values.byName(json['outcome'] as String) : null,
        reallyDialed: json['reallyDialed'] as bool,
        talkDurationSeconds: json['talkDurationSeconds'] as int,
        timestampEpochMs: json['timestampEpochMs'] as int,
      );
}

class Group {
  const Group({required this.name, required this.studentCount, required this.studentIds});

  final String name;
  final int studentCount;
  final List<String> studentIds;
}
