import 'package:flutter/material.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/views/call/call_view.dart';
import 'package:call_tracker/ui/widgets/app_top_bar.dart';
import 'package:call_tracker/ui/widgets/custom_button.dart';
import 'package:call_tracker/ui/widgets/custom_input.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

class StudentDetailView extends StatefulWidget {
  const StudentDetailView({super.key, required this.student, this.groupName});

  final Student student;
  final String? groupName;

  @override
  State<StudentDetailView> createState() => _StudentDetailViewState();
}

class _StudentDetailViewState extends State<StudentDetailView> {
  CallReason _selectedReason = CallReason.paymentInquiry;
  final _noteController = TextEditingController();

  static const _reasonIcons = {
    CallReason.paymentInquiry: Icons.payments_outlined,
    CallReason.beginningOfSession: Icons.school_outlined,
    CallReason.teacherAbsence: Icons.person_off_outlined,
    CallReason.inquiryOnAbsences: Icons.help_outline,
    CallReason.survey: Icons.fact_check_outlined,
    CallReason.parentDidNotPickUp: Icons.directions_car_outlined,
  };

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppTopBar(title: student.name, onBack: () => Navigator.of(context).pop()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(AppStyles.borderRadiusLargeValue),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColorLight,
                        borderRadius: BorderRadius.circular(AppStyles.borderRadiusPillValue),
                      ),
                      child: CustomText.caption(text: widget.groupName ?? student.level, textColor: AppColors.primaryColor),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: AppColors.backgroundColor, shape: BoxShape.circle),
                      child: const Icon(Icons.history, color: AppColors.secondaryColor, size: 18),
                    ),
                  ],
                ),
                verticalSpaceSmall,
                CustomText.headline(text: student.name),
                CustomText.subtitle(text: 'Student ID: ${student.studentId}'),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: AppColors.borderColor)),
                _InfoRow(icon: Icons.escalator_warning_outlined, label: "Parent's Name", value: student.parentName),
                verticalSpaceSmall,
                _InfoRow(icon: Icons.call_outlined, label: 'Phone Number', value: student.phone),
              ],
            ),
          ),
          verticalSpaceMedium,
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.textColor),
              horizontalSpaceTiny,
              CustomText.bodyBold(text: 'Reason for Call', fontSize: 16),
            ],
          ),
          verticalSpaceSmall,
          ...CallReason.values.map((reason) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReasonTile(
                  reason: reason,
                  icon: _reasonIcons[reason]!,
                  selected: _selectedReason == reason,
                  onTap: () => setState(() => _selectedReason = reason),
                ),
              )),
          verticalSpaceSmall,
          CustomText.bodyBold(text: 'Internal Note', fontSize: 16),
          verticalSpaceSmall,
          CustomInput(hintText: 'Add a quick note about this call intent...', controller: _noteController, maxLines: 3, minLines: 3),
          verticalSpaceMedium,
          CustomButton(
            text: 'Start Call',
            icon: Icons.call,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CallView(student: student, reason: _selectedReason)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: AppColors.backgroundColor, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: AppColors.secondaryColor),
        ),
        horizontalSpaceSmall,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomText.caption(text: label),
            CustomText.bodyBold(text: value, fontSize: 15),
          ],
        ),
      ],
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.reason, required this.icon, required this.selected, required this.onTap});

  final CallReason reason;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
          border: Border.all(color: selected ? AppColors.primaryColor : AppColors.borderColor, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: AppColors.backgroundColor, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: AppColors.textColor),
            ),
            horizontalSpaceSmall,
            Expanded(child: CustomText.bodyBold(text: reason.label, fontSize: 15)),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primaryColor : AppColors.secondaryColorLight,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
