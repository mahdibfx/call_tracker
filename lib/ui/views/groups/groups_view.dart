import 'package:flutter/material.dart';
import 'package:call_tracker/data/dummy_data.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/views/student_detail/student_detail_view.dart';
import 'package:call_tracker/ui/widgets/app_top_bar.dart';
import 'package:call_tracker/ui/widgets/avatar_circle.dart';
import 'package:call_tracker/ui/widgets/custom_input.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

class GroupsView extends StatefulWidget {
  const GroupsView({super.key});

  @override
  State<GroupsView> createState() => _GroupsViewState();
}

class _GroupsViewState extends State<GroupsView> {
  String _query = '';
  String? _expandedGroup;

  List<Group> get _filtered => dummyGroups.where((g) => g.name.toLowerCase().contains(_query.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const AppTopBar(title: 'Student Groups', subtitle: 'Communication Cycles'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CustomInput(hintText: 'Search groups...', prefixIcon: Icons.search, onChanged: (v) => setState(() => _query = v)),
          ),
          verticalSpaceMedium,
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _filtered.length,
              separatorBuilder: (_, _) => verticalSpaceSmall,
              itemBuilder: (context, i) {
                final group = _filtered[i];
                final expanded = _expandedGroup == group.name;
                return _GroupCard(
                  group: group,
                  expanded: expanded,
                  onTap: () => setState(() => _expandedGroup = expanded ? null : group.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.expanded, required this.onTap});

  final Group group;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final students = dummyStudents.where((s) => group.studentIds.contains(s.id)).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(AppStyles.borderRadiusLargeValue),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppStyles.borderRadiusLargeValue),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText.bodyBold(text: group.name, fontSize: 17),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.groups, size: 15, color: AppColors.primaryColor),
                            horizontalSpaceTiny,
                            CustomText.subtitle(text: '${group.studentCount} Students'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.secondaryColor),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1, color: AppColors.borderColor),
                  verticalSpaceSmall,
                  ...students.map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => StudentDetailView(student: s, groupName: group.name)),
                          ),
                          child: Row(
                            children: [
                              AvatarCircle(name: s.name, size: 36),
                              horizontalSpaceSmall,
                              Expanded(child: CustomText.bodyBold(text: s.name, fontSize: 14)),
                              const Icon(Icons.chevron_right, color: AppColors.secondaryColor, size: 18),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
