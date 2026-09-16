import 'package:flutter/material.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/widgets/app_top_bar.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

// ponytail: no design provided yet for the real dashboard, placeholder until one exists.
class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const AppTopBar(title: 'Dashboard'),
      body: Center(child: CustomText.subtitle(text: 'Dashboard coming soon')),
    );
  }
}
