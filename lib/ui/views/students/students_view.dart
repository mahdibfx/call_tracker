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

class StudentsView extends StatefulWidget {
  const StudentsView({super.key});

  @override
  State<StudentsView> createState() => _StudentsViewState();
}

class _StudentsViewState extends State<StudentsView> {
  static const _levels = ['All Levels', 'A1', 'A2', 'B1', 'B2'];
  String _selectedLevel = 'All Levels';
  String _query = '';
  List<Student> _students = [];
  bool _loading = true;
  bool _inFlight = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    RefreshSignal.listenable.addListener(_loadStudents);
  }

  @override
  void dispose() {
    RefreshSignal.listenable.removeListener(_loadStudents);
    super.dispose();
  }

  Future<void> _loadStudents() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final students = await ApiService.getStudents();
      if (!mounted) return;
      setState(() {
        // A failed fetch keeps whatever the list already had — losing the
        // roster to one bad refresh would be worse than showing it stale.
        if (students != null) _students = students;
        _failed = students == null;
        _loading = false;
      });
    } finally {
      _inFlight = false;
    }
  }

  List<Student> get _filtered {
    return _students.where((s) {
      final matchesLevel = _selectedLevel == 'All Levels' || s.level == _selectedLevel;
      final matchesQuery = _query.isEmpty ||
          s.name.toLowerCase().contains(_query.toLowerCase()) ||
          s.phone.contains(_query);
      return matchesLevel && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const AppTopBar(title: 'Language Institute'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CustomText.headline(text: 'All Students'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: CustomInput(
              hintText: 'Search by name or number...',
              prefixIcon: Icons.search,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          verticalSpaceMedium,
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _levels.length,
              separatorBuilder: (_, _) => horizontalSpaceSmall,
              itemBuilder: (context, i) {
                final level = _levels[i];
                final selected = level == _selectedLevel;
                return ChoiceChip(
                  label: Text(level),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedLevel = level),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primaryColor : AppColors.secondaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  backgroundColor: AppColors.cardColor,
                  selectedColor: AppColors.primaryColorLight,
                  side: BorderSide(color: selected ? AppColors.primaryColor : AppColors.borderColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppStyles.borderRadiusPillValue)),
                );
              },
            ),
          ),
          verticalSpaceMedium,
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadStudents,
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
    final students = _filtered;
    if (students.isEmpty) {
      // Still a ListView so the empty state can be pulled down to refresh.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
        children: [
          Center(
            child: CustomText.subtitle(
              text: _students.isNotEmpty
                  ? 'No students match your search.'
                  : _failed
                      ? "Couldn't load students — pull down to retry."
                      : 'No students yet — pull down to refresh.',
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: students.length,
      separatorBuilder: (_, _) => verticalSpaceSmall,
      itemBuilder: (context, i) {
        final student = students[i];
        return _StudentRow(
          student: student,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => StudentDetailView(student: student)),
          ),
        );
      },
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student, required this.onTap});

  final Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusLargeValue),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(AppStyles.borderRadiusLargeValue),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            AvatarCircle(name: student.name),
            horizontalSpaceMedium,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText.bodyBold(text: student.name, fontSize: 15),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.call, size: 13, color: AppColors.secondaryColor),
                      horizontalSpaceTiny,
                      CustomText.subtitle(text: student.phone),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
