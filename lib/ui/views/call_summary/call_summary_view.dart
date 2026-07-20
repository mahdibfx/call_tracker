import 'package:flutter/material.dart';
import 'package:call_tracker/data/api_service.dart';
import 'package:call_tracker/data/auth_service.dart';
import 'package:call_tracker/data/call_history_store.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/widgets/custom_button.dart';
import 'package:call_tracker/ui/widgets/custom_input.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

class CallSummaryView extends StatefulWidget {
  const CallSummaryView({
    super.key,
    required this.student,
    required this.reason,
    required this.durationSeconds,
    this.verification,
  });

  final Student student;
  final CallReason reason;
  final int durationSeconds;
  final CallVerification? verification;

  @override
  State<CallSummaryView> createState() => _CallSummaryViewState();
}

class _CallSummaryViewState extends State<CallSummaryView> {
  CallOutcome? _selectedOutcome = CallOutcome.interested;
  final _notesController = TextEditingController();

  static const _outcomeIcons = {
    CallOutcome.interested: Icons.thumb_up_outlined,
    CallOutcome.notInterested: Icons.thumb_down_outlined,
    CallOutcome.comingToInstitute: Icons.directions_walk,
    CallOutcome.informationDiscussed: Icons.info_outline,
    CallOutcome.couldNotReach: Icons.fact_check_outlined,
    CallOutcome.followUpRequired: Icons.event_repeat_outlined,
  };

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String get _formattedDuration {
    final m = (widget.durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (widget.durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _statusDescription {
    final verification = widget.verification;
    if (verification == null) {
      return 'Parent hung up after ${widget.durationSeconds ~/ 60} minutes.';
    }
    if (!verification.reallyDialed) return 'No call was detected for this number.';
    if (verification.talkDurationSeconds <= 0) return 'The call was not answered.';
    return 'Call lasted $_formattedDuration.';
  }

  Future<void> _finish() async {
    final agent = await AuthService.currentAgent();
    final record = CallRecord(
      studentId: widget.student.id,
      studentName: widget.student.name,
      reason: widget.reason,
      outcome: _selectedOutcome,
      agentId: agent?.id,
      agentName: agent?.name,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      reallyDialed: widget.verification?.reallyDialed ?? true,
      talkDurationSeconds: widget.durationSeconds,
      timestampEpochMs: DateTime.now().millisecondsSinceEpoch,
      likelyHungUpEarly: widget.verification?.likelyHungUpEarly ?? false,
      endedQuickly: widget.verification?.endedQuickly ?? false,
      ringSessionSeconds: widget.verification?.ringSessionSeconds,
    );
    await Future.wait([
      CallHistoryStore.add(record),
      ApiService.submitCall(
        studentId: widget.student.id,
        studentName: widget.student.name,
        reason: widget.reason.label,
        outcome: _selectedOutcome?.label ?? '',
        notes: record.notes,
        reallyDialed: record.reallyDialed,
        talkDurationSeconds: record.talkDurationSeconds,
        ringSessionCount: 1,
        isFinal: true,
      ),
    ]);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(icon: const Icon(Icons.close, color: AppColors.textColor), onPressed: _finish),
        title: CustomText.title(text: 'Call Summary', fontSize: 18),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(AppStyles.borderRadiusLargeValue),
              border: Border.all(color: AppColors.borderColor),
              boxShadow: [BoxShadow(color: AppColors.greenColor.withValues(alpha: .4), offset: const Offset(0, -3), blurRadius: 0, spreadRadius: -2)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.greenColorLight, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: AppColors.greenColor, size: 20),
                    ),
                    horizontalSpaceSmall,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText.bodyBold(text: widget.student.name, fontSize: 16),
                          CustomText.subtitle(text: 'Parent: ${widget.student.parentName}'),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: AppColors.secondaryColor),
                        horizontalSpaceTiny,
                        CustomText.caption(text: _formattedDuration),
                      ],
                    ),
                  ],
                ),
                verticalSpaceMedium,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.backgroundColor, borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CustomText.caption(text: 'STATUS'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.redColorLight, borderRadius: BorderRadius.circular(AppStyles.borderRadiusPillValue)),
                            child: CustomText.caption(text: 'Call Ended', textColor: AppColors.redColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      CustomText.body(text: _statusDescription),
                    ],
                  ),
                ),
                if (widget.verification?.suspicious ?? false) ...[
                  verticalSpaceSmall,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.redColorLight,
                      borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
                      border: Border.all(color: AppColors.redColor.withValues(alpha: .3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.flag_outlined, color: AppColors.redColor, size: 18),
                        horizontalSpaceSmall,
                        Expanded(
                          child: CustomText.body(
                            text: 'Flagged for review: ${widget.verification!.note}',
                            textColor: AppColors.redColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          verticalSpaceMedium,
          CustomText.bodyBold(text: 'What was the outcome?', fontSize: 16),
          verticalSpaceSmall,
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: CallOutcome.values
                .map((o) => _OutcomeCard(
                      outcome: o,
                      icon: _outcomeIcons[o]!,
                      selected: _selectedOutcome == o,
                      onTap: () => setState(() => _selectedOutcome = o),
                    ))
                .toList(),
          ),
          verticalSpaceMedium,
          CustomText.bodyBold(text: 'Internal Notes', fontSize: 16),
          verticalSpaceSmall,
          CustomInput(hintText: 'Add specific notes about the conversation...', controller: _notesController, maxLines: 4, minLines: 4),
          verticalSpaceMedium,
          CustomButton(text: 'Save and Finish', onPressed: _finish),
        ],
      ),
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({required this.outcome, required this.icon, required this.selected, required this.onTap});

  final CallOutcome outcome;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryColorLight : AppColors.cardColor,
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
          border: Border.all(color: selected ? AppColors.primaryColor : AppColors.borderColor, width: selected ? 1.5 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? AppColors.primaryColor : AppColors.textColor, size: 22),
            const SizedBox(height: 6),
            CustomText.bodyBold(text: outcome.label, fontSize: 13, textAlign: TextAlign.center, textColor: selected ? AppColors.primaryColor : AppColors.textColor),
          ],
        ),
      ),
    );
  }
}
