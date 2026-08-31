import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/tab_visibility.dart';
import '../services/current_user.dart';
import '../services/payment_data.dart';
import '../services/attendance_data.dart';
import '../widgets/ai_insight_card.dart';
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
            Text('Dashboard', style: AppTheme.pageTitle(context)),
            const SizedBox(height: 6),
            Text("Welcome back! Here's what's happening with your gym today.",
                style: AppTheme.pageSubtitle(context)),
            const SizedBox(height: AppSpacing.section),
            GridView.count(
              crossAxisCount: statCols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: statCols == 1 ? 2.8 : 1.5,
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

  // ---------- Stat cards ----------

  List<Widget> _ownerStatCards() {
    final totalRevenue = _dashboardStats?.totalRevenue ?? 0;
    final stats = _dashboardStats;
    final churnCount = _churnRisk.length;
    final churnChange = _churnForecast != null
        ? '${_churnForecast!.riskRatePercent}% at risk'
        : (_loadingChurnRisk ? '—' : 'Watch');

    return [
      StatCard(
        icon: Icons.card_membership_outlined,
        iconBg: AppColors.blueBg,
        iconColor: AppColors.blueIcon,
        change: '+12%',
        value: stats != null ? '${stats.activeSubscriptions}' : '—',
        label: 'Active Subscriptions',
      ),
      StatCard(
        icon: Icons.person_outline,
        iconBg: AppColors.tealBg,
        iconColor: AppColors.tealIcon,
        change: '+8%',
        value: stats != null ? '${stats.activeMembers}' : '—',
        label: 'Active Members',
      ),
      StatCard(
        iconText: '₱',
        iconBg: AppColors.goldBg,
        iconColor: AppColors.gold,
        change: '+15%',
        value: _formatCurrency(totalRevenue),
        label: 'Total Revenue (This Year)',
      ),
      StatCard(
        icon: Icons.warning_amber_rounded,
        iconBg: const Color(0xFFFEE2E2),
        iconColor: const Color(0xFFDC2626),
        change: churnChange,
        value: _loadingChurnRisk ? '—' : '$churnCount',
        label: 'Churn Risk (Active Members)',
      ),
    ];
  }

  List<Widget> _staffStatCards() {
    final stats = _dashboardStats;
    return [
      StatCard(
        icon: Icons.people_alt_outlined,
        iconBg: AppColors.blueBg,
        iconColor: AppColors.blueIcon,
        change: '+12%',
        value: stats != null ? '${stats.activeSubscriptions}' : '—',
        label: 'Members on Plan',
      ),
      StatCard(
        icon: Icons.person_outline,
        iconBg: AppColors.tealBg,
        iconColor: AppColors.tealIcon,
        change: '+8%',
        value: stats != null ? '${stats.activeMembers}' : '—',
        label: 'Active Members',
      ),
      StatCard(
        icon: Icons.trending_up,
        iconBg: AppColors.greenBg,
        iconColor: AppColors.greenIcon,
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: AppTheme.cardDecoration(context, accent: accent),
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
                  Text(title, style: AppTheme.sectionTitle(context)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
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

  Widget _aiBadge({String label = 'AI Predicted'}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.goldBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 12, color: AppColors.gold),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.gold)),
        ],
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
      accent: AppColors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _periodSelector(),
          const SizedBox(height: 16),
          Expanded(
            child: _loadingRevenue
                ? const Center(child: CircularProgressIndicator())
                : values.isEmpty
                    ? const Center(
                        child: Text('No revenue recorded for this period yet.',
                            style: TextStyle(color: AppColors.textMuted)))
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
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
                              color: AppColors.gold,
                              barWidth: 3,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) =>
                                    FlDotCirclePainter(
                                        radius: 3.5,
                                        color: Theme.of(context).cardColor,
                                        strokeWidth: 2.5,
                                        strokeColor: AppColors.gold),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.gold.withValues(alpha: 0.18),
                                    AppColors.gold.withValues(alpha: 0.0),
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

  Widget _periodSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2E35) : const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: RevenuePeriod.values.map((p) {
          final selected = p == _revenuePeriod;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(7),
              onTap: () {
                setState(() => _revenuePeriod = p);
                _loadRevenueAnalytics();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? (isDark ? const Color(0xFF3A3F47) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: selected
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 5, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Text(
                  _periodLabel(p),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.cyanDark : AppColors.textMuted,
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
      accent: AppColors.cyan,
      child: _loadingAttendance
          ? const Center(child: CircularProgressIndicator())
          : values.isEmpty
              ? const Center(
                  child: Text('No attendance recorded yet this week.',
                      style: TextStyle(color: AppColors.textMuted)))
              : BarChart(
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
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: List.generate(values.length, (i) {
                      return BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: values[i],
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [AppColors.cyanDark, AppColors.cyan],
                          ),
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ]);
                    }),
                  ),
                ),
    );
  }

  // ---------- Owner: Expiring Memberships ----------
  Widget _expiringMembershipsCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: AppTheme.cardDecoration(context, accent: AppColors.cyan),
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
                  Text('Expiring Memberships', style: AppTheme.sectionTitle(context)),
                  const SizedBox(height: 3),
                  Text('Members renewing within the next 7 days',
                      style: AppTheme.cardSubtitle(context)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF7FC),
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_expiringMembers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No memberships expiring in the next 7 days.',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            )
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
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFF1F5F9),
            child: Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  '${m.plan ?? 'No plan'} · ${m.renewalCount} previous renewal${m.renewalCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: AppTheme.cardDecoration(context, accent: AppColors.warning),
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
                  Text('Churn Risk Watchlist', style: AppTheme.sectionTitle(context)),
                  const SizedBox(height: 3),
                  Text('Active members flagged for possible churn',
                      style: AppTheme.cardSubtitle(context)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Rule-based · prototype',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingChurnRisk)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_churnRisk.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No members currently flagged as churn risks.',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            )
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
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFF1F5F9),
            child: Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(m.reason, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: AppTheme.cardDecoration(context, accent: AppColors.warning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('AI Churn Forecast', style: AppTheme.sectionTitle(context)),
              _aiBadge(label: 'AI Predicted · Prototype'),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingChurnForecast)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_churnForecast == null)
            const Text('Forecast unavailable right now.',
                style: TextStyle(color: AppColors.textMuted))
          else ...[
            Row(
              children: [
                Text('${_churnForecast!.riskRatePercent}%',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.gold)),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('of active members at risk',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
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
      accent: AppColors.cyan,
      child: _loadingAttendance
          ? const Center(child: CircularProgressIndicator())
          : values.isEmpty
              ? const Center(
                  child: Text('No attendance recorded yet this week.',
                      style: TextStyle(color: AppColors.textMuted)))
              : BarChart(
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
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
                              child: Text(labels[i], style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: List.generate(values.length, (i) {
                      return BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: values[i],
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [AppColors.cyanDark, AppColors.cyan],
                          ),
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ]);
                    }),
                  ),
                ),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: AppTheme.cardDecoration(context, accent: AppColors.cyan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppTheme.sectionTitle(context)),
          const SizedBox(height: 16),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No entries yet today.',
                  style: TextStyle(color: AppColors.textMuted)),
            )
          else
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFE0F7FA),
                      child: Icon(Icons.person, size: 16, color: AppColors.cyanDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(e['plan'] ?? e['amount'] ?? '',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Text(e['time'] ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _notificationsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Notifications', style: AppTheme.sectionTitle(context)),
          const SizedBox(height: 14),
          if (_loadingNotifications)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_notifications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No recent activity yet.', style: TextStyle(color: AppColors.textMuted)),
            )
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
        iconColor = AppColors.textMuted;
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
                Text(n.subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(n.timeAgo, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}
