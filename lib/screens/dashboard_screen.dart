import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../widgets/tab_visibility.dart';
import '../services/current_user.dart';
import '../services/payment_data.dart';
import '../services/attendance_data.dart';
import '../widgets/ai_insight_card.dart';
import '../widgets/state_views.dart';
import '../services/dashboard_stats_service.dart';
import '../services/dashboard_analytics_service.dart';

enum RevenuePeriod { weekly, monthly, yearly }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with PollingScreenMixin<DashboardScreen> {
  RevenuePeriod _revenuePeriod = RevenuePeriod.monthly;
  DashboardStats? _dashboardStats;

  // ---- Real, backend-driven analytics state ----
  List<ChurnRiskMember> _churnRisk = [];
  bool _loadingChurnRisk = true;

  ChurnForecast? _churnForecast;
  bool _loadingChurnForecast = true;

  ChartSeries? _revenueSeries;
  bool _loadingRevenue = true;

  ChartSeries? _attendanceSeries;
  bool _loadingAttendance = true;

  ChartSeries? _monthlyAttendanceSeries;
  bool _loadingMonthlyAttendance = true;

  List<ExpiringMember> _expiringMembers = [];
  bool _loadingExpiring = true;

  List<AppNotification> _notifications = [];
  bool _loadingNotifications = true;

  List<TodayWalkInEntry> _todaysWalkIns = [];
  bool _loadingTodaysWalkIns = true;

  List<TodayMemberEntry> _todaysMemberAttendance = [];
  bool _loadingTodaysMemberAttendance = true;

  @override
  void initState() {
    super.initState();
    PaymentData.instance.addListener(_onDataChanged);
    AttendanceData.instance.addListener(_onDataChanged);
  }

  // Refresh cadence while the Dashboard is the visible tab. Polling pauses
  // entirely while another tab is on screen (see PollingScreenMixin).
  @override
  Duration get pollInterval => const Duration(seconds: 30);

  @override
  void onInitialLoad() {
    _loadDashboardStats();
    _loadChurnRisk();
    _loadChurnForecast();
    _loadRevenueAnalytics();
    _loadAttendanceAnalytics();
    _loadMonthlyAttendanceAnalytics();
    _loadExpiringMemberships();
    _loadRecentNotifications();
    _loadTodaysWalkIns();
    _loadTodaysMemberAttendance();
  }

  // Keep the dashboard in sync with what's happening in Attendance/Billing
  // without requiring a manual refresh.
  @override
  void onPoll() {
    _loadDashboardStats(silent: true);
    _loadChurnRisk(silent: true);
    _loadRevenueAnalytics(silent: true);
    _loadAttendanceAnalytics(silent: true);
    _loadMonthlyAttendanceAnalytics(silent: true);
    _loadExpiringMemberships(silent: true);
    _loadRecentNotifications(silent: true);
    _loadTodaysWalkIns(silent: true);
    _loadTodaysMemberAttendance(silent: true);
  }

  Future<void> _loadDashboardStats({bool silent = false}) async {
    final stats = await DashboardStatsService.fetch();
    if (mounted && stats != null) {
      setState(() => _dashboardStats = stats);
    }
  }

  Future<void> _loadChurnRisk({bool silent = false}) async {
    if (!silent) setState(() => _loadingChurnRisk = true);
    final list = await DashboardAnalyticsService.fetchChurnRisk();
    if (mounted) {
      setState(() {
        _churnRisk = list;
        _loadingChurnRisk = false;
      });
    }
  }

  Future<void> _loadChurnForecast({bool silent = false}) async {
    if (!silent) setState(() => _loadingChurnForecast = true);
    final forecast = await DashboardAnalyticsService.fetchChurnForecast();
    if (mounted) {
      setState(() {
        _churnForecast = forecast;
        _loadingChurnForecast = false;
      });
    }
  }

  Future<void> _loadRevenueAnalytics({bool silent = false}) async {
    if (!silent) setState(() => _loadingRevenue = true);
    final series = await DashboardAnalyticsService.fetchRevenueAnalytics(_periodParam(_revenuePeriod));
    if (mounted) {
      setState(() {
        _revenueSeries = series;
        _loadingRevenue = false;
      });
    }
  }

  Future<void> _loadAttendanceAnalytics({bool silent = false}) async {
    if (!silent) setState(() => _loadingAttendance = true);
    final series = await DashboardAnalyticsService.fetchAttendanceAnalytics();
    if (mounted) {
      setState(() {
        _attendanceSeries = series;
        _loadingAttendance = false;
      });
    }
  }

  Future<void> _loadMonthlyAttendanceAnalytics({bool silent = false}) async {
    if (!silent) setState(() => _loadingMonthlyAttendance = true);
    final series = await DashboardAnalyticsService.fetchAttendanceAnalytics('monthly');
    if (mounted) {
      setState(() {
        _monthlyAttendanceSeries = series;
        _loadingMonthlyAttendance = false;
      });
    }
  }

  Future<void> _loadExpiringMemberships({bool silent = false}) async {
    if (!silent) setState(() => _loadingExpiring = true);
    final list = await DashboardAnalyticsService.fetchExpiringMemberships();
    if (mounted) {
      setState(() {
        _expiringMembers = list;
        _loadingExpiring = false;
      });
    }
  }

  Future<void> _loadRecentNotifications({bool silent = false}) async {
    if (!silent) setState(() => _loadingNotifications = true);
    final list = await DashboardAnalyticsService.fetchRecentNotifications();
    if (mounted) {
      setState(() {
        _notifications = list;
        _loadingNotifications = false;
      });
    }
  }

  Future<void> _loadTodaysWalkIns({bool silent = false}) async {
    if (!silent) setState(() => _loadingTodaysWalkIns = true);
    final list = await DashboardAnalyticsService.fetchTodaysWalkIns();
    if (mounted) {
      setState(() {
        _todaysWalkIns = list;
        _loadingTodaysWalkIns = false;
      });
    }
  }

  Future<void> _loadTodaysMemberAttendance({bool silent = false}) async {
    if (!silent) setState(() => _loadingTodaysMemberAttendance = true);
    final list = await DashboardAnalyticsService.fetchTodaysMemberAttendance();
    if (mounted) {
      setState(() {
        _todaysMemberAttendance = list;
        _loadingTodaysMemberAttendance = false;
      });
    }
  }

  String _periodParam(RevenuePeriod p) {
    switch (p) {
      case RevenuePeriod.weekly:
        return 'weekly';
      case RevenuePeriod.monthly:
        return 'monthly';
      case RevenuePeriod.yearly:
        return 'yearly';
    }
  }

  @override
  void dispose() {
    PaymentData.instance.removeListener(_onDataChanged);
    AttendanceData.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  String _formatCurrency(int amount) {
    if (amount < 1000) return '₱$amount';
    final parts = amount.toString().split('');
    var result = '';
    var count = 0;
    for (var i = parts.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result = ',$result';
      }
      result = '${parts[i]}$result';
      count++;
    }
    return '₱$result';
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = CurrentUser.isOwner;

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 900;
      final statCols = constraints.maxWidth >= 1100
          ? 4
          : constraints.maxWidth >= 650
              ? 2
              : 1;

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pageHeader(),
            const SizedBox(height: AppSpacing.section),
            GridView.count(
              crossAxisCount: statCols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: statCols == 1 ? 2.8 : 2.0,
              children: isOwner ? _ownerStatCards() : _staffStatCards(),
            ),
            const SizedBox(height: AppSpacing.section),

            if (isOwner) ...[
              const AiInsightCard(),
              const SizedBox(height: AppSpacing.section),
              _revenueAnalyticsCard(),
              const SizedBox(height: AppSpacing.section),
              _attendanceAnalyticsCard(),
              const SizedBox(height: AppSpacing.section),
              _monthlyAttendanceCard(),
              const SizedBox(height: AppSpacing.section),
              _expiringMembershipsCard(),
              const SizedBox(height: AppSpacing.section),
              isWide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _churnRiskCard()),
                          const SizedBox(width: 16),
                          Expanded(child: _aiChurnForecastCard()),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _churnRiskCard(),
                        const SizedBox(height: 16),
                        _aiChurnForecastCard(),
                      ],
                    ),
              const SizedBox(height: AppSpacing.section),
            ] else ...[
              _weeklyAttendanceCard(),
              const SizedBox(height: AppSpacing.section),
              _monthlyAttendanceCard(),
              const SizedBox(height: AppSpacing.section),
              _expiringMembershipsCard(),
              const SizedBox(height: AppSpacing.section),
              isWide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _churnRiskCard()),
                          const SizedBox(width: 16),
                          Expanded(child: _aiChurnForecastCard()),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _churnRiskCard(),
                        const SizedBox(height: 16),
                        _aiChurnForecastCard(),
                      ],
                    ),
              const SizedBox(height: AppSpacing.section),
              isWide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _attendanceListCard(
                            title: "Today's Walk-in Attendance",
                            entries: _walkInEntryMaps(),
                            loading: _loadingTodaysWalkIns,
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: _attendanceListCard(
                            title: "Today's Member Attendance",
                            entries: _memberEntryMaps(),
                            loading: _loadingTodaysMemberAttendance,
                          )),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _attendanceListCard(
                          title: "Today's Walk-in Attendance",
                          entries: _walkInEntryMaps(),
                          loading: _loadingTodaysWalkIns,
                        ),
                        const SizedBox(height: 16),
                        _attendanceListCard(
                          title: "Today's Member Attendance",
                          entries: _memberEntryMaps(),
                          loading: _loadingTodaysMemberAttendance,
                        ),
                      ],
                    ),
              const SizedBox(height: AppSpacing.section),
            ],

            _notificationsCard(),
            const SizedBox(height: AppSpacing.section),
          ],
        ),
      );
    });
  }

  // ---------- Page header (replaces the big cyan welcome banner) ----------

  Widget _pageHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppTheme.heading(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Here's what's happening with your gym today.",
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted(context)),
          ),
        ],
      ),
    );
  }

  // ---------- Small shared style helpers ----------

  /// Small uppercase gray card title (Haws Prints style).
  Widget _panelTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: AppTheme.textMuted(context),
      ),
    );
  }

  // ---------- Stat cards ----------

  List<Widget> _ownerStatCards() {
    final totalRevenue = _dashboardStats?.totalRevenue ?? 0;
    final stats = _dashboardStats;
    final churnCount = _churnRisk.length;
    final churnChange = _churnForecast != null
        ? '${_churnForecast!.riskRatePercent}% at risk'
        : (_loadingChurnRisk ? '—' : 'Watch');

    return [
      _KpiCard(
        icon: Icons.card_membership_outlined,
        change: '+12%',
        value: stats != null ? '${stats.activeSubscriptions}' : '—',
        label: 'Active Subscriptions',
      ),
      _KpiCard(
        icon: Icons.person_outline,
        change: '+8%',
        value: stats != null ? '${stats.activeMembers}' : '—',
        label: 'Active Members',
      ),
      _KpiCard(
        iconText: '₱',
        change: '+15%',
        value: _formatCurrency(totalRevenue),
        label: 'Total Revenue (This Year)',
      ),
      _KpiCard(
        icon: Icons.warning_amber_rounded,
        change: churnChange,
        value: _loadingChurnRisk ? '—' : '$churnCount',
        label: 'Churn Risk (Active Members)',
        accent: AppColors.warning,
      ),
    ];
  }

  List<Widget> _staffStatCards() {
    final stats = _dashboardStats;
    return [
      _KpiCard(
        icon: Icons.people_alt_outlined,
        change: '+12%',
        value: stats != null ? '${stats.activeSubscriptions}' : '—',
        label: 'Members on Plan',
      ),
      _KpiCard(
        icon: Icons.person_outline,
        change: '+8%',
        value: stats != null ? '${stats.activeMembers}' : '—',
        label: 'Active Members',
      ),
      _KpiCard(
        icon: Icons.trending_up,
        change: '+5%',
        value: stats != null ? '${stats.attendanceRate}%' : '—',
        label: "Today's Attendance Rate",
      ),
    ];
  }

  // ---------- Shared card wrapper ----------

  Widget _cardWrap({
    required String title,
    required Widget child,
    Widget? trailing,
    String? subtitle,
    double chartHeight = 240,
    Color? accent,
  }) {
    return _Panel(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _panelTitle(title),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTheme.cardSubtitle(context)),
                  ],
                ],
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(height: chartHeight, child: child),
        ],
      ),
    );
  }

  /// Small neutral tag (e.g. "AI Predicted", "Live").
  Widget _aiBadge({String label = 'AI Predicted'}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.subtleFill(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 12, color: AppColors.cyan),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted(context))),
        ],
      ),
    );
  }

  // ---------- Shared bar chart (weekly / monthly attendance) ----------

  Widget _attendanceBarChart({
    required List<String> labels,
    required List<double> values,
    required double maxY,
    required double interval,
  }) {
    return BarChart(
      BarChartData(
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: interval,
              reservedSize: 36,
              getTitlesWidget: (v, meta) => Text(v.toInt().toString(),
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted(context))),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(labels[i],
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted(context))),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(values.length, (i) {
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: values[i],
              color: AppColors.cyan,
              width: 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            ),
          ]);
        }),
      ),
    );
  }

  // ---------- Owner: Revenue Analytics (Weekly / Monthly / Yearly) ----------
  Widget _revenueAnalyticsCard() {
    final series = _revenueSeries;
    final values = series?.values ?? const <double>[];
    final labels = series?.labels ?? const <String>[];
    final maxRaw = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    final maxY = maxRaw > 0 ? maxRaw * 1.2 : 1.0;
    final interval = maxRaw > 0 ? maxRaw / 5 : 1.0;

    return _cardWrap(
      title: 'Revenue Analytics',
      subtitle: 'Actual revenue from membership and walk-in payments',
      trailing: _aiBadge(),
      chartHeight: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _periodSelector(),
          const SizedBox(height: 16),
          Expanded(
            child: _loadingRevenue
                ? const LoadingState()
                : values.isEmpty
                    ? const EmptyState(
                        icon: Icons.show_chart,
                        message: 'No revenue recorded for this period yet.')
                    : LineChart(
                        LineChartData(
                          maxY: maxY,
                          minY: 0,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: interval,
                            getDrawingHorizontalLine: (v) =>
                                FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: interval,
                                reservedSize: 56,
                                getTitlesWidget: (v, meta) => Text(_formatChartValue(v),
                                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted(context))),
                              ),
                            ),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, meta) {
                                  final i = v.toInt();
                                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(labels[i],
                                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted(context))),
                                  );
                                },
                              ),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                  values.length, (i) => FlSpot(i.toDouble(), values[i])),
                              isCurved: true,
                              curveSmoothness: 0.28,
                              color: AppColors.cyan,
                              barWidth: 3,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) =>
                                    FlDotCirclePainter(
                                        radius: 3.5,
                                        color: Theme.of(context).cardColor,
                                        strokeWidth: 2.5,
                                        strokeColor: AppColors.cyan),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.cyan.withValues(alpha: 0.16),
                                    AppColors.cyan.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// Weekly / Monthly / Yearly toggle, styled as a dark pill like the
  /// Haws Prints period switcher. Behavior is unchanged.
  Widget _periodSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark ? AppColors.cyan : const Color(0xFF111827);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: RevenuePeriod.values.map((p) {
          final selected = p == _revenuePeriod;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                setState(() => _revenuePeriod = p);
                _loadRevenueAnalytics();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? selectedBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _periodLabel(p),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppTheme.textMuted(context),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _periodLabel(RevenuePeriod p) {
    switch (p) {
      case RevenuePeriod.weekly:
        return 'Weekly';
      case RevenuePeriod.monthly:
        return 'Monthly';
      case RevenuePeriod.yearly:
        return 'Yearly';
    }
  }

  String _formatChartValue(double v) {
    if (v == 0) return '₱0';
    if (v >= 1000000) return '₱${(v / 1000000).toStringAsFixed(1)}m';
    if (v >= 1000) return '₱${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    return '₱${v.toInt()}';
  }

  // ---------- Owner: Weekly Attendance Analytics ----------
  Widget _attendanceAnalyticsCard() {
    final series = _attendanceSeries;
    final labels = series?.labels ?? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final values = series?.values ?? const <double>[];
    final maxRaw = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    final maxY = maxRaw > 0 ? maxRaw * 1.2 : 10.0;
    final interval = maxY / 4;

    return _cardWrap(
      title: 'Attendance Analytics',
      subtitle: "This week's actual foot traffic (member check-ins + walk-ins)",
      trailing: _aiBadge(label: 'Live'),
      child: _loadingAttendance
          ? const LoadingState()
          : values.isEmpty
              ? const EmptyState(
                  icon: Icons.bar_chart,
                  message: 'No attendance recorded yet this week.')
              : _attendanceBarChart(
                  labels: labels, values: values, maxY: maxY, interval: interval),
    );
  }

  // ---------- Monthly Attendance Analytics (owner + staff) ----------
  Widget _monthlyAttendanceCard() {
    final series = _monthlyAttendanceSeries;
    final labels = series?.labels ?? const ['', '', '', '', '', ''];
    final values = series?.values ?? const <double>[];
    final maxRaw = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    final maxY = maxRaw > 0 ? maxRaw * 1.2 : 10.0;
    final interval = maxY / 4;

    return _cardWrap(
      title: 'Monthly Attendance',
      subtitle: 'Foot traffic (member check-ins + walk-ins) over the last 6 months',
      trailing: _aiBadge(label: 'Live'),
      child: _loadingMonthlyAttendance
          ? const LoadingState()
          : values.isEmpty
              ? const EmptyState(
                  icon: Icons.bar_chart,
                  message: 'No attendance recorded yet this month.')
              : _attendanceBarChart(
                  labels: labels, values: values, maxY: maxY, interval: interval),
    );
  }

  // ---------- Owner: Expiring Memberships ----------
  Widget _expiringMembershipsCard() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _panelTitle('Expiring Memberships'),
                  const SizedBox(height: 4),
                  Text('Members renewing within the next 7 days',
                      style: AppTheme.cardSubtitle(context)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _loadingExpiring ? '—' : '${_expiringMembers.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.cyanDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingExpiring)
            const LoadingState()
          else if (_expiringMembers.isEmpty)
            const EmptyState(
              icon: Icons.card_membership_outlined,
              message: 'No memberships expiring in the next 7 days.')
          else
            for (final m in _expiringMembers) _expiringMemberRow(m),
        ],
      ),
    );
  }

  Widget _expiringMemberRow(ExpiringMember m) {
    final isExpired = m.isExpired;
    final badgeBg = isExpired ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3E2);
    final badgeText = isExpired ? const Color(0xFFDC2626) : const Color(0xFFCA8A04);
    final badgeLabel = isExpired
        ? 'Expired'
        : m.daysUntilExpiry <= 0
            ? 'Renews today'
            : '${m.daysUntilExpiry}d left';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.subtleFill(context),
            child: Icon(Icons.person_outline, size: 16, color: AppTheme.textMuted(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  '${m.plan ?? 'No plan'} · ${m.renewalCount} previous renewal${m.renewalCount == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
            child: Text(badgeLabel,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: badgeText)),
          ),
        ],
      ),
    );
  }

  // ---------- Owner: Churn Risk Watchlist ----------
  Widget _churnRiskCard() {
    return _Panel(
      accent: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _panelTitle('Churn Risk Watchlist'),
                  const SizedBox(height: 4),
                  Text('Active members flagged for possible churn',
                      style: AppTheme.cardSubtitle(context)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.subtleFill(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Rule-based · prototype',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted(context))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingChurnRisk)
            const LoadingState()
          else if (_churnRisk.isEmpty)
            const EmptyState(
              icon: Icons.shield_outlined,
              message: 'No members currently flagged as churn risks.')
          else
            for (final m in _churnRisk.take(8)) _churnRiskRow(m),
        ],
      ),
    );
  }

  Widget _churnRiskRow(ChurnRiskMember m) {
    final isHigh = m.riskLevel == 'High';
    final badgeBg = isHigh ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3E2);
    final badgeText = isHigh ? const Color(0xFFDC2626) : const Color(0xFFCA8A04);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.subtleFill(context),
            child: Icon(Icons.person_outline, size: 16, color: AppTheme.textMuted(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(m.reason, style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
            child: Text(m.riskLevel,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: badgeText)),
          ),
        ],
      ),
    );
  }

  // ---------- Owner: AI Churn Forecast (prototype) ----------
  Widget _aiChurnForecastCard() {
    return _Panel(
      accent: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _panelTitle('AI Churn Forecast'),
              _aiBadge(label: 'AI Predicted · Prototype'),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingChurnForecast)
            const LoadingState()
          else if (_churnForecast == null)
            Text('Forecast unavailable right now.',
                style: TextStyle(color: AppTheme.textMuted(context)))
          else ...[
            Row(
              children: [
                Text('${_churnForecast!.riskRatePercent}%',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.warning)),
                const SizedBox(width: 8),
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('of active members at risk',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_churnForecast!.forecast,
                style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.heading(context))),
            const SizedBox(height: 12),
            Row(
              children: [
                _forecastChip('${_churnForecast!.highRiskCount} High', const Color(0xFFDC2626)),
                const SizedBox(width: 8),
                _forecastChip('${_churnForecast!.mediumRiskCount} Medium', const Color(0xFFCA8A04)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _forecastChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ---------- Staff: Weekly Attendance (real data, same source as owner chart) ----------
  Widget _weeklyAttendanceCard() {
    final series = _attendanceSeries;
    final labels = series?.labels ?? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final values = series?.values ?? const <double>[];
    final maxRaw = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    final maxY = maxRaw > 0 ? maxRaw * 1.2 : 10.0;
    final interval = maxY / 4;

    return _cardWrap(
      title: 'Weekly Attendance',
      child: _loadingAttendance
          ? const LoadingState()
          : values.isEmpty
              ? const EmptyState(
                  icon: Icons.bar_chart,
                  message: 'No attendance recorded yet this week.')
              : _attendanceBarChart(
                  labels: labels, values: values, maxY: maxY, interval: interval),
    );
  }

  // ---------- Staff-only attendance lists (now real data) ----------

  List<Map<String, String>> _walkInEntryMaps() {
    return _todaysWalkIns
        .map((e) => {
              'name': e.name,
              'time': e.time,
              'amount': '₱${e.amount.toStringAsFixed(0)}',
            })
        .toList();
  }

  List<Map<String, String>> _memberEntryMaps() {
    return _todaysMemberAttendance
        .map((e) => {
              'name': e.name,
              'time': e.time,
              'plan': e.plan ?? 'No active plan',
            })
        .toList();
  }

  Widget _attendanceListCard({
    required String title,
    required List<Map<String, String>> entries,
    bool loading = false,
  }) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _panelTitle(title),
          const SizedBox(height: 16),
          if (loading)
            const LoadingState(padding: EdgeInsets.symmetric(vertical: 20))
          else if (entries.isEmpty)
            const EmptyState(
              icon: Icons.event_busy_outlined,
              padding: EdgeInsets.symmetric(vertical: 12),
              message: 'No entries yet today.')
          else
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.subtleFill(context),
                      child: Icon(Icons.person, size: 16, color: AppTheme.textMuted(context)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(e['plan'] ?? e['amount'] ?? '',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted(context))),
                        ],
                      ),
                    ),
                    Text(e['time'] ?? '',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context))),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _notificationsCard() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle('Recent Notifications'),
          const SizedBox(height: 14),
          if (_loadingNotifications)
            const LoadingState(padding: EdgeInsets.symmetric(vertical: 16))
          else if (_notifications.isEmpty)
            const EmptyState(
              icon: Icons.notifications_none,
              padding: EdgeInsets.symmetric(vertical: 16),
              message: 'No recent activity yet.')
          else
            for (final n in _notifications) _notificationRow(n),
        ],
      ),
    );
  }

  Widget _notificationRow(AppNotification n) {
    IconData icon;
    Color iconColor;

    switch (n.type) {
      case 'registration':
        icon = Icons.person_add_alt;
        iconColor = AppColors.blueIcon;
        break;
      case 'payment_paid':
        icon = Icons.check_circle_outline;
        iconColor = AppColors.greenIcon;
        break;
      case 'payment_failed':
        icon = Icons.error_outline;
        iconColor = AppColors.danger;
        break;
      case 'payment_pending':
        icon = Icons.hourglass_empty;
        iconColor = AppColors.gold;
        break;
      default:
        icon = Icons.notifications_none;
        iconColor = AppTheme.textMuted(context);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(n.subtitle, style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(n.timeAgo, style: TextStyle(color: AppTheme.textMuted(context), fontSize: 11)),
        ],
      ),
    );
  }
}

// =====================================================================
// Presentation-only widgets used by the dashboard (no logic).
// =====================================================================

/// White rounded card with a hairline border and soft shadow. An optional
/// [accent] draws a thin colored bar on the left edge, reserved for cards
/// that need attention (e.g. churn risk).
class _Panel extends StatelessWidget {
  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry? padding;

  const _Panel({required this.child, this.accent, this.padding});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: dark
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: padding ?? const EdgeInsets.all(AppSpacing.card),
            child: child,
          ),
          if (accent != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: accent),
            ),
        ],
      ),
    );
  }
}

/// KPI card: small gray label on top, big bold number, small status text
/// underneath. Replaces the tinted/colored StatCard on this screen.
class _KpiCard extends StatelessWidget {
  final IconData? icon;
  final String? iconText;
  final String change;
  final String value;
  final String label;
  final Color? accent;

  const _KpiCard({
    this.icon,
    this.iconText,
    required this.change,
    required this.value,
    required this.label,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.textMuted(context);
    final tint = accent ?? AppColors.cyan;
    final positive = change.startsWith('+');
    final changeColor = positive ? AppColors.greenIcon : (accent ?? muted);

    return _Panel(
      accent: accent,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: iconText != null
                    ? Text(
                        iconText!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: tint,
                        ),
                      )
                    : Icon(icon, size: 17, color: tint),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTheme.heading(context),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            change,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: changeColor,
            ),
          ),
        ],
      ),
    );
  }
}
