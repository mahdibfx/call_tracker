enum CallReason {
  paymentInquiry('Payment inquiry', 'Payment Due'),
  beginningOfSession('Beginning of study session', 'New Session'),
  teacherAbsence('Teacher absence notification', 'Teacher Absent'),
  inquiryOnAbsences('Inquiry on absences', 'Absence Inquiry'),
  survey('Survey', 'Survey'),
  parentDidNotPickUp("Parent didn't pick up child", 'Pickup Missed'),

  /// Only ever set by the incoming-call flow — a parent ringing back after
  /// missing the agent's call. Never offered when choosing who to ring.
  returnedOurCall('Parent called back', 'Called Back', incomingOnly: true);

  const CallReason(this.label, this.chipLabel, {this.incomingOnly = false});
  final String label;
  final String chipLabel;

  /// True for reasons that describe a call the agent received rather than
  /// placed, so the outbound picker can leave them out.
  final bool incomingOnly;

  /// The reasons an agent can pick when starting a call himself.
  static List<CallReason> get outgoing =>
      values.where((r) => !r.incomingOnly).toList();
}

/// Who rang whom. An incoming call is one a parent placed to the agent —
/// usually returning a call they missed earlier.
enum CallDirection {
  outgoing,
  incoming;

  bool get isIncoming => this == CallDirection.incoming;
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
    this.direction = CallDirection.outgoing,
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
  final CallDirection direction;

  /// True when the call log doesn't back up what the agent reported —
  /// this is the "agent is lying" signal.
  ///
  /// The dial-side checks below don't apply to an incoming call — the agent
  /// never placed it, so he can't have faked placing it. What still applies is
  /// the answered-vs-claimed matrix: marking a call the parent never got
  /// through on as 'Interested' is the same overclaim in either direction.
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
    if (direction.isIncoming) {
      return talkDurationSeconds > 0
          ? 'Parent called the agent, call was answered, talked for ${_formatDuration(talkDurationSeconds)}'
          : 'Parent called the agent but the call was not answered';
    }
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
        CallVerdictKind.answeredMatch => direction.isIncoming
            ? 'Parent called in and was answered — talked ${talkDurationSeconds}s, matches agent report'
            : 'Answered — talked ${talkDurationSeconds}s, matches agent report',
        CallVerdictKind.notAnsweredMatch => direction.isIncoming
            ? "Parent called in but it wasn't answered — matches agent report"
            : 'Not answered${ringSessionSeconds != null ? " (rang ${ringSessionSeconds}s)" : ''} — matches agent report',
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
        'direction': direction.name,
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
        // Records written before incoming calls existed have no direction.
        direction: json['direction'] != null
            ? CallDirection.values.byName(json['direction'] as String)
            : CallDirection.outgoing,
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
