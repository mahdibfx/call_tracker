import 'package:flutter/material.dart';
import 'package:call_tracker/data/auth_service.dart';
import 'package:call_tracker/data/report_api.dart';
import 'package:call_tracker/data/report_models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/views/reports/widgets/close_report_sheet.dart';
import 'package:call_tracker/ui/views/reports/widgets/report_card.dart';
import 'package:call_tracker/ui/views/reports/widgets/report_state_chip.dart';
import 'package:call_tracker/ui/widgets/custom_button.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

/// One report, with whatever actions the signed-in role is allowed.
class ReportDetailView extends StatefulWidget {
  const ReportDetailView({super.key, required this.report});

  final Report report;

  @override
  State<ReportDetailView> createState() => _ReportDetailViewState();
}

class _ReportDetailViewState extends State<ReportDetailView> {
  late Report _report = widget.report;
  bool _busy = false;
  bool _changed = false;

  /// Whether this role handles the report's category.
  ///
  /// Cosmetic: it decides which buttons to draw, not what is permitted. The
  /// backend answers 403 regardless, and that answer is surfaced rather than
  /// swallowed.
  bool get _canHandle {
    final user = AuthService.signedIn.value;
    return user != null && _report.canBeHandledBy(user);
  }

  bool get _isAdmin => AuthService.signedIn.value?.isAdmin ?? false;

  Future<void> _apply(Future<Report?> Function() action, String failureMessage) async {
    setState(() => _busy = true);
    final updated = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (updated != null) {
        _report = updated;
        _changed = true;
      }
    });
    if (updated == null) _complain(failureMessage);
  }

  void _complain(String message) {
    showTopSnackBar(
      Overlay.of(context),
      CustomSnackBar.error(message: message),
    );
  }

  Future<void> _setState(ReportState state) => _apply(
        () => ReportApi.setState(_report.id, state: state),
        "Couldn't update this report. It may not be yours to handle.",
      );

  Future<void> _close() async {
    final result = await showCloseReportSheet(context);
    if (result == null) return;
    await _apply(
      () => ReportApi.setState(
        _report.id,
        state: result.state,
        confirmationDescription: result.description,
        confirmationImagePath: result.imagePath,
      ),
      "Couldn't close this report. It may not be yours to handle.",
    );
  }

  Future<void> _toggleConfirmed() async {
    setState(() => _busy = true);
    final ok = await ReportApi.setConfirmed(_report.id, !_report.confirmed);
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      _complain("Couldn't change the sign-off.");
      return;
    }
    final fresh = await ReportApi.getReport(_report.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (fresh != null) _report = fresh;
      _changed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final category = report.category;
    final room = report.room;
    final reporter = report.reportedBy;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, _) {},
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textColor),
            // Tells the inbox whether to re-fetch.
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          title: CustomText.title(
            text: category?.name ?? 'Report #${report.id}',
            fontSize: 18,
            maxLines: 1,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ReportStateChip(state: report.state, confirmed: report.confirmed),
                      const Spacer(),
                      CustomText.caption(
                        text: ReportCard.formatWhen(report.reportedAt),
                      ),
                    ],
                  ),
                  if (report.description != null && report.description!.isNotEmpty) ...[
                    verticalSpaceSmall,
                    CustomText.body(text: report.description!),
                  ],
                  if (report.imageUrl != null) ...[
                    verticalSpaceSmall,
                    _ReportImage(url: report.imageUrl!),
                  ],
                  verticalSpaceSmall,
                  const Divider(height: 1, color: AppColors.borderColor),
                  verticalSpaceSmall,
                  if (reporter != null)
                    _Row(
                      icon: Icons.person_outline,
                      label: 'Reported by',
                      value: [
                        reporter.name,
                        if (reporter.role != null) '(${reporter.role!.displayLabel})',
                      ].join(' '),
                    ),
                  if (room != null)
                    _Row(
                      icon: Icons.meeting_room_outlined,
                      label: 'Room',
                      value: room.display,
                    ),
                  if (category?.role != null)
                    _Row(
                      icon: Icons.build_outlined,
                      label: 'Handled by',
                      value: category!.role!.displayLabel,
                    ),
                  if (report.stateNote != null && report.stateNote!.isNotEmpty)
                    _Row(
                      icon: Icons.sticky_note_2_outlined,
                      label: 'Note',
                      value: report.stateNote!,
                    ),
                ],
              ),
            ),
            if (report.hasResult) ...[
              verticalSpaceMedium,
              CustomText.bodyBold(text: 'Result', fontSize: 16),
              verticalSpaceSmall,
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (report.confirmationDescription != null &&
                        report.confirmationDescription!.isNotEmpty)
                      CustomText.body(text: report.confirmationDescription!),
                    if (report.confirmationImageUrl != null) ...[
                      verticalSpaceSmall,
                      _ReportImage(url: report.confirmationImageUrl!),
                    ],
                  ],
                ),
              ),
            ],
            if (_canHandle) ...[
              verticalSpaceMedium,
              CustomText.bodyBold(text: 'What now?', fontSize: 16),
              verticalSpaceSmall,
              ..._actions(report),
            ],
            if (_isAdmin) ...[
              verticalSpaceMedium,
              CustomButton(
                text: report.confirmed ? 'Take back sign-off' : 'Sign off',
                icon: report.confirmed ? Icons.undo : Icons.verified_outlined,
                onPressed: _busy ? null : _toggleConfirmed,
                backgroundColor: AppColors.cardColor,
                foregroundColor: AppColors.textColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The next steps that make sense from here, rather than a free pick of
  /// every state — fewer ways to put a report somewhere nobody meant.
  List<Widget> _actions(Report report) {
    final state = report.state;
    final buttons = <Widget>[];

    if (state == ReportState.review) {
      buttons.add(CustomButton(
        text: 'Start work',
        icon: Icons.play_arrow,
        onPressed: _busy ? null : () => _setState(ReportState.processing),
      ));
    }
    if (state == ReportState.review || state == ReportState.processing) {
      buttons.add(CustomButton(
        text: 'Close this report',
        icon: Icons.check,
        onPressed: _busy ? null : _close,
        backgroundColor: AppColors.greenColor,
      ));
    }
    if (state?.isClosing ?? false) {
      buttons.add(CustomButton(
        text: 'Reopen',
        icon: Icons.refresh,
        onPressed: _busy ? null : () => _setState(ReportState.processing),
        backgroundColor: AppColors.cardColor,
        foregroundColor: AppColors.textColor,
      ));
    }
    if (state == null) {
      // An unknown state: offer nothing rather than guess a transition.
      buttons.add(CustomText.subtitle(
        text: 'This report is in a state this version does not recognise.',
        maxLines: 2,
      ));
    }

    return [
      for (final b in buttons)
        Padding(padding: const EdgeInsets.only(bottom: 10), child: b),
    ];
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusLargeValue),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: child,
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppColors.secondaryColor),
            horizontalSpaceSmall,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText.caption(text: label),
                  CustomText.body(text: value, fontSize: 14, maxLines: 3),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ReportImage extends StatelessWidget {
  const _ReportImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
      child: Image.network(
        url,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              ),
        // A dead URL would otherwise paint a red error box over the card.
        errorBuilder: (_, _, _) => Container(
          height: 120,
          color: AppColors.backgroundColor,
          child: Center(
            child: CustomText.caption(text: "Photo couldn't be loaded"),
          ),
        ),
      ),
    );
  }
}
