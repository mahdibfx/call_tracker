import 'package:flutter/material.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/report_models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// Picks what kind of problem is being reported.
///
/// Shows **every** category, not just the reporter's own — anyone may report
/// anything, which is how a cleaner flags a broken projector for maintenance.
/// The reporter's own group is listed first because that is the common case.
Future<ReportCategory?> showCategoryPicker(
  BuildContext context, {
  required List<ReportCategory> categories,
  StaffRole? ownRole,
}) {
  return showModalBottomSheet<ReportCategory>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppStyles.borderRadiusLargeValue),
      ),
    ),
    builder: (context) => _CategoryPicker(categories: categories, ownRole: ownRole),
  );
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.categories, this.ownRole});

  final List<ReportCategory> categories;
  final StaffRole? ownRole;

  @override
  Widget build(BuildContext context) {
    // Grouped by the role that handles each, so the list reads as "who will
    // get this" rather than as 23 flat options.
    final groups = <StaffRole?, List<ReportCategory>>{};
    for (final category in categories) {
      groups.putIfAbsent(category.role, () => []).add(category);
    }
    final ordered = groups.keys.toList()
      ..sort((a, b) {
        if (a == ownRole) return -1;
        if (b == ownRole) return 1;
        return (a?.displayLabel ?? 'Other').compareTo(b?.displayLabel ?? 'Other');
      });

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      maxChildSize: .92,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: CustomText.bodyBold(text: 'What is the problem?', fontSize: 16),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.secondaryColor,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                for (final role in ordered) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: CustomText.caption(
                      text: (role?.displayLabel ?? 'Other').toUpperCase(),
                    ),
                  ),
                  for (final category in groups[role]!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CategoryRow(
                        category: category,
                        onTap: () => Navigator.of(context).pop(category),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.onTap});

  final ReportCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nameAr = category.nameAr;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText.body(text: category.name, fontSize: 14, maxLines: 2),
                  if (nameAr != null && nameAr.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    CustomText.caption(text: nameAr),
                  ],
                ],
              ),
            ),
            horizontalSpaceSmall,
            const Icon(Icons.chevron_right, size: 18, color: AppColors.secondaryColor),
          ],
        ),
      ),
    );
  }
}
