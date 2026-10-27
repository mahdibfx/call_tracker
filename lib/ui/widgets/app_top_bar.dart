import 'package:flutter/material.dart';
import 'package:call_tracker/data/auth_service.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/widgets/avatar_circle.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// Shared top bar: leading icon (menu or back) + title + profile circle.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.showUser = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// On a root screen, show who is signed in: their initials as the leading
  /// circle and their role under the title. Pushed screens leave this off and
  /// get a back arrow instead.
  final bool showUser;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final user = showUser ? AuthService.signedIn.value : null;
    // Falls back to the plain title when the role is unknown, so the bar never
    // renders an empty second line.
    final secondLine = subtitle ?? user?.role?.displayLabel;
    return AppBar(
      backgroundColor: AppColors.backgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      leadingWidth: 56,
      leading: switch ((onBack, user)) {
        (final VoidCallback back, _) => IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textColor),
            onPressed: back,
          ),
        (null, final Agent u) => Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(child: AvatarCircle(name: u.name, size: 32)),
          ),
        // No back action and nobody to show: leave the slot empty rather than
        // render an icon that does nothing.
        (null, null) => const SizedBox.shrink(),
      },
      title: secondLine == null
          ? CustomText.title(text: title, fontSize: 18)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText.bodyBold(text: title, fontSize: 17),
                CustomText.caption(text: secondLine),
              ],
            ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: trailing ?? const _ProfileAvatar(),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  Future<void> _handleTap(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed != true) return;
    // AuthGate watches the signed-in state and swaps in the login screen, so
    // there is nothing to navigate to here.
    await AuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _handleTap(context),
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primaryColor, width: 1.5),
          color: AppColors.primaryColorLight,
        ),
        child: const Icon(Icons.person, color: AppColors.primaryColor, size: 20),
      ),
    );
  }
}
