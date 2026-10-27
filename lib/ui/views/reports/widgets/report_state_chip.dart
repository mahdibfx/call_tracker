import 'package:flutter/material.dart';
import 'package:call_tracker/data/report_models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// Where a report stands, as a coloured pill.
class ReportStateChip extends StatelessWidget {
  const ReportStateChip({super.key, required this.state, this.confirmed = false});

  final ReportState? state;

  /// Admin sign-off, shown as a tick beside the state.
  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    final s = state;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: s?.tint ?? AppColors.secondaryColorLight,
            borderRadius: BorderRadius.circular(AppStyles.borderRadiusPillValue),
          ),
          child: CustomText.caption(
            // A state this build doesn't know still renders, rather than
            // leaving the card looking broken.
            text: s?.label ?? 'Unknown',
            textColor: s?.color ?? AppColors.secondaryColor,
          ),
        ),
        if (confirmed) ...[
          const SizedBox(width: 6),
          const Icon(Icons.verified, size: 15, color: AppColors.greenColor),
        ],
      ],
    );
  }
}
