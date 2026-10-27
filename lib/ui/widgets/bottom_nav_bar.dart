import 'package:flutter/material.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/views/root/app_area.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.areas,
    required this.currentIndex,
    required this.onTap,
  });

  /// The signed-in user's areas, in the same order `RootView` stacks them —
  /// both come from `AppArea.forUser`, so an index always names its screen.
  final List<AppArea> areas;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            children: List.generate(areas.length, (i) {
              final selected = i == currentIndex;
              final item = areas[i];
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primaryColorLight : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            item.icon,
                            color: selected ? AppColors.primaryColor : AppColors.secondaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        CustomText.caption(
                          text: item.label,
                          textColor: selected ? AppColors.primaryColor : AppColors.secondaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
