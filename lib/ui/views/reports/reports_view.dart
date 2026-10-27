import 'package:flutter/material.dart';
import 'package:call_tracker/data/refresh_signal.dart';
import 'package:call_tracker/data/report_api.dart';
import 'package:call_tracker/data/report_models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/views/reports/report_compose_view.dart';
import 'package:call_tracker/ui/views/reports/report_detail_view.dart';
import 'package:call_tracker/ui/views/reports/widgets/report_card.dart';
import 'package:call_tracker/ui/views/reports/widgets/state_filter_bar.dart';
import 'package:call_tracker/ui/widgets/app_top_bar.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

/// Problem reports: file one, and work the ones your role is responsible for.
///
/// What a user can see is decided by the backend — own-role categories plus
/// anything they filed themselves, or everything for an admin — so this never
/// filters the list itself.
class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  final _scrollController = ScrollController();

  List<Report> _reports = [];
  ReportState? _filter;
  bool _loading = true;
  bool _failed = false;
  bool _inFlight = false;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _load();
    // The tabs live in an IndexedStack, so initState runs once a session.
    // Without this the list would never refresh for a role that has tabs.
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
      final page = await ReportApi.getReports(
        states: _filter == null ? const [] : [_filter!],
      );
      if (!mounted) return;
      setState(() {
        // A failed fetch keeps what is already on screen rather than blanking
        // the list on a flaky connection.
        if (page != null) {
          _reports = page.items;
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

  Future<void> _loadMore() async {
    if (_inFlight || _page >= _totalPages) return;
    _inFlight = true;
    try {
      final next = await ReportApi.getReports(
        states: _filter == null ? const [] : [_filter!],
        page: _page + 1,
      );
      if (!mounted || next == null) return;
      setState(() {
        _reports = [..._reports, ...next.items];
        _page = next.page;
        _totalPages = next.totalPages;
      });
    } finally {
      _inFlight = false;
    }
  }

  void _onFilterChanged(ReportState? state) {
    setState(() {
      _filter = state;
      _loading = true;
      _reports = [];
    });
    _load();
  }

  Future<void> _openCompose() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ReportComposeView()),
    );
    if (created == true) await _load();
  }

  Future<void> _open(Report report) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ReportDetailView(report: report)),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const AppTopBar(title: 'Reports', showUser: true),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCompose,
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        tooltip: 'Report a problem',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          verticalSpaceSmall,
          StateFilterBar(selected: _filter, onChanged: _onFilterChanged),
          verticalSpaceSmall,
          Expanded(
            // ponytail: mandatory, not decoration — roles with a single area
            // have no tab to switch, so RefreshSignal never fires for them and
            // this is their only way to pull new reports in.
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
    if (_reports.isEmpty) {
      return _message(
        _failed
            ? "Couldn't load reports — pull down to retry."
            : _filter == null
                ? 'No reports yet. Tap + to report a problem.'
                : 'Nothing ${_filter!.label.toLowerCase()}.',
      );
    }
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      itemCount: _reports.length + (_page < _totalPages ? 1 : 0),
      separatorBuilder: (_, _) => verticalSpaceSmall,
      itemBuilder: (context, i) {
        if (i >= _reports.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final report = _reports[i];
        return ReportCard(report: report, onTap: () => _open(report));
      },
    );
  }

  /// A ListView so an empty or failed state can still be pulled to refresh.
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
