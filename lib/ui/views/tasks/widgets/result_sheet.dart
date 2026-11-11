import 'package:flutter/material.dart';
import 'package:call_tracker/data/task_models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/widgets/custom_button.dart';
import 'package:call_tracker/ui/widgets/custom_input.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// What the agent recorded against one student.
class TargetResult {
  const TargetResult({required this.status, this.note});

  final TargetStatus status;
  final String? note;
}

/// Asks what happened on this student's line. Null if the agent backed out.
Future<TargetResult?> showResultSheet(BuildContext context, TaskTarget target) {
  return showModalBottomSheet<TargetResult>(
    context: context,
    backgroundColor: AppColors.cardColor,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppStyles.borderRadiusLargeValue),
      ),
    ),
    builder: (_) => _ResultSheet(target: target),
  );
}

class _ResultSheet extends StatefulWidget {
  const _ResultSheet({required this.target});

  final TaskTarget target;

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> {
  late final _noteController =
      TextEditingController(text: widget.target.resultNote ?? '');

  /// Pre-selected to whatever is already recorded, so changing a result is a
  /// one-tap correction rather than a re-entry.
  late TargetStatus _status = widget.target.status == TargetStatus.pending
      ? TargetStatus.done
      : widget.target.status;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet above the keyboard while the note is being typed.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomText.bodyBold(
                text: 'How did it go with ${widget.target.studentName}?',
                fontSize: 16,
                maxLines: 2,
              ),
              verticalSpaceMedium,
              // `pending` is deliberately not offered: putting a student back
              // to "not called" is undoing, not a result.
              for (final status in const [
                TargetStatus.done,
                TargetStatus.noAnswer,
                TargetStatus.skipped,
              ]) ...[
                _StatusOption(
                  status: status,
                  selected: _status == status,
                  onTap: () => setState(() => _status = status),
                ),
                verticalSpaceSmall,
              ],
              verticalSpaceSmall,
              CustomText.caption(text: 'Note (optional)'),
              const SizedBox(height: 6),
              CustomInput(
                controller: _noteController,
                hintText: 'What was said…',
                maxLines: 3,
              ),
              verticalSpaceMedium,
              CustomButton(
                text: 'Save result',
                onPressed: () => Navigator.of(context).pop(
                  TargetResult(status: _status, note: _noteController.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final TargetStatus status;
  final bool selected;
  final VoidCallback onTap;

  static const _icons = {
    TargetStatus.done: Icons.check_circle_outline,
    TargetStatus.noAnswer: Icons.phone_missed_outlined,
    TargetStatus.skipped: Icons.skip_next_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryColor : AppColors.secondaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryColorLight : AppColors.cardColor,
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
          border: Border.all(
            color: selected ? AppColors.primaryColor : AppColors.borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(_icons[status] ?? Icons.circle_outlined, size: 19, color: color),
            horizontalSpaceSmall,
            Expanded(
              child: CustomText.body(
                text: status.label,
                fontSize: 14,
                textColor: selected ? AppColors.primaryColor : AppColors.textColor,
              ),
            ),
            if (selected)
              const Icon(Icons.check, size: 17, color: AppColors.primaryColor),
          ],
        ),
      ),
    );
  }
}
