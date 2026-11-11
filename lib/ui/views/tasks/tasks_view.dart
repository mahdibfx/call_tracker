import 'package:flutter/material.dart';
import 'package:call_tracker/data/refresh_signal.dart';
import 'package:call_tracker/data/task_api.dart';
import 'package:call_tracker/data/task_models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/views/tasks/task_detail_view.dart';
import 'package:call_tracker/ui/views/tasks/widgets/task_card.dart';
import 'package:call_tracker/ui/widgets/app_top_bar.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// Lists of students the office has asked this agent to ring.
///
/// Read-only as a list: an agent never creates a task and never sets a task's
/// status. They open one and record what happened on each line; the backend
/// moves the task along from there. So there is no FAB here.
class TasksView extends StatefulWidget {
  const TasksView({super.key});

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  final _scrollController = ScrollController();

  /// The tab an agent wants on opening: what is still to do. Finished tasks
  /// are a lookup, not the daily view.
  static const _open = [TaskStatus.pending, TaskStatus.inProgress];

  List<Task> _tasks = [];
  TaskCounts _counts = const TaskCounts();

  /// Null means the "To do" tab — the open statuses, not every status.
  TaskStatus? _filter;
  bool _loading = true;
  bool _failed = false;
  bool _inFlight = false;
  int _page = 1;
  int _totalPages = 1;

  List<TaskStatus> get _statuses => _filter == null ? _open : [_filter!];

  @override
  void initState() {
    super.initState();
    _load();
    RefreshSignal.listenable.addListener(_load);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    RefreshSignal.listenable.removeListener(_load);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final result = await TaskApi.getTasks(statuses: _statuses);
      if (!mounted) return;
      setState(() {
        // A failed fetch keeps what is on screen — the house rule.
        if (result != null) {
          _tasks = result.page.items;
          _page = result.page.page;
          _totalPages = result.page.totalPages;
          _counts = result.counts;
        }
        _failed = result == null;
        _loading = false;
      });
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _loadMore() async {
    if (_inFlight || _page >= _totalPages) return;
    _inFlight = true;
    try {
      final next = await TaskApi.getTasks(statuses: _statuses, page: _page + 1);
      if (!mounted || next == null) return;
      setState(() {
        _tasks = [..._tasks, ...next.page.items];
        _page = next.page.page;
        _totalPages = next.page.totalPages;
      });
    } finally {
      _inFlight = false;
    }
  }

  void _onFilterChanged(TaskStatus? status) {
    setState(() {
      _filter = status;
      _loading = true;
      _tasks = [];
    });
    _load();
  }

  Future<void> _openTask(Task task) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskDetailView(task: task)),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const AppTopBar(title: 'Tasks', showUser: true),
      body: Column(
        children: [
          verticalSpaceSmall,
          _filterBar(),
          verticalSpaceSmall,
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

  /// Carries the counts, because the number of tasks waiting is the single
  /// most useful thing on this screen and it survives whichever tab is open.
  Widget _filterBar() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            label: 'To do',
            count: _counts.open,
            selected: _filter == null,
            onTap: () => _onFilterChanged(null),
          ),
          for (final status in TaskStatus.values) ...[
            horizontalSpaceSmall,
            _Chip(
              label: status.label,
              count: _counts.forStatus(status),
              selected: _filter == status,
              onTap: () => _onFilterChanged(status),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_tasks.isEmpty) {
      return _message(
        _failed
            ? "Couldn't load your tasks — pull down to retry."
            : _filter == null
                ? 'Nothing to do right now.'
                : 'Nothing ${_filter!.label.toLowerCase()}.',
      );
    }
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _tasks.length + (_page < _totalPages ? 1 : 0),
      separatorBuilder: (_, _) => verticalSpaceSmall,
      itemBuilder: (context, i) {
        if (i >= _tasks.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final task = _tasks[i];
        return TaskCard(task: task, onTap: () => _openTask(task));
      },
    );
  }

  Widget _message(String text) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
        children: [
          Center(
            child: CustomText.body(
              text: text,
              fontSize: 13,
              textColor: AppColors.secondaryColor,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? AppColors.primaryColor : AppColors.secondaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryColorLight : AppColors.cardColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primaryColor : AppColors.borderColor,
          ),
        ),
        child: Row(
          children: [
            CustomText.caption(text: label, textColor: accent),
            // A zero is noise: an empty tab says so by being empty.
            if (count > 0) ...[
              const SizedBox(width: 5),
              CustomText.caption(text: '$count', textColor: accent),
            ],
          ],
        ),
      ),
    );
  }
}
