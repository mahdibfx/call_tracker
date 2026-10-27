import 'package:flutter/material.dart';
import 'package:call_tracker/data/report_models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// Narrows the inbox to one state. Null means everything.
class StateFilterBar extends StatelessWidget {
  const StateFilterBar({super.key, required this.selected, required this.onChanged});

  final ReportState? selected;
  final ValueChanged<ReportState?> onChanged;

  @override
  Widget build(BuildContext context) {
    // "Open" first: what still needs someone is what a handler opens the app
    // for, and it is the only multi-state filter.
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            label: 'All',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final state in ReportState.values) ...[
            horizontalSpaceSmall,
            _Chip(
              label: state.label,
              selected: selected == state,
              onTap: () => onChanged(state),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusPillValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryColorLight : AppColors.cardColor,
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusPillValue),
          border: Border.all(
            color: selected ? AppColors.primaryColor : AppColors.borderColor,
          ),
        ),
        child: CustomText.caption(
          text: label,
          textColor: selected ? AppColors.primaryColor : AppColors.secondaryColor,
        ),
      ),
    );
  }
}
