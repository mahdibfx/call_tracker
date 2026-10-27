import 'dart:io';

import 'package:flutter/material.dart';
import 'package:call_tracker/data/auth_service.dart';
import 'package:call_tracker/data/photo_capture.dart';
import 'package:call_tracker/data/report_api.dart';
import 'package:call_tracker/data/report_models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/views/reports/widgets/category_picker_sheet.dart';
import 'package:call_tracker/ui/views/reports/widgets/room_picker_sheet.dart';
import 'package:call_tracker/ui/widgets/app_top_bar.dart';
import 'package:call_tracker/ui/widgets/custom_button.dart';
import 'package:call_tracker/ui/widgets/custom_input.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

/// Files a new report. Pops `true` once one has been created.
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
    // Enables the submit button the moment there is something to send.
    _descriptionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadPickers() async {
    // Every category, not just this role's: anyone may report anything.
    final categories = await ReportApi.getCategories();
    final rooms = await ReportApi.getRooms();
    if (!mounted) return;
    setState(() {
      if (categories != null) _categories = categories;
      if (rooms != null) _rooms = rooms;
    });
  }

  /// The backend needs one of the two. Said up front rather than as an error
  /// after a failed submit.
  bool get _canSubmit =>
      _descriptionController.text.trim().isNotEmpty || _imagePath != null;

  Future<void> _takePhoto() async {
    final path = await PhotoCapture.takePhoto();
    if (!mounted || path == null) return;
    setState(() => _imagePath = path);
  }

  Future<void> _pickCategory() async {
    if (_categories.isEmpty) return;
    final picked = await showCategoryPicker(
      context,
      categories: _categories,
      ownRole: AuthService.signedIn.value?.role,
    );
    if (!mounted || picked == null) return;
    setState(() => _category = picked);
  }

  Future<void> _pickRoom() async {
    if (_rooms.isEmpty) return;
    final picked = await showRoomPicker(context, _rooms);
    if (!mounted || picked == null) return;
    setState(() => _room = picked);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final created = await ReportApi.createReport(
      categoryId: _category?.id,
      description: _descriptionController.text,
      imagePath: _imagePath,
      roomId: _room?.id,
    );
    if (!mounted) return;
    if (created == null) {
      setState(() => _submitting = false);
      showTopSnackBar(
        Overlay.of(context),
        const CustomSnackBar.error(
          message: "Couldn't send the report. Check your connection and try again.",
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppTopBar(
        title: 'Report a problem',
        onBack: () => Navigator.of(context).pop(),
        trailing: const SizedBox.shrink(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          CustomText.bodyBold(text: 'What is wrong?', fontSize: 16),
          verticalSpaceSmall,
          _PickerField(
            icon: Icons.category_outlined,
            label: 'Category',
            value: _category?.name,
            placeholder: _categories.isEmpty ? 'Loading…' : 'Choose a category',
            onTap: _categories.isEmpty ? null : _pickCategory,
          ),
          verticalSpaceMedium,
          CustomText.bodyBold(text: 'Describe it', fontSize: 16),
          verticalSpaceSmall,
          CustomInput(
            hintText: 'What happened, and where exactly?',
            controller: _descriptionController,
            maxLines: 5,
            minLines: 4,
          ),
          verticalSpaceMedium,
          CustomText.bodyBold(text: 'Photo', fontSize: 16),
          const SizedBox(height: 2),
          CustomText.caption(text: 'A photo makes a report much easier to act on.'),
          verticalSpaceSmall,
          if (_imagePath == null)
            CustomButton(
              text: 'Take a photo',
              icon: Icons.photo_camera_outlined,
              onPressed: _takePhoto,
              backgroundColor: AppColors.cardColor,
              foregroundColor: AppColors.textColor,
            )
          else
            _PhotoRow(
              path: _imagePath!,
              onRetake: _takePhoto,
              onRemove: () => setState(() => _imagePath = null),
            ),
          verticalSpaceMedium,
          CustomText.bodyBold(text: 'Room', fontSize: 16),
          const SizedBox(height: 2),
          CustomText.caption(text: 'Optional'),
          verticalSpaceSmall,
          _PickerField(
            icon: Icons.meeting_room_outlined,
            label: 'Room',
            value: _room?.display,
            placeholder: _rooms.isEmpty ? 'Loading…' : 'Choose a room',
            onTap: _rooms.isEmpty ? null : _pickRoom,
            onClear: _room == null ? null : () => setState(() => _room = null),
          ),
          verticalSpaceLarge,
          CustomButton(
            // CustomButton has no busy state, so the label carries it — the
            // same thing the login screen does.
            text: _submitting ? 'Sending…' : 'Send report',
            icon: _submitting ? null : Icons.send,
            onPressed: (_canSubmit && !_submitting) ? _submit : null,
          ),
          if (!_canSubmit) ...[
            verticalSpaceSmall,
            Center(
              child: CustomText.caption(
                text: 'Add a description or a photo first.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final chosen = value != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusMediumValue),
          border: Border.all(
            color: chosen ? AppColors.primaryColor : AppColors.borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: chosen ? AppColors.primaryColor : AppColors.secondaryColor,
            ),
            horizontalSpaceSmall,
            Expanded(
              child: chosen
                  ? CustomText.body(text: value!, fontSize: 14, maxLines: 2)
                  : CustomText.subtitle(text: placeholder),
            ),
            if (onClear != null)
              InkWell(
                onTap: onClear,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: AppColors.secondaryColor),
                ),
              )
            else
              const Icon(Icons.chevron_right, size: 18, color: AppColors.secondaryColor),
          ],
        ),
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
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
            tooltip: 'Retake',
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
