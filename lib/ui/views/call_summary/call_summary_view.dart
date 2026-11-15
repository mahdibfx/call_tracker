import 'dart:async';

import 'package:flutter/material.dart';
import 'package:call_tracker/data/api_service.dart';
import 'package:call_tracker/data/auth_service.dart';
import 'package:call_tracker/data/call_history_store.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/refresh_signal.dart';
import 'package:call_tracker/main.dart';
import 'package:call_tracker/data/task_api.dart';
import 'package:call_tracker/data/task_models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/widgets/custom_button.dart';
import 'package:call_tracker/ui/widgets/custom_input.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class CallSummaryView extends StatefulWidget {
  const CallSummaryView({
    super.key,
    required this.student,
    required this.reason,
    required this.durationSeconds,
    required this.startedAtEpochMs,
    this.verification,
    this.taskId,
    this.targetId,
  });

  final Student student;
  final CallReason reason;
  final int durationSeconds;

  /// When the agent tapped "Start Call" — sent to the backend alongside the
  /// end time so a late submission still records when the call really was.
  final int startedAtEpochMs;
  final CallVerification? verification;

  /// Set when this call is one student on a task: the outcome chosen here is
  /// also written back as that target's result, so the agent never has to
  /// reopen the task to record what happened.
  final int? taskId;
  final int? targetId;

  @override
  State<CallSummaryView> createState() => _CallSummaryViewState();
}

class _CallSummaryViewState extends State<CallSummaryView> {
  CallOutcome? _selectedOutcome = CallOutcome.interested;

  /// True while a finish is in flight, so the button shows progress and a
  /// second tap (or the X) cannot fire a duplicate submit.
  bool _finishing = false;
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

  /// Deliberately derived from the call duration alone. Anything read off
  /// [CallVerification] here — "no call was detected for this number" being
  /// the worst of them — tells the agent his call log is being checked.
  String get _statusDescription => widget.durationSeconds > 0
      ? 'Call lasted $_formattedDuration.'
      : 'The call was not answered.';

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final agent = await AuthService.currentAgent();
    final record = CallRecord(
      studentId: widget.student.id,
      studentName: widget.student.name,
      reason: widget.reason,
      outcome: _selectedOutcome,
      agentId: agent?.id,
      agentName: agent?.name,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      reallyDialed: widget.verification?.reallyDialed ?? true,
      talkDurationSeconds: widget.durationSeconds,
      timestampEpochMs: DateTime.now().millisecondsSinceEpoch,
      likelyHungUpEarly: widget.verification?.likelyHungUpEarly ?? false,
      endedQuickly: widget.verification?.endedQuickly ?? false,
      ringSessionSeconds: widget.verification?.ringSessionSeconds,
    );
    // Local first, so the call is in the agent's history even with no signal.
    await CallHistoryStore.add(record);

    // Everything the background sync needs, captured before this screen is
    // gone — it must not touch `widget`/`context`/`setState` afterwards.
    final outcome = _selectedOutcome;
    final startedAt = widget.startedAtEpochMs;
    final studentName = widget.student.name;
    final reasonLabel = widget.reason.label;
    final taskId = widget.taskId;
    final targetId = widget.targetId;

    // Leave immediately. A field agent must never be trapped on "Finishing…"
    // while the phone's data reconnects after a call — which is exactly what an
    // awaited submit here did. The call is already saved locally; the server
    // sync runs in the background and reports itself through the root overlay.
    if (!mounted) return;
    if (taskId != null) {
      // Back to the task detail (one pop — CallView replaced itself here).
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    RefreshSignal.fire();

    unawaited(_syncToServer(
      record: record,
      reasonLabel: reasonLabel,
      outcome: outcome,
      startedAt: startedAt,
      studentName: studentName,
      taskId: taskId,
      targetId: targetId,
    ));
  }

  /// Sends the finished call, and (for a task call) the target result, after
  /// the screen has already closed. Static so it cannot accidentally reach
  /// into the disposed State; it reports through the root navigator's overlay.
  static Future<void> _syncToServer({
    required CallRecord record,
    required String reasonLabel,
    required CallOutcome? outcome,
    required int startedAt,
    required String studentName,
    required int? taskId,
    required int? targetId,
  }) async {
    final result = await ApiService.submitCall(
      studentId: record.studentId,
      studentName: record.studentName,
      reason: reasonLabel,
      outcome: outcome?.label ?? '',
      notes: record.notes,
      reallyDialed: record.reallyDialed,
      talkDurationSeconds: record.talkDurationSeconds,
      ringSessionSeconds: record.ringSessionSeconds,
      likelyHungUpEarly: record.likelyHungUpEarly,
      endedQuickly: record.endedQuickly,
      finalResult: record.finalResult,
      startedAtEpochMs: startedAt,
      endedAtEpochMs: record.timestampEpochMs,
    );

    String? taskError;
    if (taskId != null && targetId != null) {
      taskError = await TaskApi.setTargetResult(
        taskId,
        targetId,
        status: TargetStatus.forCall(outcome),
        note: record.notes ?? '',
        // Links the call to the target when the backend returned its id.
        callId: (result?['id'] as num?)?.toInt(),
      );
      // The target changed server-side, so refresh an open task screen.
      if (taskError == null) RefreshSignal.fire();
    }

    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    if (result == null) {
      showTopSnackBar(
        overlay,
        CustomSnackBar.error(
          message: "Couldn't send $studentName's call — it's saved on your phone.",
        ),
      );
    } else if (taskError != null) {
      showTopSnackBar(
        overlay,
        CustomSnackBar.error(message: 'Call sent, but the task result did not: $taskError'),
      );
    }
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
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textColor),
          onPressed: _finishing ? null : _finish,
        ),
        title: CustomText.title(text: 'Call Summary', fontSize: 18),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(
                AppStyles.borderRadiusLargeValue,
              ),
              border: Border.all(color: AppColors.borderColor),
              boxShadow: [
                BoxShadow(
                  color: AppColors.greenColor.withValues(alpha: .4),
                  offset: const Offset(0, -3),
                  blurRadius: 0,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.greenColorLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: AppColors.greenColor,
                        size: 20,
                      ),
                    ),
                    horizontalSpaceSmall,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText.bodyBold(
                            text: widget.student.name,
                            fontSize: 16,
                          ),
                          CustomText.subtitle(text: widget.student.phone),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.secondaryColor,
                        ),
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
                  decoration: BoxDecoration(
                    color: AppColors.backgroundColor,
                    borderRadius: BorderRadius.circular(
                      AppStyles.borderRadiusMediumValue,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CustomText.caption(text: 'STATUS'),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.redColorLight,
                              borderRadius: BorderRadius.circular(
                                AppStyles.borderRadiusPillValue,
                              ),
                            ),
                            child: CustomText.caption(
                              text: 'Call Ended',
                              textColor: AppColors.redColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      CustomText.body(text: _statusDescription),
                    ],
                  ),
                ),
                // Deliberately nothing here about the verification verdict.
                // The agent must not be able to tell what the call log check
                // concluded — it still goes to the backend, it just isn't
                // shown to the person being checked.
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
                .map(
                  (o) => _OutcomeCard(
                    outcome: o,
                    icon: _outcomeIcons[o]!,
                    selected: _selectedOutcome == o,
                    onTap: () => setState(() => _selectedOutcome = o),
                  ),
                )
                .toList(),
          ),
          verticalSpaceMedium,
          CustomText.bodyBold(text: 'Internal Notes', fontSize: 16),
          verticalSpaceSmall,
          CustomInput(
            hintText: 'Add specific notes about the conversation...',
            controller: _notesController,
            maxLines: 4,
            minLines: 4,
          ),
          verticalSpaceMedium,
          CustomButton(
            text: _finishing ? 'Finishing…' : 'Save and Finish',
            onPressed: _finishing ? null : _finish,
          ),
        ],
      ),
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({
    required this.outcome,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

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
          borderRadius: BorderRadius.circular(
            AppStyles.borderRadiusMediumValue,
          ),
          border: Border.all(
            color: selected ? AppColors.primaryColor : AppColors.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primaryColor : AppColors.textColor,
              size: 22,
            ),
            const SizedBox(height: 6),
            CustomText.bodyBold(
              text: outcome.label,
              fontSize: 13,
              textAlign: TextAlign.center,
              textColor: selected
                  ? AppColors.primaryColor
                  : AppColors.textColor,
            ),
          ],
        ),
      ),
    );
  }
}
