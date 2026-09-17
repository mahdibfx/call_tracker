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

class Agent {
  const Agent({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};

  factory Agent.fromJson(Map<String, dynamic> json) => Agent(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
      );
}

/// One number on a student's file. `type` is `personal` or `parent`.
class StudentPhone {
  const StudentPhone({
    required this.number,
    required this.type,
    required this.isPrimary,
    this.label,
  });

  final String number;
  final String type;
  final bool isPrimary;
  final String? label;

  bool get isParentLine => type == 'parent';

  factory StudentPhone.fromJson(Map<String, dynamic> json) => StudentPhone(
        number: (json['number'] ?? '').toString(),
        type: (json['type'] ?? 'personal').toString(),
        isPrimary: json['is_primary'] == true,
        label: json['label'] as String?,
      );
}

/// The most recent call on a student's record, as the backend reports it.
/// `verdict` is computed server-side and must never reach agent-facing UI.
class LastCall {
  const LastCall({required this.date, this.reason, this.outcome, this.summary});

  final DateTime date;
  final String? reason;
  final String? outcome;
  final String? summary;

  /// `02/01/2027` — the form shown under a student's name in both lists.
  String get formattedDate {
    final d = date.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  static LastCall? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final raw = json['date'];
    if (raw == null) return null;
    final date = DateTime.tryParse(raw.toString());
    if (date == null) return null;
    return LastCall(
      date: date,
      reason: json['reason'] as String?,
      outcome: json['outcome'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class Student {
  const Student({
    required this.id,
    required this.name,
    required this.level,
    required this.phones,
    this.lastCall,
  });

  final String id;
  final String name;
  final String level;
  final List<StudentPhone> phones;
  final LastCall? lastCall;

  /// The number the dialer should call. A line explicitly marked as the
  /// parent's wins — that's who the agent is trying to reach — then the
  /// primary, then whatever exists.
  String get phone {
    if (phones.isEmpty) return '';
    for (final p in phones) {
      if (p.isParentLine && p.isPrimary) return p.number;
    }
    for (final p in phones) {
      if (p.isParentLine) return p.number;
    }
    for (final p in phones) {
      if (p.isPrimary) return p.number;
    }
    return phones.first.number;
  }

  bool get hasPhone => phone.isNotEmpty;

  factory Student.fromJson(Map<String, dynamic> json) {
    final first = (json['first_name'] ?? '').toString().trim();
    final last = (json['last_name'] ?? '').toString().trim();
    final name = [first, last].where((p) => p.isNotEmpty).join(' ');
    return Student(
      id: json['student_id'].toString(),
      name: name.isEmpty ? 'Unnamed student' : name,
      level: (json['level'] as String?)?.trim().isNotEmpty == true
          ? json['level'] as String
          : 'Unknown',
      phones: (json['phone_numbers'] as List<dynamic>? ?? [])
          .map((p) => StudentPhone.fromJson(p as Map<String, dynamic>))
          .toList(),
      lastCall: LastCall.fromJson(json['last_call'] as Map<String, dynamic>?),
    );
  }
}

/// One page of a paginated list endpoint.
class Paged<T> {
  const Paged({required this.items, required this.page, required this.totalPages});

  final List<T> items;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;

  static Paged<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final pagination = json['pagination'] as Map<String, dynamic>? ?? const {};
    return Paged<T>(
      items: (json['data'] as List<dynamic>? ?? [])
          .map((e) => itemFromJson(e as Map<String, dynamic>))
          .toList(),
      page: (pagination['page'] as num?)?.toInt() ?? 1,
      totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Result of cross-checking a call against the device's own call log —
/// this is what tells us whether an agent actually placed the call.
class CallVerification {
  const CallVerification({
    required this.reallyDialed,
    required this.talkDurationSeconds,
    required this.suspicious,
    required this.note,
    this.likelyHungUpEarly = false,
    this.endedQuickly = false,
    this.ringSessionSeconds,
  });

  final bool reallyDialed;
  final int talkDurationSeconds;
  final bool suspicious;
  final String note;

  /// True when the call log shows 0s talk time AND the device's own call
  /// session (dial to hang-up, timed locally) was too short to have
  /// actually rung — the "agent hung up before it could ring" signature,
  /// as opposed to a genuine unanswered call that rang for a while.
  final bool likelyHungUpEarly;

  /// True for the ambiguous middle zone: long enough it might have rung
  /// briefly, short enough it might not have. Could be the parent declining
  /// quickly or the agent hanging up early — genuinely can't tell which
  /// without becoming the device's default dialer, so this is surfaced
  /// as "needs review", not asserted as either.
  final bool endedQuickly;

  /// How long the device was actually in an active call session, timed
  /// locally via phone_state. Null when that timing wasn't observed
  /// (e.g. reconciled after the app process was killed mid-call).
  final int? ringSessionSeconds;
}

enum CallVerdictKind {
  answeredMatch,
  notAnsweredMatch,
  noCallDetected,
  mismatchOverclaimed,
  mismatchUnderclaimed,
  earlyHangup,
  endedQuickly,
}

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
    this.agentId,
    this.agentName,
    this.notes,
    this.likelyHungUpEarly = false,
    this.endedQuickly = false,
    this.ringSessionSeconds,
  });

  final String studentId;
  final String studentName;
  final CallReason reason;
  final CallOutcome? outcome;
  final bool reallyDialed;
  final int talkDurationSeconds;
  final int timestampEpochMs;
  final String? agentId;
  final String? agentName;
  final String? notes;
  final bool likelyHungUpEarly;
  final bool endedQuickly;
  final int? ringSessionSeconds;

  /// True when the call log doesn't back up what the agent reported —
  /// this is the "agent is lying" signal.
  CallVerdictKind get verdictKind {
    if (!reallyDialed) return CallVerdictKind.noCallDetected;
    if (likelyHungUpEarly) return CallVerdictKind.earlyHangup;
    if (endedQuickly) return CallVerdictKind.endedQuickly;
    final answered = talkDurationSeconds > 0;
    final claimedReached = outcome != null && outcome != CallOutcome.couldNotReach;
    if (answered && claimedReached) return CallVerdictKind.answeredMatch;
    if (answered && !claimedReached) return CallVerdictKind.mismatchUnderclaimed;
    if (!answered && !claimedReached) return CallVerdictKind.notAnsweredMatch;
    return CallVerdictKind.mismatchOverclaimed;
  }

  bool get isFlagged =>
      verdictKind == CallVerdictKind.noCallDetected ||
      verdictKind == CallVerdictKind.mismatchOverclaimed ||
      verdictKind == CallVerdictKind.earlyHangup;

  /// Ambiguous, not a confirmed problem — worth a supervisor's eyes, but
  /// shouldn't be styled or counted the same as a confirmed flag.
  bool get needsReview => verdictKind == CallVerdictKind.endedQuickly;

  /// One short phrase describing what actually happened on the call —
  /// the field meant for the backend payload. Purely about call mechanics
  /// (was it placed, did it ring, was it answered, how long); it doesn't
  /// judge the agent's reported outcome — see [verdictLabel] for that.
  String get finalResult {
    if (!reallyDialed) return 'Agent never actually placed the call';
    if (likelyHungUpEarly) return 'Agent called and cancelled almost immediately';
    if (endedQuickly) return 'Call ended quickly — could be a decline or an early hangup';
    if (talkDurationSeconds <= 0) {
      return ringSessionSeconds != null
          ? 'Call rang for ${ringSessionSeconds}s but was not answered'
          : 'Call was not answered';
    }
    return 'Agent called, call was answered, talked for ${_formatDuration(talkDurationSeconds)}';
  }

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}min';
    return '${m}min ${s}s';
  }

  String get verdictLabel => switch (verdictKind) {
        CallVerdictKind.answeredMatch => 'Answered — talked ${talkDurationSeconds}s, matches agent report',
        CallVerdictKind.notAnsweredMatch => 'Not answered${ringSessionSeconds != null ? " (rang ${ringSessionSeconds}s)" : ''} — matches agent report',
        CallVerdictKind.noCallDetected => 'No call was ever placed to this number',
        CallVerdictKind.mismatchUnderclaimed =>
          "Call connected (${talkDurationSeconds}s) but agent marked '${outcome?.label ?? '—'}'",
        CallVerdictKind.mismatchOverclaimed =>
          "Not answered, but agent marked '${outcome?.label ?? '—'}' — flagged as lying",
        CallVerdictKind.earlyHangup =>
          'Ended after only ${ringSessionSeconds}s — too quick to have rung, likely hung up immediately',
        CallVerdictKind.endedQuickly =>
          'Ended quickly after ${ringSessionSeconds}s — could be a decline or an early hangup, can\'t tell which',
      };

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'studentName': studentName,
        'reason': reason.name,
        'outcome': outcome?.name,
        'notes': notes,
        'reallyDialed': reallyDialed,
        'talkDurationSeconds': talkDurationSeconds,
        'timestampEpochMs': timestampEpochMs,
        'agentId': agentId,
        'agentName': agentName,
        'likelyHungUpEarly': likelyHungUpEarly,
        'endedQuickly': endedQuickly,
        'ringSessionSeconds': ringSessionSeconds,
        'finalResult': finalResult,
      };

  factory CallRecord.fromJson(Map<String, dynamic> json) => CallRecord(
        studentId: json['studentId'] as String,
        studentName: json['studentName'] as String,
        reason: CallReason.values.byName(json['reason'] as String),
        agentId: json['agentId'] as String?,
        agentName: json['agentName'] as String?,
        notes: json['notes'] as String?,
        likelyHungUpEarly: json['likelyHungUpEarly'] as bool? ?? false,
        endedQuickly: json['endedQuickly'] as bool? ?? false,
        ringSessionSeconds: json['ringSessionSeconds'] as int?,
        outcome: json['outcome'] != null ? CallOutcome.values.byName(json['outcome'] as String) : null,
        reallyDialed: json['reallyDialed'] as bool,
        talkDurationSeconds: json['talkDurationSeconds'] as int,
        timestampEpochMs: json['timestampEpochMs'] as int,
      );
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.studentCount,
    required this.type,
    required this.category,
    required this.teacherName,
    required this.state,
  });

  final String id;
  final String name;
  final int studentCount;

  /// Delivery type — `Onsite` or `Online`.
  final String type;

  /// The "featuring" bucket, e.g. `Language Level`, `Summer Camp`.
  final String category;
  final String teacherName;

  /// `running`, `waiting to complete` or `stopped`.
  final String state;

  /// The roster is not part of this payload — fetch it per group with
  /// `ApiService.getGroupStudents(id)`.
  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'].toString(),
        name: (json['name'] ?? '').toString(),
        studentCount: (json['studentCount'] as num?)?.toInt() ?? 0,
        type: (json['type'] as String?)?.trim() ?? '',
        category: (json['category'] as String?)?.trim() ?? '',
        teacherName: (json['teacher_name'] as String?)?.trim() ?? '',
        state: (json['state'] as String?)?.trim() ?? '',
      );
}
