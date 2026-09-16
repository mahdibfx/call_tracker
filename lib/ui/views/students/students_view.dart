import 'dart:async';

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
  final _scrollController = ScrollController();
  Timer? _searchDebounce;

  String _query = '';
  List<Student> _students = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _inFlight = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
    RefreshSignal.listenable.addListener(_loadFirstPage);
  }

  @override
  void dispose() {
    RefreshSignal.listenable.removeListener(_loadFirstPage);
    _searchDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// The roster is thousands of students, so it arrives a page at a time and
  /// searching happens server-side rather than over what's been loaded.
  Future<void> _loadFirstPage() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final page = await ApiService.getStudents(page: 1, search: _query);
      if (!mounted) return;
      setState(() {
        // A failed fetch keeps whatever the list already had — losing the
        // roster to one bad refresh would be worse than showing it stale.
        if (page != null) {
          _students = page.items;
          _page = page.page;
          _totalPages = page.totalPages;
        }
        _failed = page == null;
        _loading = false;
      });
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _loadNextPage() async {
    if (_inFlight || _loadingMore || _page >= _totalPages) return;
    _inFlight = true;
    setState(() => _loadingMore = true);
    try {
      final page = await ApiService.getStudents(page: _page + 1, search: _query);
      if (!mounted) return;
      setState(() {
        if (page != null) {
          _students = [..._students, ...page.items];
          _page = page.page;
          _totalPages = page.totalPages;
        }
        _loadingMore = false;
      });
    } finally {
      _inFlight = false;
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) _loadNextPage();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || value.trim() == _query) return;
      setState(() {
        _query = value.trim();
        _loading = true;
      });
      _loadFirstPage();
    });
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
              onChanged: _onSearchChanged,
            ),
          ),
          verticalSpaceMedium,
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadFirstPage,
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
    if (_students.isEmpty) {
      // Still a ListView so the empty state can be pulled down to refresh.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
        children: [
          Center(
            child: CustomText.subtitle(
              text: _query.isNotEmpty
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
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _students.length + (_page < _totalPages ? 1 : 0),
      separatorBuilder: (_, _) => verticalSpaceSmall,
      itemBuilder: (context, i) {
        if (i >= _students.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final student = _students[i];
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

  static String _formatDate(DateTime date) {
    final d = date.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final lastCall = student.lastCall;
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
                  CustomText.bodyBold(text: student.name, fontSize: 15, maxLines: 1),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.call, size: 13, color: AppColors.secondaryColor),
                      horizontalSpaceTiny,
                      CustomText.subtitle(
                        text: student.hasPhone ? student.phone : 'No number on file',
                      ),
                    ],
                  ),
                  if (lastCall != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.history, size: 13, color: AppColors.secondaryColor),
                        horizontalSpaceTiny,
                        CustomText.subtitle(text: 'Called at ${_formatDate(lastCall.date)}'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
