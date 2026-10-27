import 'package:flutter/material.dart';
import 'package:call_tracker/data/report_models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// Picks where the problem is. Optional on a report.
///
/// There are 28 rooms, so this is a plain grid — no search to maintain.
Future<Room?> showRoomPicker(BuildContext context, List<Room> rooms) {
  return showModalBottomSheet<Room>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppStyles.borderRadiusLargeValue),
      ),
    ),
    builder: (context) => _RoomPicker(rooms: rooms),
  );
}

class _RoomPicker extends StatelessWidget {
  const _RoomPicker({required this.rooms});

  final List<Room> rooms;

  @override
  Widget build(BuildContext context) {
    // Floors, so a long flat list of codes becomes something you can scan.
    final byFloor = <int?, List<Room>>{};
    for (final room in rooms) {
      byFloor.putIfAbsent(room.floorNumber, () => []).add(room);
    }
    final floors = byFloor.keys.toList()
      ..sort((a, b) => (a ?? 1 << 30).compareTo(b ?? 1 << 30));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .6,
      maxChildSize: .9,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(child: CustomText.bodyBold(text: 'Where?', fontSize: 16)),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.secondaryColor,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                for (final floor in floors) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: CustomText.caption(
                      text: floor == null ? 'OTHER' : 'FLOOR $floor',
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final room in byFloor[floor]!)
                        InkWell(
                          onTap: () => Navigator.of(context).pop(room),
                          borderRadius:
                              BorderRadius.circular(AppStyles.borderRadiusPillValue),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundColor,
                              borderRadius: BorderRadius.circular(
                                AppStyles.borderRadiusPillValue,
                              ),
                              border: Border.all(color: AppColors.borderColor),
                            ),
                            child: CustomText.body(text: room.roomIndex, fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
