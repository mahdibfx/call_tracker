import 'package:flutter/material.dart';
import 'package:call_tracker/data/auth_service.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/views/login/login_view.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// Shared top bar: leading icon (menu or back) + title + profile circle.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.backgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: Icon(onBack != null ? Icons.arrow_back : Icons.menu, color: AppColors.textColor),
        onPressed: onBack ?? () {},
      ),
      title: subtitle == null
          ? CustomText.title(text: title, fontSize: 18)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText.bodyBold(text: title, fontSize: 17),
                CustomText.caption(text: subtitle!),
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
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginView()),
      (route) => false,
    );
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
