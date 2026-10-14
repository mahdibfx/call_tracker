import 'package:flutter/material.dart';
import 'package:call_tracker/data/api_service.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/widgets/app_top_bar.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// Every call made to one student, by anyone — unlike the History tab, which
/// is the signed-in agent's own calls read from the device.
///
/// Agent-facing, so it shows what was reported (when, why, outcome, notes,
/// duration, who called) and nothing about the call-log check.
class StudentCallsView extends StatefulWidget {
  const StudentCallsView({super.key, required this.student});

  final Student student;

  @override
  State<StudentCallsView> createState() => _StudentCallsViewState();
}

class _StudentCallsViewState extends State<StudentCallsView> {
  List<StudentCall>? _calls;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final calls = await ApiService.getStudentCalls(widget.student.id);
    if (!mounted) return;
    setState(() {
      // A failed fetch keeps whatever we already had, per the null contract.
      if (calls != null) _calls = calls;
      _failed = calls == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppTopBar(
        title: 'Call Log',
        subtitle: widget.student.name,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primaryColor,
        child: _buildList(),
      ),
    );
  }

  Widget _buildList() {
    final calls = _calls;
    if (calls == null) {
      if (_failed) return _message("Couldn't load the call log — pull down to retry.");
      return const Center(child: CircularProgressIndicator());
    }
    if (calls.isEmpty) return _message('No calls to this student yet.');
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: calls.length,
      separatorBuilder: (_, _) => verticalSpaceSmall,
      itemBuilder: (context, i) => _CallTile(call: calls[i]),
    );
  }

  /// A ListView so the state can still be pulled down to refresh.
  Widget _message(String text) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
        children: [
          Center(
            child: CustomText.body(
              text: text,
              fontSize: 13,
              textColor: AppColors.secondaryColor,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
}

class _CallTile extends StatelessWidget {
  const _CallTile({required this.call});

  final StudentCall call;

  static String _formatWhen(DateTime when) {
    final d = when.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} · $hh:$min';
  }

  static String _formatDuration(int seconds) {
    if (seconds <= 0) return 'Not answered';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}min';
    return '${m}min ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final reason = call.reason;
    final outcome = call.outcome;
    final notes = call.notes;
    final calledBy = call.calledByName;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadiusLargeValue),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: CustomText.bodyBold(text: _formatWhen(call.when), fontSize: 14, maxLines: 1)),
              horizontalSpaceSmall,
              Row(
                children: [
                  Icon(
                    call.wasAnswered ? Icons.call_made : Icons.call_missed_outgoing,
                    size: 13,
                    color: call.wasAnswered ? AppColors.greenColor : AppColors.secondaryColor,
                  ),
                  horizontalSpaceTiny,
                  CustomText.caption(text: _formatDuration(call.talkDurationSeconds)),
                ],
              ),
            ],
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 13, color: AppColors.secondaryColor),
                horizontalSpaceTiny,
                Expanded(child: CustomText.subtitle(text: reason, maxLines: 2)),
              ],
            ),
          ],
          if (calledBy != null && calledBy.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 13, color: AppColors.secondaryColor),
                horizontalSpaceTiny,
                Expanded(child: CustomText.subtitle(text: calledBy, maxLines: 1)),
              ],
            ),
          ],
          if (outcome != null && outcome.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryColorLight,
                borderRadius: BorderRadius.circular(AppStyles.borderRadiusPillValue),
              ),
              child: CustomText.caption(text: outcome, textColor: AppColors.primaryColor),
            ),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            CustomText.body(text: notes, fontSize: 13, maxLines: 3),
          ],
        ],
      ),
    );
  }
}
