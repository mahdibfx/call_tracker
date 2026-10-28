import 'package:flutter/material.dart';
import 'package:call_tracker/data/auth_service.dart';
import 'package:call_tracker/data/call_history_store.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/refresh_signal.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/widgets/app_top_bar.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// The agent's own record of calls they've made, read from on-device storage —
/// the backend has no history endpoint yet, and this needs to work offline.
///
/// Agent-facing, so it shows only what the agent themselves reported: who,
/// why, what they said the outcome was, how long it lasted. Nothing about the
/// call-log check is surfaced here.
class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  List<CallRecord>? _records;

  @override
  void initState() {
    super.initState();
    _load();
    RefreshSignal.listenable.addListener(_load);
  }

  @override
  void dispose() {
    RefreshSignal.listenable.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final records = await CallHistoryStore.all();
    final agent = await AuthService.currentAgent();
    if (!mounted) return;
    // A shared handset shouldn't show one agent their colleague's calls.
    // Records saved before logins existed carry no agent and stay visible.
    final mine = agent == null
        ? records
        : records.where((r) => r.agentId == null || r.agentId == agent.id).toList();
    setState(() => _records = mine);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const AppTopBar(title: 'Call History', showUser: true),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primaryColor,
        child: _buildList(),
      ),
    );
  }

  Widget _buildList() {
    final records = _records;
    if (records == null) return const Center(child: CircularProgressIndicator());
    if (records.isEmpty) {
      // Still a ListView so the empty state can be pulled down to refresh.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
        children: [
          Center(child: CustomText.subtitle(text: 'No calls yet — your finished calls appear here.')),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: records.length,
      separatorBuilder: (_, _) => verticalSpaceSmall,
      itemBuilder: (context, i) => _HistoryTile(record: records[i]),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final CallRecord record;

  static String _formatWhen(int epochMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal();
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
    final notes = record.notes;
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
              Expanded(
                child: CustomText.bodyBold(text: record.studentName, fontSize: 15, maxLines: 1),
              ),
              horizontalSpaceSmall,
              CustomText.caption(text: _formatWhen(record.timestampEpochMs)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 13, color: AppColors.secondaryColor),
              horizontalSpaceTiny,
              Expanded(child: CustomText.subtitle(text: record.reason.label, maxLines: 1)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.access_time, size: 13, color: AppColors.secondaryColor),
              horizontalSpaceTiny,
              CustomText.subtitle(text: _formatDuration(record.talkDurationSeconds)),
            ],
          ),
          if (record.outcome != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryColorLight,
                borderRadius: BorderRadius.circular(AppStyles.borderRadiusPillValue),
              ),
              child: CustomText.caption(
                text: record.outcome!.label,
                textColor: AppColors.primaryColor,
              ),
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
