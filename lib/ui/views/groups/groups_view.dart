import 'package:flutter/material.dart';
import 'package:call_tracker/data/api_service.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/data/refresh_signal.dart';
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
  List<Group> _groups = [];
  bool _loading = true;
  bool _inFlight = false;
  bool _failed = false;

  /// Rosters are fetched per group the first time it's expanded — the groups
  /// payload no longer carries its student ids. Keyed by group id.
  final Map<String, List<Student>> _rosters = {};
  final Set<String> _rostersLoading = {};

  @override
  void initState() {
    super.initState();
    _load();
    RefreshSignal.listenable.addListener(_load);
  }

  @override
  void dispose() {
    RefreshSignal.listenable.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final groups = await ApiService.getGroups();
      if (!mounted) return;
      setState(() {
        // A failed fetch keeps whatever the list already had — see StudentsView.
        if (groups != null) _groups = groups;
        _failed = groups == null;
        _loading = false;
        // Rosters may be stale after a refresh; drop them so an expanded
        // group refetches rather than showing an out-of-date list.
        _rosters.clear();
      });
      final expanded = _expandedGroup;
      if (expanded != null) _loadRoster(expanded);
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _loadRoster(String groupId) async {
    if (_rostersLoading.contains(groupId)) return;
    _rostersLoading.add(groupId);
    try {
      final page = await ApiService.getGroupStudents(groupId);
      if (!mounted || page == null) return;
      setState(() => _rosters[groupId] = page.items);
    } finally {
      _rostersLoading.remove(groupId);
    }
  }

  void _toggleGroup(Group group) {
    final expanded = _expandedGroup == group.id;
    setState(() => _expandedGroup = expanded ? null : group.id);
    if (!expanded && !_rosters.containsKey(group.id)) _loadRoster(group.id);
  }

  List<Group> get _filtered => _groups.where((g) => g.name.toLowerCase().contains(_query.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const AppTopBar(title: 'Student Groups', showUser: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CustomInput(hintText: 'Search groups...', prefixIcon: Icons.search, onChanged: (v) => setState(() => _query = v)),
          ),
          verticalSpaceMedium,
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primaryColor,
              child: _buildList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final groups = _filtered;
    if (groups.isEmpty) {
      // Still a ListView so the empty state can be pulled down to refresh.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
        children: [
          Center(
            child: CustomText.subtitle(
              text: _groups.isNotEmpty
                  ? 'No groups match your search.'
                  : _failed
                      ? "Couldn't load groups — pull down to retry."
                      : 'No groups yet — pull down to refresh.',
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: groups.length,
      separatorBuilder: (_, _) => verticalSpaceSmall,
      itemBuilder: (context, i) {
        final group = groups[i];
        return _GroupCard(
          group: group,
          students: _rosters[group.id],
          rosterLoading: _rostersLoading.contains(group.id),
          expanded: _expandedGroup == group.id,
          onTap: () => _toggleGroup(group),
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.students,
    required this.rosterLoading,
    required this.expanded,
    required this.onTap,
  });

  final Group group;

  /// Null until this group's roster has been fetched.
  final List<Student>? students;
  final bool rosterLoading;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final groupStudents = students;
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
                        if (group.category.isNotEmpty || group.type.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.local_offer_outlined, size: 14, color: AppColors.secondaryColor),
                              horizontalSpaceTiny,
                              Expanded(
                                child: CustomText.subtitle(
                                  text: [group.category, group.type]
                                      .where((v) => v.isNotEmpty)
                                      .join(' • '),
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (group.teacherName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 14, color: AppColors.secondaryColor),
                              horizontalSpaceTiny,
                              Expanded(
                                child: CustomText.subtitle(text: group.teacherName, maxLines: 1),
                              ),
                            ],
                          ),
                        ],
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
                  if (groupStudents == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: rosterLoading
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : Center(child: CustomText.subtitle(text: "Couldn't load this group's students.")),
                    )
                  else if (groupStudents.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CustomText.subtitle(text: 'No students in this group yet.')),
                    )
                  else
                    ...groupStudents.map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => StudentDetailView(student: s, groupName: group.name)),
                          ),
                          child: Row(
                            children: [
                              AvatarCircle(name: s.name, size: 36),
                              horizontalSpaceSmall,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomText.bodyBold(text: s.name, fontSize: 14, maxLines: 1),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.call, size: 12, color: AppColors.secondaryColor),
                                        horizontalSpaceTiny,
                                        Expanded(
                                          child: CustomText.subtitle(
                                            text: s.phoneSummary,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (s.lastCall != null) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.history, size: 12, color: AppColors.secondaryColor),
                                          horizontalSpaceTiny,
                                          Expanded(
                                            child: CustomText.subtitle(
                                              text: 'Called at ${s.lastCall!.formattedDate}',
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
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
