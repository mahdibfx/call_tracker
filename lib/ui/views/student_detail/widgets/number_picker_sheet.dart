import 'package:flutter/material.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// Asks which of a student's numbers to ring.
///
/// Returns the chosen line, or null if the sheet was dismissed. Only worth
/// showing when a student has more than one number on file — most have one,
/// and that case should dial without an extra tap.
Future<StudentPhone?> showNumberPicker(BuildContext context, Student student) {
  return showModalBottomSheet<StudentPhone>(
    context: context,
    backgroundColor: AppColors.cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppStyles.borderRadiusLargeValue),
      ),
    ),
    builder: (context) => _NumberPicker(student: student),
  );
}

class _NumberPicker extends StatelessWidget {
  const _NumberPicker({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    // The same line the app would have dialed on its own — parent first, then
    // primary. Marked as the suggestion rather than pre-committed, so one tap
    // still places the call.
    final suggested = student.phone;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomText.bodyBold(text: 'Which number?', fontSize: 16),
            const SizedBox(height: 2),
            CustomText.caption(text: student.name),
            verticalSpaceMedium,
            ...student.phones.map(
              (phone) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _NumberRow(
                  phone: phone,
                  suggested: phone.number == suggested,
                  onTap: () => Navigator.of(context).pop(phone),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.phone,
    required this.suggested,
    required this.onTap,
  });

  final StudentPhone phone;
  final bool suggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = [
      phone.isParentLine ? "Parent's number" : 'Personal number',
      if (phone.label != null && phone.label!.isNotEmpty) '(${phone.label})',
      if (phone.isPrimary) '• primary',
    ].join(' ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: suggested ? AppColors.primaryColorLight : AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
          border: Border.all(
            color: suggested ? AppColors.primaryColor : AppColors.borderColor,
            width: suggested ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              // Same mapping the student detail card uses for these lines.
              phone.isParentLine ? Icons.escalator_warning_outlined : Icons.call_outlined,
              size: 20,
              color: suggested ? AppColors.primaryColor : AppColors.secondaryColor,
            ),
            horizontalSpaceSmall,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText.bodyBold(text: phone.number, fontSize: 15),
                  const SizedBox(height: 2),
                  CustomText.caption(text: label),
                ],
              ),
            ),
            if (suggested)
              const Icon(Icons.check_circle, size: 20, color: AppColors.primaryColor),
          ],
        ),
      ),
    );
  }
}
