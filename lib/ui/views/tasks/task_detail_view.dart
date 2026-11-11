import 'package:flutter/material.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/task_api.dart';
import 'package:call_tracker/data/task_models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/views/call/call_view.dart';
import 'package:call_tracker/ui/views/reports/widgets/report_card.dart';
import 'package:call_tracker/ui/views/tasks/widgets/result_sheet.dart';
import 'package:call_tracker/ui/widgets/app_top_bar.dart';
import 'package:call_tracker/ui/widgets/avatar_circle.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

/// One task: the students to ring, in the order the office put them in, and
/// what happened on each line.
///
/// The agent never moves the task itself — recording the last result is what
/// finishes it, at the backend.
class TaskDetailView extends StatefulWidget {
  const TaskDetailView({super.key, required this.task});

  /// The list row that was tapped. It carries no targets, so the full task is
  /// fetched on open; this is what fills the screen in the meantime.
  final Task task;

  @override
  State<TaskDetailView> createState() => _TaskDetailViewState();
}

class _TaskDetailViewState extends State<TaskDetailView> {
  late Task _task = widget.task;
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final full = await TaskApi.getTask(widget.task.id);
    if (!mounted) return;
    setState(() {
      if (full != null) _task = full;
      _loading = false;
    });
  }

  /// Hands the student to the normal call flow, so a task call is tracked and
  /// verified exactly like any other.
  ///
  /// ponytail: the call is not linked back to the target (`call_id` stays
  /// null). CallSummaryView unwinds to the root when it submits, so carrying
  /// the new call's id back here means changing that unwind — a change to the
  /// one flow that cannot be unit-tested. Record the result by hand for now;
  /// wire `call_id` when the unwind is revisited.
  Future<void> _call(TaskTarget target) async {
    final student = Student(
      id: target.studentId,
      name: target.studentName,
      level: '',
      phones: [
        StudentPhone(number: target.phone, type: 'personal', isPrimary: true),
      ],
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallView(
          student: student,
          // The office's instruction is the task's own title; this picks the
          // closest of the fixed reasons rather than inventing one.
          reason: CallReason.inquiryOnAbsences,
          number: target.phone,
        ),
      ),
    );
  }

  Future<void> _recordResult(TaskTarget target) async {
    final result = await showResultSheet(context, target);
    if (!mounted || result == null) return;

    final error = await TaskApi.setTargetResult(
      _task.id,
      target.id,
      status: result.status,
      note: result.note,
    );
    if (!mounted) return;
    if (error != null) {
      showTopSnackBar(
        Overlay.of(context),
        CustomSnackBar.error(message: error),
      );
      return;
    }
    _changed = true;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: const AppTopBar(title: 'Task'),
        body: _loading && _task.targets.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primaryColor,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _header(),
                    verticalSpaceMedium,
                    CustomText.bodyBold(
                      text: 'Students (${_task.summary.total})',
                      fontSize: 14,
                    ),
                    verticalSpaceSmall,
                    if (_task.targets.isEmpty)
                      CustomText.subtitle(
                        text: 'Nobody has been added to this task yet.',
                      )
                    else
                      for (final target in _task.targets) ...[
                        _TargetTile(
                          target: target,
                          // A cancelled task is read-only: the backend answers
                          // 409 on any result, so offering the buttons would
                          // only produce an error.
                          actionable: _task.status != TaskStatus.cancelled,
                          onCall: () => _call(target),
                          onRecord: () => _recordResult(target),
                        ),
                        verticalSpaceSmall,
                      ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _header() {
    final summary = _task.summary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadiusLargeValue),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText.bodyBold(text: _task.title, fontSize: 17),
          if (_task.description != null && _task.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            CustomText.body(
              text: _task.description!,
              fontSize: 13,
              textColor: AppColors.secondaryColor,
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: summary.progress,
              minHeight: 6,
              backgroundColor: AppColors.borderColor,
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryColor),
            ),
          ),
          const SizedBox(height: 8),
          CustomText.caption(
            text: '${summary.handled} of ${summary.total} called'
                '${summary.noAnswer > 0 ? ' · ${summary.noAnswer} no answer' : ''}'
                '${summary.skipped > 0 ? ' · ${summary.skipped} skipped' : ''}',
          ),
          if (_task.dueDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 13,
                  color: _task.overdue ? AppColors.redColor : AppColors.secondaryColor,
                ),
                horizontalSpaceTiny,
                CustomText.caption(
                  text: _task.overdue
                      ? 'Was due ${ReportCard.formatWhen(_task.dueDate)}'
                      : 'Due ${ReportCard.formatWhen(_task.dueDate)}',
                  textColor: _task.overdue ? AppColors.redColor : null,
                ),
              ],
            ),
          ],
          if (_task.createdByName != null) ...[
            const SizedBox(height: 4),
            CustomText.caption(text: 'From ${_task.createdByName}'),
          ],
          if (_task.status == TaskStatus.cancelled) ...[
            const SizedBox(height: 8),
            CustomText.caption(
              text: 'This task was cancelled'
                  '${_task.cancelReason != null ? ' — ${_task.cancelReason}' : ''}.',
              textColor: AppColors.redColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({
    required this.target,
    required this.actionable,
    required this.onCall,
    required this.onRecord,
  });

  final TaskTarget target;
  final bool actionable;
  final VoidCallback onCall;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final done = target.status != TargetStatus.pending;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadiusLargeValue),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AvatarCircle(name: target.studentName, size: 38),
              horizontalSpaceSmall,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.bodyBold(
                      text: target.studentName,
                      fontSize: 14,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    CustomText.caption(
                      text: target.hasPhone ? target.phone : 'No number on file',
                    ),
                  ],
                ),
              ),
              _ResultChip(status: target.status),
            ],
          ),
          if (target.resultNote != null && target.resultNote!.isNotEmpty) ...[
            verticalSpaceSmall,
            Align(
              alignment: Alignment.centerLeft,
              child: CustomText.caption(text: '“${target.resultNote}”'),
            ),
          ],
          if (actionable) ...[
            verticalSpaceSmall,
            Row(
              children: [
                Expanded(
                  child: _Action(
                    icon: Icons.call,
                    // Once there is a result, calling again is a second
                    // attempt rather than the main action.
                    label: done ? 'Call again' : 'Call',
                    primary: !done,
                    onTap: target.hasPhone ? onCall : null,
                  ),
                ),
                horizontalSpaceSmall,
                Expanded(
                  child: _Action(
                    icon: Icons.edit_note,
                    label: done ? 'Change result' : 'Record result',
                    primary: done,
                    onTap: onRecord,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.status});

  final TargetStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TargetStatus.done => AppColors.greenColor,
      TargetStatus.noAnswer => AppColors.amberColor,
      TargetStatus.skipped => AppColors.secondaryColor,
      TargetStatus.pending => AppColors.secondaryColor,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: CustomText.caption(text: status.label, textColor: color),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool primary;

  /// Null disables it — a student with no number cannot be rung.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = !enabled
        ? AppColors.secondaryColor
        : primary
            ? AppColors.primaryColor
            : AppColors.secondaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: primary && enabled ? AppColors.primaryColorLight : AppColors.cardColor,
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
          border: Border.all(
            color: primary && enabled ? AppColors.primaryColor : AppColors.borderColor,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            horizontalSpaceTiny,
            CustomText.caption(text: label, textColor: color),
          ],
        ),
      ),
    );
  }
}
