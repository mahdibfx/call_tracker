import 'package:flutter/material.dart';
import 'package:call_tracker/data/call_history_store.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/widgets/app_top_bar.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

// ponytail: no design provided yet for the real dashboard, placeholder until one exists.
// Flip this to false before shipping to agents — it must never ship on, or they'd learn
// exactly what the detector is watching for.
const bool kShowCallMonitor = true;

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  List<CallRecord>? _records;

  @override
  void initState() {
    super.initState();
    if (kShowCallMonitor) _load();
  }

  Future<void> _load() async {
    final records = await CallHistoryStore.all();
    if (mounted) setState(() => _records = records);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const AppTopBar(title: 'Dashboard'),
      body: kShowCallMonitor ? _buildMonitorSection() : Center(child: CustomText.subtitle(text: 'Dashboard coming soon')),
    );
  }

  Widget _buildMonitorSection() {
    final records = _records;
    if (records == null) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bug_report_outlined, size: 18, color: AppColors.secondaryColor),
                  horizontalSpaceTiny,
                  CustomText.bodyBold(text: 'Call Monitor (Test Mode)', fontSize: 16),
                ],
              ),
              TextButton(
                onPressed: () async {
                  await CallHistoryStore.clear();
                  _load();
                },
                child: CustomText.caption(text: 'Clear', textColor: AppColors.primaryColor),
              ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? Center(child: CustomText.subtitle(text: 'No calls recorded yet'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: records.length,
                  separatorBuilder: (_, _) => verticalSpaceSmall,
                  itemBuilder: (context, i) => _CallRecordTile(record: records[i]),
                ),
        ),
      ],
    );
  }
}

class _CallRecordTile extends StatelessWidget {
  const _CallRecordTile({required this.record});

  final CallRecord record;

  @override
  Widget build(BuildContext context) {
    final flagged = record.isFlagged;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadiusLargeValue),
        border: Border.all(color: flagged ? AppColors.redColor.withValues(alpha: .4) : AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: CustomText.bodyBold(text: record.studentName, fontSize: 15)),
              Icon(
                flagged ? Icons.flag : Icons.check_circle,
                size: 16,
                color: flagged ? AppColors.redColor : AppColors.greenColor,
              ),
            ],
          ),
          const SizedBox(height: 2),
          CustomText.caption(text: '${record.reason.label} • agent said: ${record.outcome?.label ?? 'no outcome'}'),
          const SizedBox(height: 6),
          CustomText.body(
            text: record.verdictLabel,
            textColor: flagged ? AppColors.redColor : AppColors.textColor,
            fontSize: 13,
          ),
        ],
      ),
    );
  }
}
