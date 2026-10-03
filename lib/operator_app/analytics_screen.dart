import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_model/parking_ticket_model.dart';
import '../services/app_data_cache.dart';

enum AnalyticsTimeframe { today, last7Days, last30Days, thisMonth, allTime }

class AnalyticsScreen extends StatefulWidget {
  final String? locationIdOverride;
  final String? locationNameOverride;

  const AnalyticsScreen({
    super.key,
    this.locationIdOverride,
    this.locationNameOverride,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AppDataCache _cache = AppDataCache.instance;
  AnalyticsTimeframe _timeframe = AnalyticsTimeframe.last7Days;

  List<ParkingTicketModel> _tickets = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    if (!_cache.isLoaded) {
      await _cache.preloadForCurrentUser();
    }

    final locId = widget.locationIdOverride ?? _cache.locationId;
    final data = await _cache.getTickets(
      specificLocationId: locId,
    );

    if (mounted) {
      setState(() {
        _tickets = data;
        _isLoading = false;
      });
    }
  }

  // -------------------------------------------------------------
  // Filtered by Timeframe
  // -------------------------------------------------------------

  DateTimeRange? _getTimeframeRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    switch (_timeframe) {
      case AnalyticsTimeframe.today:
        return DateTimeRange(start: todayStart, end: todayEnd);

      case AnalyticsTimeframe.last7Days:
        final start = todayStart.subtract(const Duration(days: 6));
        return DateTimeRange(start: start, end: todayEnd);

      case AnalyticsTimeframe.last30Days:
        final start = todayStart.subtract(const Duration(days: 29));
        return DateTimeRange(start: start, end: todayEnd);

      case AnalyticsTimeframe.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: start, end: todayEnd);

      case AnalyticsTimeframe.allTime:
        return null;
    }
  }

  List<ParkingTicketModel> get _filteredTickets {
    final range = _getTimeframeRange();

    return _tickets.where((ticket) {
      final isInside = ticket.status.toLowerCase() == 'in';
      final operatorId = _cache.userRole == 'operator' &&
              widget.locationIdOverride == null
          ? _cache.operatorId
          : null;
      final attributedOperator = isInside
          ? ticket.entryOperatorId
          : (ticket.exitOperatorId.isNotEmpty
              ? ticket.exitOperatorId
              : ticket.operatorId);
      if (operatorId != null && attributedOperator != operatorId) return false;
      if (range == null) return true;
      final t = (isInside ? ticket.startTime : ticket.endTime)?.toDate() ??
          ticket.startTime?.toDate();
      if (t == null) return false;
      return !t.isBefore(range.start) && !t.isAfter(range.end);
    }).toList();
  }

  // -------------------------------------------------------------
  // Aggregations
  // -------------------------------------------------------------

  int get _totalVehicles => _filteredTickets.length;

  int get _activeCount =>
      _filteredTickets.where((t) => t.status.toLowerCase() == 'in').length;

  double get _totalRevenue {
    double total = 0;
    for (final t in _filteredTickets) {
      if (t.status.toLowerCase() != 'in') {
        // t.charges already resolves checkoutAmount → finalParkingCharges → charges.
        // Do NOT fall back to t.parkingCharges (the base rate).
        total += t.charges;
      }
    }
    return total;
  }

  double get _avgRevenuePerTicket {
    final exited = _filteredTickets.where((t) => t.status.toLowerCase() != 'in').length;
    if (exited == 0) return 0;
    return _totalRevenue / exited;
  }

  String get _avgDuration {
    int totalMinutes = 0;
    int count = 0;

    for (final t in _filteredTickets) {
      final start = t.startTime?.toDate();
      if (start == null) continue;
      final end = t.endTime?.toDate() ?? DateTime.now();
      final diff = end.difference(start).inMinutes;
      if (diff >= 0) {
        totalMinutes += diff;
        count++;
      }
    }

    if (count == 0) return '0m';
    final avg = totalMinutes ~/ count;
    final h = avg ~/ 60;
    final m = avg % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Map<int, int> get _hourlyInflow {
    final map = <int, int>{};
    for (int i = 0; i < 24; i++) {
      map[i] = 0;
    }

    for (final t in _filteredTickets) {
      final start = t.startTime?.toDate();
      if (start != null) {
        map[start.hour] = (map[start.hour] ?? 0) + 1;
      }
    }
    return map;
  }

  String get _peakHourString {
    final map = _hourlyInflow;
    int maxHour = 0;
    int maxCount = 0;

    map.forEach((hour, count) {
      if (count > maxCount) {
        maxCount = count;
        maxHour = hour;
      }
    });

    if (maxCount == 0) return 'None';

    final period = maxHour >= 12 ? 'PM' : 'AM';
    final h = maxHour % 12 == 0 ? 12 : maxHour % 12;
    return '${h.toString().padLeft(2, '0')}:00 $period ($maxCount cars)';
  }

  // Category counts & revenue
  Map<String, _CategoryStats> get _categoryStats {
    final stats = {
      'valet': _CategoryStats('Valet Parking', Icons.room_service_rounded, const Color(0xFF512DA8)),
      'self': _CategoryStats('Self Parking', Icons.directions_car_rounded, const Color(0xFF2E7D32)),
      'bike': _CategoryStats('Bike / Motorcycle', Icons.two_wheeler_rounded, const Color(0xFF00838F)),
    };

    for (final t in _filteredTickets) {
      final cat = t.vehicleCategory.toLowerCase();
      final key = stats.containsKey(cat) ? cat : 'self';
      final item = stats[key]!;
      item.count++;

      if (t.status.toLowerCase() != 'in') {
        item.revenue += t.charges;
      }
    }

    return stats;
  }

  // Duration distribution
  Map<String, int> get _durationDistribution {
    final dist = {
      '< 1h': 0,
      '1 - 3h': 0,
      '3 - 6h': 0,
      '6 - 12h': 0,
      '> 12h': 0,
    };

    for (final t in _filteredTickets) {
      final start = t.startTime?.toDate();
      if (start == null) continue;
      final end = t.endTime?.toDate() ?? DateTime.now();
      final hours = end.difference(start).inHours;

      if (hours < 1) {
        dist['< 1h'] = (dist['< 1h'] ?? 0) + 1;
      } else if (hours < 3) {
        dist['1 - 3h'] = (dist['1 - 3h'] ?? 0) + 1;
      } else if (hours < 6) {
        dist['3 - 6h'] = (dist['3 - 6h'] ?? 0) + 1;
      } else if (hours < 12) {
        dist['6 - 12h'] = (dist['6 - 12h'] ?? 0) + 1;
      } else {
        dist['> 12h'] = (dist['> 12h'] ?? 0) + 1;
      }
    }

    return dist;
  }

  // -------------------------------------------------------------
  // UI Build
  // -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locationName = widget.locationNameOverride ?? _cache.locationName ?? 'Current Facility';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // Header Bar
          _buildHeader(theme, locationName),

          // Main Analytics Body
          Expanded(
            child: _isLoading && _tickets.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top KPI Metrics
                          _buildKpiCards(theme),

                          const SizedBox(height: 24),

                          // Charts Row: Revenue & Daily Trend + Peak Inflow
                          _buildChartsRow(theme),

                          const SizedBox(height: 24),

                          // Breakdown Row: Category Share + Duration Breakdown
                          _buildBreakdownsRow(theme),

                          const SizedBox(height: 24),

                          // Active Long-Stay Watchlist
                          _buildLongStayWatchlist(theme),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Header
  // -------------------------------------------------------------

  Widget _buildHeader(ThemeData theme, String locationName) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.bar_chart_rounded, color: colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Performance & Parking Analytics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Location: $locationName • Real-Time Metrics & Traffic Insights',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Timeframe selector
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                _timeframeButton('Today', AnalyticsTimeframe.today, colorScheme),
                _timeframeButton('Last 7 Days', AnalyticsTimeframe.last7Days, colorScheme),
                _timeframeButton('Last 30 Days', AnalyticsTimeframe.last30Days, colorScheme),
                _timeframeButton('This Month', AnalyticsTimeframe.thisMonth, colorScheme),
                _timeframeButton('All Time', AnalyticsTimeframe.allTime, colorScheme),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Refresh Analytics',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
    );
  }

  Widget _timeframeButton(String label, AnalyticsTimeframe tf, ColorScheme colors) {
    final selected = _timeframe == tf;
    return InkWell(
      onTap: () => setState(() => _timeframe = tf),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // KPI Cards
  // -------------------------------------------------------------

  Widget _buildKpiCards(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final int cols = w >= 1150 ? 5 : (w >= 750 ? 3 : 2);
        const spacing = 16.0;
        final cardWidth = (w - (spacing * (cols - 1))) / cols;

        final cards = [
          _AnalyticsKpiCard(
            title: 'TOTAL REVENUE',
            value: 'Rs. ${NumberFormat('#,##0').format(_totalRevenue)}',
            subtitle: 'Avg Rs. ${_avgRevenuePerTicket.toStringAsFixed(0)} / car',
            icon: Icons.payments_rounded,
            color: const Color(0xFF2E7D32),
          ),
          _AnalyticsKpiCard(
            title: 'TOTAL VEHICLES',
            value: '$_totalVehicles',
            subtitle: '${_filteredTickets.length - _activeCount} Exited (${_totalVehicles > 0 ? ((_filteredTickets.length - _activeCount) * 100 ~/ _totalVehicles) : 0}%)',
            icon: Icons.directions_car_rounded,
            color: const Color(0xFF1E88E5),
          ),
          _AnalyticsKpiCard(
            title: 'CURRENTLY INSIDE',
            value: '$_activeCount',
            subtitle: 'Real-time parked cars',
            icon: Icons.local_parking_rounded,
            color: const Color(0xFFFB8C00),
          ),
          _AnalyticsKpiCard(
            title: 'PEAK TRAFFIC HOUR',
            value: _peakHourString,
            subtitle: 'Highest check-in influx',
            icon: Icons.access_time_filled_rounded,
            color: const Color(0xFFE91E63),
          ),
          _AnalyticsKpiCard(
            title: 'AVG DURATION',
            value: _avgDuration,
            subtitle: 'Mean duration of stay',
            icon: Icons.timelapse_rounded,
            color: const Color(0xFF8E24AA),
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // Charts Row: Daily Revenue/Volume + Hourly Traffic Peak
  // -------------------------------------------------------------

  Widget _buildChartsRow(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isDesktop = w >= 950;

        final dailyTrendCard = _buildDailyTrendCard(theme);
        final hourlyPeakCard = _buildHourlyPeakCard(theme);

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: dailyTrendCard),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: hourlyPeakCard),
            ],
          );
        } else {
          return Column(
            children: [
              dailyTrendCard,
              const SizedBox(height: 20),
              hourlyPeakCard,
            ],
          );
        }
      },
    );
  }

  // Daily Trend Custom Bar Chart
  Widget _buildDailyTrendCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    // Aggregate by day (last 7 or up to 14 days)
    final daysMap = <String, _DayStat>{};
    final now = DateTime.now();

    final daysCount = _timeframe == AnalyticsTimeframe.today ? 1 : (_timeframe == AnalyticsTimeframe.last7Days ? 7 : 14);

    for (int i = daysCount - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(d);
      final label = DateFormat('EEE, d').format(d);
      daysMap[key] = _DayStat(label: label, count: 0, revenue: 0);
    }

    for (final t in _filteredTickets) {
      final start = t.startTime?.toDate();
      if (start == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(start);
      if (daysMap.containsKey(key)) {
        daysMap[key]!.count++;
        if (t.status.toLowerCase() != 'in') {
          daysMap[key]!.revenue += (t.charges > 0 ? t.charges : t.parkingCharges);
        }
      }
    }

    final dayList = daysMap.values.toList();
    final maxCount = dayList.fold<int>(1, (prev, e) => max(prev, e.count));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, color: colorScheme.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'Vehicle Volume & Revenue Trend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              _legendDot(const Color(0xFF2E7D32), 'Volume'),
              const SizedBox(width: 14),
              _legendDot(const Color(0xFF1E88E5), 'Revenue (Rs)'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Daily check-ins and revenue collection across period',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 24),

          // Custom Bar Chart Render
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dayList.map((day) {
                final ratio = maxCount > 0 ? (day.count / maxCount) : 0.0;
                final barHeight = max(10.0, ratio * 130);

                return Expanded(
                  child: Tooltip(
                    message: '${day.label}\nVehicles: ${day.count}\nRevenue: Rs. ${NumberFormat('#,##0').format(day.revenue)}',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${day.count}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: max(16.0, 36.0 - (dayList.length * 1.5)),
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                colorScheme.primary,
                                colorScheme.primary.withValues(alpha: 0.75),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          day.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          'Rs.${day.revenue >= 1000 ? '${(day.revenue / 1000).toStringAsFixed(1)}k' : day.revenue.toStringAsFixed(0)}',
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Hourly Traffic Peak Distribution
  Widget _buildHourlyPeakCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final hourly = _hourlyInflow;
    final maxHourly = hourly.values.fold<int>(1, (prev, e) => max(prev, e));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: Colors.orange.shade800, size: 22),
              const SizedBox(width: 10),
              Text(
                'Hourly Inflow Intensity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Vehicle entry count by hour of day (rush hours)',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 20),

          // 24 Hour bar visual (clustered in 2-hour slots for readability)
          Column(
            children: [
              for (int hour = 8; hour <= 22; hour += 2) ...[
                _hourlyRow(
                  hour: hour,
                  count: (hourly[hour] ?? 0) + (hourly[hour + 1] ?? 0),
                  maxCount: max(1, maxHourly * 2),
                  theme: theme,
                ),
                if (hour < 22) const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _hourlyRow({
    required int hour,
    required int count,
    required int maxCount,
    required ThemeData theme,
  }) {
    final colorScheme = theme.colorScheme;
    final ratio = count / maxCount;
    final isPeak = ratio >= 0.7 && count > 0;

    final startLabel = hour > 12 ? '${hour - 12} PM' : (hour == 12 ? '12 PM' : '$hour AM');
    final endHour = hour + 2;
    final endLabel = endHour > 12 ? '${endHour - 12} PM' : (endHour == 12 ? '12 PM' : '$endHour AM');

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$startLabel - $endLabel',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isPeak ? Colors.orange.shade900 : colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 14,
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                ),
                FractionallySizedBox(
                  widthFactor: max(0.02, ratio.clamp(0.0, 1.0)),
                  child: Container(
                    height: 14,
                    color: isPeak ? Colors.orange.shade700 : colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 32,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isPeak ? FontWeight.w900 : FontWeight.w600,
              color: isPeak ? Colors.orange.shade900 : colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Breakdowns Row: Category Share + Duration Distribution
  // -------------------------------------------------------------

  Widget _buildBreakdownsRow(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isDesktop = w >= 950;

        final categoryCard = _buildCategoryBreakdownCard(theme);
        final durationCard = _buildDurationBreakdownCard(theme);

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: categoryCard),
              const SizedBox(width: 20),
              Expanded(child: durationCard),
            ],
          );
        } else {
          return Column(
            children: [
              categoryCard,
              const SizedBox(height: 20),
              durationCard,
            ],
          );
        }
      },
    );
  }

  Widget _buildCategoryBreakdownCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final catStats = _categoryStats;
    final total = _totalVehicles;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: const Color(0xFF512DA8), size: 22),
              const SizedBox(width: 10),
              Text(
                'Vehicle Category Distribution',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Volume and revenue breakdown by category',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 18),

          // Segmented Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: Row(
                children: catStats.values.map((cat) {
                  final pct = total > 0 ? (cat.count / total) : 0.0;
                  if (pct == 0) return const SizedBox.shrink();
                  return Expanded(
                    flex: max(1, (pct * 100).toInt()),
                    child: Container(color: cat.color),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Detail Tiles
          ...catStats.values.map((cat) {
            final pct = total > 0 ? (cat.count * 100 / total).toStringAsFixed(1) : '0';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(cat.icon, color: cat.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(
                        'Rs. ${NumberFormat('#,##0').format(cat.revenue)} collected',
                        style: TextStyle(fontSize: 11.5, color: colorScheme.onSurface.withValues(alpha: 0.55)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${cat.count} vehicles', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      Text('$pct%', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: cat.color)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDurationBreakdownCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final dist = _durationDistribution;
    final total = _totalVehicles;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_rounded, color: const Color(0xFF00838F), size: 22),
              const SizedBox(width: 10),
              Text(
                'Duration of Stay Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Vehicle turnaround time and parking duration patterns',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 20),

          ...dist.entries.map((entry) {
            final count = entry.value;
            final pct = total > 0 ? (count / total) : 0.0;
            final isOverstay = entry.key == '> 12h' && count > 0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isOverstay ? Colors.red.shade700 : colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '$count cars (${(pct * 100).toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(
                          height: 10,
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        ),
                        FractionallySizedBox(
                          widthFactor: max(0.01, pct.clamp(0.0, 1.0)),
                          child: Container(
                            height: 10,
                            color: isOverstay ? Colors.red : const Color(0xFF00838F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Longest-Stay Watchlist (Active Vehicles)
  // -------------------------------------------------------------

  Widget _buildLongStayWatchlist(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();

    final activeList = _tickets.where((t) => t.status.toLowerCase() == 'in').toList();
    activeList.sort((a, b) {
      final aStart = a.startTime?.toDate() ?? now;
      final bStart = b.startTime?.toDate() ?? now;
      return aStart.compareTo(bStart); // Oldest first
    });

    final topLongest = activeList.take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 22),
              const SizedBox(width: 10),
              Text(
                'Longest Parked Vehicles (Active Watchlist)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${activeList.length} active vehicles currently inside',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Vehicles currently inside that have accumulated the highest elapsed parking time',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 16),

          if (topLongest.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No vehicles currently parked inside.',
                  style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topLongest.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final ticket = topLongest[index];
                final start = ticket.startTime?.toDate();
                String elapsed = '--';
                bool isVeryLong = false;

                if (start != null) {
                  final diff = now.difference(start);
                  final d = diff.inDays;
                  final h = diff.inHours % 24;
                  final m = diff.inMinutes % 60;
                  if (d > 0) {
                    elapsed = '${d}d ${h}h ${m}m';
                    isVeryLong = true;
                  } else if (h > 6) {
                    elapsed = '${h}h ${m}m';
                    isVeryLong = true;
                  } else {
                    elapsed = '${h}h ${m}m';
                  }
                }

                return Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        ticket.vehicleNumber,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.6),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      ticket.ticketNumber,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      ticket.driverName.isNotEmpty ? ticket.driverName : 'Walk-in Driver',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isVeryLong ? Colors.red.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isVeryLong ? Colors.red.shade200 : Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 14, color: isVeryLong ? Colors.red.shade800 : Colors.orange.shade900),
                          const SizedBox(width: 4),
                          Text(
                            elapsed,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: isVeryLong ? Colors.red.shade900 : Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// -------------------------------------------------------------
// Helper Data Classes
// -------------------------------------------------------------

class _DayStat {
  final String label;
  int count;
  double revenue;

  _DayStat({required this.label, required this.count, required this.revenue});
}

class _CategoryStats {
  final String name;
  final IconData icon;
  final Color color;
  int count = 0;
  double revenue = 0.0;

  _CategoryStats(this.name, this.icon, this.color);
}

class _AnalyticsKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _AnalyticsKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
