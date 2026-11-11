import 'package:flutter/material.dart';
import 'package:call_tracker/data/task_models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/views/reports/widgets/report_card.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// One task in the list: what it is, when it is due, and how far through it
/// the agent is.
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = task.summary;
    final priority = task.priority;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusLargeValue),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusLargeValue),
          border: Border.all(
            // A late task earns a red edge; nothing else does, so it reads at
            // a glance down a list.
            color: task.overdue ? AppColors.redColor : AppColors.borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CustomText.bodyBold(text: task.title, fontSize: 15, maxLines: 2),
                ),
                // Only high and urgent are flagged — a badge on every task
                // would mean nothing.
                if (priority != null && priority.standsOut) ...[
                  horizontalSpaceSmall,
                  _PriorityBadge(priority: priority),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _ProgressBar(summary: summary),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.call_outlined, size: 13, color: AppColors.secondaryColor),
                horizontalSpaceTiny,
                CustomText.caption(
                  text: '${summary.handled} of ${summary.total} called',
                ),
                if (task.dueDate != null) ...[
                  horizontalSpaceSmall,
                  Icon(
                    Icons.schedule,
                    size: 13,
                    color: task.overdue ? AppColors.redColor : AppColors.secondaryColor,
                  ),
                  horizontalSpaceTiny,
                  Expanded(
                    child: CustomText.caption(
                      text: task.overdue
                          ? 'Late · ${ReportCard.formatWhen(task.dueDate)}'
                          : 'Due ${ReportCard.formatWhen(task.dueDate)}',
                      textColor: task.overdue ? AppColors.redColor : null,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.summary});

  final TargetsSummary summary;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: summary.progress,
        minHeight: 6,
        backgroundColor: AppColors.borderColor,
        valueColor: const AlwaysStoppedAnimation(AppColors.primaryColor),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final urgent = priority == TaskPriority.urgent;
    final color = urgent ? AppColors.redColor : AppColors.amberColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: CustomText.caption(text: priority.label, textColor: color),
    );
  }
}
