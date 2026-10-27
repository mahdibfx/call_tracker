import 'package:flutter/material.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';

/// Where a report is in its life.
///
/// `review → processing → complete | not_complete`, and a closed report can be
/// reopened back to `processing`.
enum ReportState {
  review('review', 'In review'),
  processing('processing', 'In progress'),
  complete('complete', 'Completed'),
  notComplete('not_complete', 'Not completed');

  const ReportState(this.code, this.label);

  final String code;
  final String label;

  /// Null for a state this build does not know, so a new one added
  /// server-side renders as "unknown" rather than crashing the list.
  static ReportState? parse(Object? raw) {
    if (raw == null) return null;
    final key = raw.toString().trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');
    for (final state in values) {
      if (state.code == key) return state;
    }
    return null;
  }

  /// Closing states. The backend only accepts a result photo and description
  /// on a transition into one of these.
  bool get isClosing => this == complete || this == notComplete;

  /// The one place states are given a colour — four screens need the same
  /// mapping, and they must not drift apart.
  Color get color => switch (this) {
        ReportState.review => AppColors.amberColor,
        ReportState.processing => AppColors.primaryColor,
        ReportState.complete => AppColors.greenColor,
        ReportState.notComplete => AppColors.redColor,
      };

  Color get tint => switch (this) {
        ReportState.review => AppColors.amberColorLight,
        ReportState.processing => AppColors.primaryColorLight,
        ReportState.complete => AppColors.greenColorLight,
        ReportState.notComplete => AppColors.redColorLight,
      };
}

/// A kind of problem, and the role responsible for fixing it.
class ReportCategory {
  const ReportCategory({
    required this.id,
    required this.code,
    required this.name,
    this.nameAr,
    this.role,
    this.isActive = true,
    this.reportsCount = 0,
  });

  final int id;
  final String code;
  final String name;
  final String? nameAr;

  /// Who handles this category. Parsed through [StaffRole.parse], which is
  /// what reconciles the underscored spelling used here with the spaced one
  /// that login returns.
  final StaffRole? role;

  final bool isActive;
  final int reportsCount;

  static ReportCategory? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = int.tryParse('${json['id']}');
    if (id == null) return null;
    return ReportCategory(
      id: id,
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nameAr: json['name_ar']?.toString(),
      role: StaffRole.parse(json['role']),
      isActive: json['is_active'] != false,
      reportsCount: (json['reports_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A room a report can be pinned to.
class Room {
  const Room({
    required this.id,
    required this.roomIndex,
    this.floorNumber,
    this.capacity,
    this.type,
  });

  final int id;

  /// A label, not a number — the API returns strings like `R01`.
  final String roomIndex;
  final int? floorNumber;
  final int? capacity;
  final String? type;

  String get display =>
      floorNumber == null ? roomIndex : '$roomIndex · Floor $floorNumber';

  static Room? fromJson(Map<String, dynamic> json) {
    final id = int.tryParse('${json['id']}');
    if (id == null) return null;
    return Room(
      id: id,
      roomIndex: (json['room_index'] ?? '').toString(),
      floorNumber: (json['floor_number'] as num?)?.toInt(),
      capacity: (json['capacity'] as num?)?.toInt(),
      type: json['type']?.toString(),
    );
  }
}

/// Who filed or handled a report.
class ReportPerson {
  const ReportPerson({required this.name, this.userId, this.accountId, this.role});

  final String name;
  final String? userId;
  final String? accountId;
  final StaffRole? role;

  static ReportPerson? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final name = (json['name'] ?? '').toString();
    if (name.isEmpty) return null;
    return ReportPerson(
      name: name,
      userId: json['user_id']?.toString(),
      accountId: json['account_id']?.toString(),
      role: StaffRole.parse(json['role']),
    );
  }
}

/// One problem report.
class Report {
  const Report({
    required this.id,
    this.category,
    this.state,
    this.description,
    this.imageUrl,
    this.stateNote,
    this.confirmationDescription,
    this.confirmationImageUrl,
    this.reportedAt,
    this.stateChangedAt,
    this.room,
    this.reportedBy,
    this.confirmed = false,
  });

  final int id;
  final ReportCategory? category;
  final ReportState? state;
  final String? description;
  final String? imageUrl;

  /// An internal note left on the last transition.
  final String? stateNote;

  /// What was done, or why it could not be — only set once closed.
  final String? confirmationDescription;
  final String? confirmationImageUrl;

  final DateTime? reportedAt;
  final DateTime? stateChangedAt;
  final Room? room;
  final ReportPerson? reportedBy;

  /// Signed off by an admin.
  final bool confirmed;

  bool get hasResult =>
      (confirmationDescription?.isNotEmpty ?? false) || confirmationImageUrl != null;

  /// What the agent-facing card leads with when there is no photo.
  String get summaryLine {
    final text = description?.trim();
    if (text != null && text.isNotEmpty) return text;
    return category?.name ?? 'Report #$id';
  }

  /// Whether [user] may move this report along.
  ///
  /// Cosmetic only — the backend is the authority and answers 403 regardless.
  /// This exists so a cleaner is not shown buttons that cannot work, not as a
  /// security boundary, and the list itself is never filtered client-side.
  bool canBeHandledBy(Agent user) =>
      user.isAdmin || (category?.role != null && category!.role == user.role);

  static Report? fromJson(Map<String, dynamic> json) {
    final id = int.tryParse('${json['id']}');
    if (id == null) return null;
    return Report(
      id: id,
      category: ReportCategory.fromJson(json['category'] as Map<String, dynamic>?),
      state: ReportState.parse(json['state']),
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString(),
      stateNote: json['state_note']?.toString(),
      confirmationDescription: json['confirmation_description']?.toString(),
      confirmationImageUrl: json['confirmation_image_url']?.toString(),
      reportedAt: DateTime.tryParse('${json['reported_at'] ?? json['created_at']}'),
      stateChangedAt: DateTime.tryParse('${json['state_changed_at']}'),
      room: json['room'] is Map<String, dynamic>
          ? Room.fromJson(json['room'] as Map<String, dynamic>)
          : null,
      reportedBy: ReportPerson.fromJson(json['reported_by'] as Map<String, dynamic>?),
      confirmed: json['confirmed'] == true,
    );
  }
}

/// Per-category counts, for a handler's overview.
class ReportMetrics {
  const ReportMetrics({
    required this.categoryId,
    required this.categoryName,
    this.categoryCode,
    this.categoryRole,
    this.total = 0,
    this.review = 0,
    this.processing = 0,
    this.complete = 0,
    this.notComplete = 0,
  });

  final int categoryId;
  final String categoryName;
  final String? categoryCode;
  final StaffRole? categoryRole;
  final int total;
  final int review;
  final int processing;
  final int complete;
  final int notComplete;

  /// Still needing someone's attention.
  int get open => review + processing;

  static ReportMetrics? fromJson(Map<String, dynamic> json) {
    final id = int.tryParse('${json['category_id']}');
    if (id == null) return null;
    return ReportMetrics(
      categoryId: id,
      categoryName: (json['category_name'] ?? '').toString(),
      // The payload calls this `category`, not `category_code` as the docs
      // claim; read both so either spelling works.
      categoryCode: (json['category'] ?? json['category_code'])?.toString(),
      categoryRole: StaffRole.parse(json['category_role']),
      total: (json['total'] as num?)?.toInt() ?? 0,
      review: (json['review'] as num?)?.toInt() ?? 0,
      processing: (json['processing'] as num?)?.toInt() ?? 0,
      complete: (json['complete'] as num?)?.toInt() ?? 0,
      notComplete: (json['not_complete'] as num?)?.toInt() ?? 0,
    );
  }
}
