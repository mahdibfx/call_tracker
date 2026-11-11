/// Tasks given to a call agent: a list of students to ring, with a result
/// recorded against each one.
///
/// Only agents ever see these. The backend lets every role read and write
/// them, but an agent is the only person this app offers them to — see
/// `AppArea.forUser`.
library;

/// Where a task is in its life. The agent never sets this: the backend moves
/// the task to `inProgress` at the first result and to `done` when no student
/// is left pending.
enum TaskStatus {
  pending('pending', 'To do'),
  inProgress('in_progress', 'In progress'),
  done('done', 'Done'),
  cancelled('cancelled', 'Cancelled');

  const TaskStatus(this.code, this.label);

  final String code;
  final String label;

  bool get isOpen => this == pending || this == inProgress;

  static TaskStatus? parse(Object? raw) {
    if (raw == null) return null;
    final key = raw.toString().trim().toLowerCase();
    for (final s in values) {
      if (s.code == key) return s;
    }
    return null;
  }
}

enum TaskPriority {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  urgent('urgent', 'Urgent');

  const TaskPriority(this.code, this.label);

  final String code;
  final String label;

  /// Only the top two are worth colouring — marking everything urgent is how
  /// a priority flag stops meaning anything.
  bool get standsOut => this == high || this == urgent;

  static TaskPriority? parse(Object? raw) {
    if (raw == null) return null;
    final key = raw.toString().trim().toLowerCase();
    for (final p in values) {
      if (p.code == key) return p;
    }
    return null;
  }
}

/// What happened on one student's line.
enum TargetStatus {
  pending('pending', 'Not called'),
  done('done', 'Reached'),
  noAnswer('no_answer', 'No answer'),
  skipped('skipped', 'Skipped');

  const TargetStatus(this.code, this.label);

  final String code;
  final String label;

  static TargetStatus parse(Object? raw) {
    final key = raw?.toString().trim().toLowerCase();
    for (final s in values) {
      if (s.code == key) return s;
    }
    // An unknown result is safer read as "still to do" than as finished.
    return pending;
  }
}

/// How many students are in each result. Drives the progress bar.
class TargetsSummary {
  const TargetsSummary({
    required this.total,
    required this.pending,
    required this.done,
    required this.noAnswer,
    required this.skipped,
  });

  final int total;
  final int pending;
  final int done;
  final int noAnswer;
  final int skipped;

  int get handled => total - pending;

  /// 0 when the task has no students yet — the obvious formula divides by
  /// zero there, and a task with nothing in it is 0% done, not NaN.
  double get progress => total == 0 ? 0 : handled / total;

  static TargetsSummary fromJson(Map<String, dynamic>? json) {
    int at(String key) => (json?[key] as num?)?.toInt() ?? 0;
    return TargetsSummary(
      total: at('total'),
      pending: at('pending'),
      done: at('done'),
      noAnswer: at('no_answer'),
      skipped: at('skipped'),
    );
  }
}

/// The tab numbers. They follow every filter except the status itself, so
/// they stay put whichever tab is open.
class TaskCounts {
  const TaskCounts({
    this.pending = 0,
    this.inProgress = 0,
    this.done = 0,
    this.cancelled = 0,
    this.overdue = 0,
  });

  final int pending;
  final int inProgress;
  final int done;
  final int cancelled;
  final int overdue;

  int get open => pending + inProgress;

  int forStatus(TaskStatus status) => switch (status) {
        TaskStatus.pending => pending,
        TaskStatus.inProgress => inProgress,
        TaskStatus.done => done,
        TaskStatus.cancelled => cancelled,
      };

  static TaskCounts fromJson(Map<String, dynamic>? json) {
    int at(String key) => (json?[key] as num?)?.toInt() ?? 0;
    return TaskCounts(
      pending: at('pending'),
      inProgress: at('in_progress'),
      done: at('done'),
      cancelled: at('cancelled'),
      overdue: at('overdue'),
    );
  }
}

/// One student on a task, and what came of calling them.
class TaskTarget {
  const TaskTarget({
    required this.id,
    required this.position,
    required this.status,
    required this.studentId,
    required this.studentName,
    required this.phone,
    this.resultNote,
    this.doneByName,
    this.doneAt,
  });

  final int id;
  final int position;
  final TargetStatus status;

  /// The call-tracker student id, as a string — that is what the rest of the
  /// app keys students on.
  final String studentId;
  final String studentName;
  final String phone;
  final String? resultNote;
  final String? doneByName;
  final DateTime? doneAt;

  bool get hasPhone => phone.isNotEmpty;

  /// Null when the row carries no usable id — rendering a target we cannot
  /// write a result back to would be a dead row.
  static TaskTarget? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt();
    if (id == null) return null;
    final student = json['student'] as Map<String, dynamic>?;
    final doneBy = json['done_by'] as Map<String, dynamic>?;
    return TaskTarget(
      id: id,
      position: (json['position'] as num?)?.toInt() ?? 0,
      status: TargetStatus.parse(json['status']),
      studentId: '${student?['id'] ?? ''}',
      studentName: student?['name']?.toString() ?? 'Student',
      phone: student?['phone_number']?.toString() ?? '',
      resultNote: json['result_note']?.toString(),
      doneByName: doneBy?['name']?.toString(),
      doneAt: DateTime.tryParse('${json['done_at']}')?.toLocal(),
    );
  }
}

/// A task as the list shows it. [targets] is filled only by `GET /tasks/:id`.
class Task {
  const Task({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.summary,
    this.description,
    this.dueDate,
    this.overdue = false,
    this.typeName,
    this.createdByName,
    this.cancelReason,
    this.targets = const [],
  });

  final int id;
  final String title;
  final TaskStatus? status;
  final TaskPriority? priority;
  final TargetsSummary summary;
  final String? description;

  /// Already converted to the device's zone, which for this institute is
  /// Algiers — the backend sends UTC.
  final DateTime? dueDate;
  final bool overdue;
  final String? typeName;
  final String? createdByName;
  final String? cancelReason;
  final List<TaskTarget> targets;

  bool get isOpen => status?.isOpen ?? false;

  /// The next student to ring: the first one still pending, in the order the
  /// office put them in.
  TaskTarget? get nextUp {
    for (final t in targets) {
      if (t.status == TargetStatus.pending) return t;
    }
    return null;
  }

  static Task? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt();
    if (id == null) return null;
    final type = json['type'] as Map<String, dynamic>?;
    final createdBy = json['created_by'] as Map<String, dynamic>?;
    final rawTargets = json['targets'] as List<dynamic>?;
    return Task(
      id: id,
      title: json['title']?.toString() ?? 'Task #$id',
      status: TaskStatus.parse(json['status']),
      priority: TaskPriority.parse(json['priority']),
      summary: TargetsSummary.fromJson(json['targets_summary'] as Map<String, dynamic>?),
      description: json['description']?.toString(),
      dueDate: DateTime.tryParse('${json['due_date']}')?.toLocal(),
      overdue: json['overdue'] == true,
      typeName: type?['name']?.toString(),
      createdByName: createdBy?['name']?.toString(),
      cancelReason: json['cancel_reason']?.toString(),
      targets: (rawTargets ?? [])
          .map((e) => TaskTarget.fromJson(e as Map<String, dynamic>))
          .whereType<TaskTarget>()
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position)),
    );
  }
}
