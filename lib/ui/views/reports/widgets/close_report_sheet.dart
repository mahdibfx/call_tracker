import 'dart:io';

import 'package:flutter/material.dart';
import 'package:call_tracker/data/photo_capture.dart';
import 'package:call_tracker/data/report_models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/widgets/custom_button.dart';
import 'package:call_tracker/ui/widgets/custom_input.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// How a report was closed.
class CloseReportResult {
  const CloseReportResult({required this.state, this.description, this.imagePath});

  final ReportState state;
  final String? description;
  final String? imagePath;
}

/// Asks how a report is being closed: done, or closed without a fix, with an
/// optional note and result photo.
///
/// Returns null if the sheet was dismissed. These two fields are the only ones
/// the backend accepts on a closing transition, which is why they live here
/// rather than on the detail screen.
Future<CloseReportResult?> showCloseReportSheet(BuildContext context) {
  return showModalBottomSheet<CloseReportResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppStyles.borderRadiusLargeValue),
      ),
    ),
    builder: (context) => const _CloseReportSheet(),
  );
}

class _CloseReportSheet extends StatefulWidget {
  const _CloseReportSheet();

  @override
  State<_CloseReportSheet> createState() => _CloseReportSheetState();
}

class _CloseReportSheetState extends State<_CloseReportSheet> {
  ReportState _state = ReportState.complete;
  final _noteController = TextEditingController();
  String? _imagePath;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final path = await PhotoCapture.takePhoto();
    if (!mounted || path == null) return;
    setState(() => _imagePath = path);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Keeps the note field above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomText.bodyBold(text: 'Closing this report', fontSize: 16),
              verticalSpaceMedium,
              Row(
                children: [
                  Expanded(
                    child: _Option(
                      label: 'Done',
                      icon: Icons.check_circle_outline,
                      color: AppColors.greenColor,
                      selected: _state == ReportState.complete,
                      onTap: () => setState(() => _state = ReportState.complete),
                    ),
                  ),
                  horizontalSpaceSmall,
                  Expanded(
                    child: _Option(
                      label: "Couldn't fix",
                      icon: Icons.cancel_outlined,
                      color: AppColors.redColor,
                      selected: _state == ReportState.notComplete,
                      onTap: () => setState(() => _state = ReportState.notComplete),
                    ),
                  ),
                ],
              ),
              verticalSpaceMedium,
              CustomText.bodyBold(
                text: _state == ReportState.complete
                    ? 'What did you do?'
                    : 'Why could it not be fixed?',
                fontSize: 14,
              ),
              verticalSpaceSmall,
              CustomInput(
                hintText: 'Optional',
                controller: _noteController,
                maxLines: 3,
                minLines: 3,
              ),
              verticalSpaceMedium,
              if (_imagePath == null)
                CustomButton(
                  text: 'Add a result photo',
                  icon: Icons.photo_camera_outlined,
                  onPressed: _takePhoto,
                  backgroundColor: AppColors.backgroundColor,
                  foregroundColor: AppColors.textColor,
                )
              else
                _PhotoPreview(
                  path: _imagePath!,
                  onRemove: () => setState(() => _imagePath = null),
                  onRetake: _takePhoto,
                ),
              verticalSpaceMedium,
              CustomButton(
                text: _state == ReportState.complete
                    ? 'Mark as done'
                    : 'Close without a fix',
                onPressed: () => Navigator.of(context).pop(
                  CloseReportResult(
                    state: _state,
                    description: _noteController.text.trim().isEmpty
                        ? null
                        : _noteController.text.trim(),
                    imagePath: _imagePath,
                  ),
                ),
                backgroundColor: _state == ReportState.complete
                    ? AppColors.greenColor
                    : AppColors.redColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: .12) : AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
          border: Border.all(
            color: selected ? color : AppColors.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : AppColors.secondaryColor, size: 22),
            const SizedBox(height: 4),
            CustomText.caption(
              text: label,
              textColor: selected ? color : AppColors.secondaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

/// The captured photo, with a way to drop or replace it.
class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.path,
    required this.onRemove,
    required this.onRetake,
  });

  final String path;
  final VoidCallback onRemove;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
          child: Image.file(
            File(path),
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 64,
              height: 64,
              color: AppColors.backgroundColor,
              child: const Icon(Icons.broken_image_outlined, size: 20),
            ),
          ),
        ),
        horizontalSpaceSmall,
        Expanded(child: CustomText.caption(text: 'Photo attached')),
        IconButton(
          onPressed: onRetake,
          icon: const Icon(Icons.photo_camera_outlined, size: 20),
          tooltip: 'Retake',
          color: AppColors.secondaryColor,
        ),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 20),
          tooltip: 'Remove',
          color: AppColors.secondaryColor,
        ),
      ],
    );
  }
}
