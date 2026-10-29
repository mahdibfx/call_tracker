import 'dart:io';

import 'package:flutter/material.dart';
import 'package:call_tracker/data/photo_capture.dart';
import 'package:call_tracker/data/report_api.dart';
import 'package:call_tracker/data/report_models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/views/reports/widgets/room_picker_sheet.dart';
import 'package:call_tracker/ui/widgets/custom_button.dart';
import 'package:call_tracker/ui/widgets/custom_input.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

/// Files a new report. Pops `true` once one has been created.
///
/// Laid out to mirror the dashboard's report form, so the two feel like the
/// same thing: photo sources first, then every category as a chip, then the
/// description and an optional room.
class ReportComposeView extends StatefulWidget {
  const ReportComposeView({super.key});

  @override
  State<ReportComposeView> createState() => _ReportComposeViewState();
}

class _ReportComposeViewState extends State<ReportComposeView> {
  final _descriptionController = TextEditingController();

  List<ReportCategory> _categories = [];
  List<Room> _rooms = [];
  ReportCategory? _category;
  Room? _room;
  String? _imagePath;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadPickers();
    // Keeps the submit button and its hint in step with what has been filled.
    _descriptionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadPickers() async {
    // Every category, not just this role's: anyone may report anything, which
    // is how a cleaner flags a broken projector for maintenance.
    final categories = await ReportApi.getCategories();
    final rooms = await ReportApi.getRooms();
    if (!mounted) return;
    setState(() {
      // Alphabetical, like the dashboard — the chips carry no grouping, and
      // the hint under them says the category is what routes the report.
      if (categories != null) {
        _categories = categories..sort((a, b) => a.name.compareTo(b.name));
      }
      if (rooms != null) _rooms = rooms;
    });
  }

  bool get _hasDetail =>
      _descriptionController.text.trim().isNotEmpty || _imagePath != null;

  /// The category routes the report, so it is required; the backend needs a
  /// description or a photo on top of that.
  bool get _canSubmit => _category != null && _hasDetail;

  Future<void> _addPhoto(Future<String?> Function() source) async {
    final path = await source();
    if (!mounted || path == null) return;
    setState(() => _imagePath = path);
  }

  Future<void> _pickRoom() async {
    if (_rooms.isEmpty) return;
    final picked = await showRoomPicker(context, _rooms);
    if (!mounted || picked == null) return;
    setState(() => _room = picked);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final result = await ReportApi.createReport(
      categoryId: _category?.id,
      description: _descriptionController.text,
      imagePath: _imagePath,
      roomId: _room?.id,
    );
    if (!mounted) return;
    if (result.error != null) {
      setState(() => _submitting = false);
      // The server's own words, not a guess about the network — a rejected
      // report usually says exactly what it wanted.
      showTopSnackBar(
        Overlay.of(context),
        CustomSnackBar.error(message: result.error!),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _photoSection(),
                  verticalSpaceLarge,
                  _RequiredLabel(text: 'What kind of problem?'),
                  verticalSpaceSmall,
                  _categoryChips(),
                  const SizedBox(height: 6),
                  CustomText.caption(text: 'It decides who handles the report.'),
                  verticalSpaceLarge,
                  CustomText.bodyBold(text: "What's the problem?", fontSize: 15),
                  verticalSpaceSmall,
                  CustomInput(
                    hintText: "e.g. The projector doesn't turn on",
                    controller: _descriptionController,
                    maxLines: 4,
                    minLines: 3,
                  ),
                  verticalSpaceLarge,
                  CustomText.bodyBold(text: 'Room', fontSize: 15),
                  verticalSpaceSmall,
                  _roomField(),
                ],
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _photoSection() {
    if (_imagePath != null) {
      return _PhotoPreview(
        path: _imagePath!,
        onRemove: () => setState(() => _imagePath = null),
        onRetake: () => _addPhoto(PhotoCapture.takePhoto),
      );
    }
    return _PhotoSource(
      icon: Icons.photo_camera_outlined,
      label: 'Take a photo',
      hint: 'Opens the camera — the photo has to be taken here',
      onTap: () => _addPhoto(PhotoCapture.takePhoto),
    );
  }

  Widget _categoryChips() {
    if (_categories.isEmpty) {
      return CustomText.subtitle(text: 'Loading the list…');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in _categories)
          _CategoryChip(
            label: category.name,
            selected: _category?.id == category.id,
            // Tapping the chosen one again clears it, so a mis-tap is
            // recoverable without hunting for an undo.
            onTap: () => setState(
              () => _category = _category?.id == category.id ? null : category,
            ),
          ),
      ],
    );
  }

  Widget _roomField() {
    final room = _room;
    return InkWell(
      onTap: _rooms.isEmpty ? null : _pickRoom,
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
          border: Border.all(
            color: room == null ? AppColors.borderColor : AppColors.primaryColor,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: CustomText.bodyBold(
                text: room?.display ?? 'No specific room',
                fontSize: 15,
                textColor: room == null ? AppColors.textColor : AppColors.primaryColor,
                maxLines: 1,
              ),
            ),
            if (room != null)
              InkWell(
                onTap: () => setState(() => _room = null),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 18, color: AppColors.secondaryColor),
                ),
              )
            else
              const Icon(Icons.expand_more, size: 22, color: AppColors.secondaryColor),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.backgroundColor,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Cancel',
                  onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                  backgroundColor: AppColors.cardColor,
                  foregroundColor: AppColors.textColor,
                ),
              ),
              horizontalSpaceSmall,
              Expanded(
                flex: 2,
                child: CustomButton(
                  // CustomButton has no busy state, so the label carries it —
                  // the same thing the login screen does.
                  text: _submitting ? 'Sending…' : 'Send report',
                  icon: _submitting ? null : Icons.send,
                  onPressed: (_canSubmit && !_submitting) ? _submit : null,
                ),
              ),
            ],
          ),
          if (!_canSubmit) ...[
            const SizedBox(height: 8),
            CustomText.caption(
              text: _category == null && !_hasDetail
                  ? 'To send: pick the kind of problem, and add a photo or a description.'
                  : _category == null
                      ? 'Pick the kind of problem to send.'
                      : 'Add a photo or a description to send.',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      decoration: const BoxDecoration(
        color: AppColors.cardColor,
        border: Border(bottom: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.amberColorLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.flag_outlined, color: AppColors.amberColor, size: 22),
          ),
          horizontalSpaceSmall,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText.bodyBold(text: 'Report a problem', fontSize: 18),
                const SizedBox(height: 2),
                CustomText.caption(text: 'Sent right away to whoever handles it'),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 22),
            color: AppColors.secondaryColor,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

/// A section label carrying the required marker.
class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          CustomText.bodyBold(text: text, fontSize: 15),
          const SizedBox(width: 4),
          CustomText.bodyBold(text: '*', fontSize: 15, textColor: AppColors.redColor),
        ],
      );
}

class _PhotoSource extends StatelessWidget {
  const _PhotoSource({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
      child: DottedBorder(
        color: AppColors.primaryColor,
        fill: AppColors.primaryColorLight,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 26, color: AppColors.primaryColor),
              const SizedBox(height: 8),
              CustomText.bodyBold(
                text: label,
                fontSize: 14,
                textColor: AppColors.primaryColor,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              CustomText.caption(text: hint, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dashed outline, which Flutter has no built-in for.
class DottedBorder extends StatelessWidget {
  const DottedBorder({
    super.key,
    required this.color,
    required this.fill,
    required this.child,
  });

  final Color color;
  final Color fill;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashedRectPainter(color: color),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
          ),
          child: child,
        ),
      );
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppStyles.borderRadiusMediumValue),
    );
    // Walk the outline, drawing every other segment.
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, (distance + dash).clamp(0, metric.length)),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => old.color != color;
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusPillValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryColorLight : AppColors.cardColor,
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusPillValue),
          border: Border.all(
            color: selected ? AppColors.primaryColor : AppColors.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: CustomText.body(
          text: label,
          fontSize: 14,
          textColor: selected ? AppColors.primaryColor : AppColors.textColor,
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.path,
    required this.onRetake,
    required this.onRemove,
  });

  final String path;
  final VoidCallback onRetake;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
            child: Image.file(
              File(path),
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 72,
                height: 72,
                color: AppColors.backgroundColor,
                child: const Icon(Icons.broken_image_outlined, size: 22),
              ),
            ),
          ),
          horizontalSpaceSmall,
          Expanded(child: CustomText.body(text: 'Photo attached', fontSize: 14)),
          IconButton(
            onPressed: onRetake,
            icon: const Icon(Icons.photo_camera_outlined, size: 20),
            tooltip: 'Replace',
            color: AppColors.secondaryColor,
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Remove',
            color: AppColors.secondaryColor,
          ),
        ],
      ),
    );
  }
}
