import 'package:flutter/material.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/widgets/app_top_bar.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// Problem reports: submit one, and handle the ones your role is responsible
/// for.
///
/// ponytail: placeholder shell so the role-based routing lands on its own. The
/// list, filters and compose flow come next.
class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const AppTopBar(title: 'Reports', showUser: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CustomText.subtitle(
            text: 'Reports are coming next.',
            maxLines: 2,
          ),
        ),
      ),
    );
  }
}
