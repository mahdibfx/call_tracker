import 'package:flutter/material.dart';
import 'package:call_tracker/data/report_models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/views/reports/widgets/report_state_chip.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// One report in the inbox.
class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report, required this.onTap});

  final Report report;
  final VoidCallback onTap;

  /// `24/10 · 12:38`, or `24/10/2026 · 12:38` once it is not this year — a
  /// year on every row is noise when most reports are recent.
  static String formatWhen(DateTime? when) {
    if (when == null) return '';
    final d = when.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    final sameYear = d.year == DateTime.now().year;
    return sameYear ? '$dd/$mm · $hh:$min' : '$dd/$mm/${d.year} · $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final category = report.category;
    final room = report.room;
    final reporter = report.reportedBy;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusLargeValue),
      child: Container(
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
                  child: CustomText.bodyBold(
                    text: category?.name ?? 'Uncategorised',
                    fontSize: 15,
                    maxLines: 1,
                  ),
                ),
                horizontalSpaceSmall,
                ReportStateChip(state: report.state, confirmed: report.confirmed),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report.imageUrl != null) ...[
                  _Thumbnail(url: report.imageUrl!),
                  horizontalSpaceSmall,
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText.body(
                        text: report.summaryLine,
                        fontSize: 13,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        children: [
                          if (room != null)
                            _Meta(icon: Icons.meeting_room_outlined, text: room.roomIndex),
                          if (reporter != null)
                            _Meta(icon: Icons.person_outline, text: reporter.name),
                          _Meta(
                            icon: Icons.access_time,
                            text: formatWhen(report.reportedAt),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.secondaryColor),
        horizontalSpaceTiny,
        CustomText.caption(text: text),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
      child: Image.network(
        url,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        // Without these a slow or dead URL paints a red error box across the
        // row; the image is decoration here, so it fails quietly.
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : const _ThumbPlaceholder(),
        errorBuilder: (_, _, _) => const _ThumbPlaceholder(),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        color: AppColors.backgroundColor,
        child: const Icon(Icons.image_outlined, size: 20, color: AppColors.secondaryColor),
      );
}
