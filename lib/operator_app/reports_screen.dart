import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../resources/widget/app_toast.dart';
import '../app_model/parking_ticket_model.dart';
import '../services/app_data_cache.dart';
import '../services/report_download.dart';

enum ReportDateFilter { today, yesterday, thisWeek, thisMonth, custom }

class ReportsScreen extends StatefulWidget {
  final String? locationIdOverride;
  final String? locationNameOverride;

  const ReportsScreen({
    super.key,
    this.locationIdOverride,
    this.locationNameOverride,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AppDataCache _cache = AppDataCache.instance;

  ReportDateFilter _dateFilter = ReportDateFilter.today;
  DateTime _customStartDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _customEndDate = DateTime.now();

  String _selectedCategory = 'All';
  String _selectedStatus = 'All';
  String _searchQuery = '';

  List<ParkingTicketModel> _allTickets = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
      }
    });

    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    if (!_cache.isLoaded) {
      await _cache.preloadForCurrentUser();
    }

    final locId = widget.locationIdOverride ?? _cache.locationId;
    final tickets = await _cache.getTickets(specificLocationId: locId);

    if (mounted) {
      setState(() {
        _allTickets = tickets;
        _isLoading = false;
      });
    }
  }

  // -------------------------------------------------------------
  // Filter Logic
  // -------------------------------------------------------------

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    switch (_dateFilter) {
      case ReportDateFilter.today:
        return DateTimeRange(start: todayStart, end: todayEnd);

      case ReportDateFilter.yesterday:
        final yestStart = todayStart.subtract(const Duration(days: 1));
        final yestEnd = todayStart.subtract(const Duration(milliseconds: 1));
        return DateTimeRange(start: yestStart, end: yestEnd);

      case ReportDateFilter.thisWeek:
        // Week starting Monday
        final daysFromMonday = (now.weekday - 1);
        final weekStart = todayStart.subtract(Duration(days: daysFromMonday));
        return DateTimeRange(start: weekStart, end: todayEnd);

      case ReportDateFilter.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: monthStart, end: todayEnd);

      case ReportDateFilter.custom:
        final start = DateTime(
          _customStartDate.year,
          _customStartDate.month,
          _customStartDate.day,
        );
        final end = DateTime(
          _customEndDate.year,
          _customEndDate.month,
          _customEndDate.day,
          23,
          59,
          59,
          999,
        );
        return DateTimeRange(start: start, end: end);
    }
  }

  List<ParkingTicketModel> get _filteredTickets {
    final range = _getDateRange();

    return _allTickets.where((ticket) {
      // A gate owns entries it created and exits it processed. This keeps
      // cross-gate revenue on the exit gate's report while preserving active
      // cars on their entry gate's report.
      final operatorId =
          _cache.userRole == 'operator' && widget.locationIdOverride == null
          ? _cache.operatorId
          : null;
      final isInside = ticket.status.toLowerCase() == 'in';
      final attributedOperator = isInside
          ? ticket.entryOperatorId
          : (ticket.exitOperatorId.isNotEmpty
                ? ticket.exitOperatorId
                : ticket.operatorId); // legacy completed tickets
      if (operatorId != null && attributedOperator != operatorId) return false;

      // 1. Date Filter
      final ticketTime =
          (isInside ? ticket.startTime : ticket.endTime)?.toDate() ??
          ticket.startTime?.toDate();
      if (ticketTime == null) return false;
      if (ticketTime.isBefore(range.start) || ticketTime.isAfter(range.end)) {
        return false;
      }

      // 2. Category Filter
      if (_selectedCategory != 'All') {
        final cat = ticket.vehicleCategory.toLowerCase();
        if (_selectedCategory == 'Valet' && cat != 'valet') return false;
        if (_selectedCategory == 'Self' && cat != 'self') return false;
        if (_selectedCategory == 'Bike' && cat != 'bike') return false;
      }

      // 3. Status Filter
      if (_selectedStatus != 'All') {
        final st = ticket.status.toLowerCase();
        if (_selectedStatus == 'Active' && st != 'in') return false;
        if (_selectedStatus == 'Exited' && st == 'in') return false;
      }

      // 4. Search Query
      if (_searchQuery.isNotEmpty) {
        final plate = ticket.vehicleNumber.toLowerCase();
        final tNum = ticket.ticketNumber.toLowerCase();
        final driver = ticket.driverName.toLowerCase();
        final phone = ticket.phoneNumber.toLowerCase();

        final matches =
            plate.contains(_searchQuery) ||
            tNum.contains(_searchQuery) ||
            driver.contains(_searchQuery) ||
            phone.contains(_searchQuery);
        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  // -------------------------------------------------------------
  // Summary Aggregates
  // -------------------------------------------------------------

  int get _totalVehicles => _filteredTickets.length;

  int get _activeCount =>
      _filteredTickets.where((t) => t.status.toLowerCase() == 'in').length;

  int get _exitedCount =>
      _filteredTickets.where((t) => t.status.toLowerCase() != 'in').length;

  double get _totalRevenue {
    double total = 0;
    for (final t in _filteredTickets) {
      if (t.status.toLowerCase() != 'in') {
        // t.charges already resolves checkoutAmount → finalParkingCharges → charges.
        // Do NOT fall back to t.parkingCharges (the base rate) — that would
        // inflate revenue for vehicles that exited within grace (Rs. 0).
        total += t.charges;
      }
    }
    return total;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locationName =
        widget.locationNameOverride ??
        _cache.locationName ??
        'Current Facility';

    final filtered = _filteredTickets;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // Header Bar
          _buildHeader(theme, locationName),

          // Main Scrollable Area
          Expanded(
            child: _isLoading && _allTickets.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // KPI Summary Cards
                          _buildSummaryCards(theme),

                          const SizedBox(height: 20),

                          // Filter Controls Card
                          _buildFilterCard(theme),

                          const SizedBox(height: 20),

                          // Table Header & Export
                          _buildTableActionsRow(theme, filtered.length),

                          const SizedBox(height: 12),

                          // Data Table
                          _buildDataTable(theme, filtered),

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final title = Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.assessment_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Parking Reports & Audit',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        locationName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Live Synced',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (!compact) const Spacer(),
              if (compact) const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showExportDialog(context),
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('Export / Print'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          );
          if (!compact) return title;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Parking Reports & Audit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                  Text(
                    locationName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const Text('• Live Synced'),
                  ElevatedButton.icon(
                    onPressed: () => _showExportDialog(context),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Export'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // Summary KPI Cards
  // -------------------------------------------------------------

  Widget _buildSummaryCards(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final int cols = w >= 1100 ? 5 : (w >= 700 ? 3 : (w < 420 ? 1 : 2));
        const spacing = 16.0;
        final cardWidth = (w - (spacing * (cols - 1))) / cols;

        final cards = [
          _StatCardItem(
            title: 'TOTAL VEHICLES',
            value: '$_totalVehicles',
            icon: Icons.directions_car_rounded,
            color: const Color(0xFF1E88E5),
            subtitle: 'Entries in period',
          ),
          _StatCardItem(
            title: 'TOTAL REVENUE',
            value: 'Rs. ${NumberFormat('#,##0').format(_totalRevenue)}',
            icon: Icons.payments_rounded,
            color: const Color(0xFF2E7D32),
            subtitle: 'Completed fee collection',
          ),
          _StatCardItem(
            title: 'COMPLETED EXITS',
            value: '$_exitedCount',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF43A047),
            subtitle: 'Checked out vehicles',
          ),
          _StatCardItem(
            title: 'CURRENTLY INSIDE',
            value: '$_activeCount',
            icon: Icons.local_parking_rounded,
            color: const Color(0xFFFB8C00),
            subtitle: 'Active parked cars',
          ),
          _StatCardItem(
            title: 'AVG DURATION',
            value: _avgDuration,
            icon: Icons.timer_outlined,
            color: const Color(0xFF8E24AA),
            subtitle: 'Per parked vehicle',
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((c) => SizedBox(width: cardWidth, child: c))
              .toList(),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // Filter Toolbar Card
  // -------------------------------------------------------------

  Widget _buildFilterCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Period:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              _buildDateFilterChip(
                'Today',
                ReportDateFilter.today,
                colorScheme,
              ),
              _buildDateFilterChip(
                'Yesterday',
                ReportDateFilter.yesterday,
                colorScheme,
              ),
              _buildDateFilterChip(
                'This Week',
                ReportDateFilter.thisWeek,
                colorScheme,
              ),
              _buildDateFilterChip(
                'This Month',
                ReportDateFilter.thisMonth,
                colorScheme,
              ),
              _buildDateFilterChip(
                'Custom Range',
                ReportDateFilter.custom,
                colorScheme,
              ),
            ],
          ),

          if (_dateFilter == ReportDateFilter.custom) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(
                  Icons.date_range_rounded,
                  size: 18,
                  color: Colors.grey,
                ),
                Text(
                  'Range: ${DateFormat('MMM dd, yyyy').format(_customStartDate)} - ${DateFormat('MMM dd, yyyy').format(_customEndDate)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickCustomDateRange,
                  icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                  label: const Text('Change Dates'),
                ),
              ],
            ),
          ],

          const Divider(height: 24),

          // Search + Dropdown Filters
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 850;
              final narrow = constraints.maxWidth < 380;
              final selectorWidth = narrow
                  ? constraints.maxWidth
                  : compact
                  ? (constraints.maxWidth - 12) / 2
                  : 180.0;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Search Input
                  SizedBox(
                    width: compact
                        ? constraints.maxWidth
                        : constraints.maxWidth * .42,
                    height: 42,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search plate #, ticket #, driver, phone...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.25),
                      ),
                    ),
                  ),

                  // Category Selector
                  SizedBox(
                    width: selectorWidth,
                    height: 42,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'All',
                          child: Text(
                            'All Categories',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Valet',
                          child: Text(
                            'Valet Parking',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Self',
                          child: Text('Self Parking'),
                        ),
                        DropdownMenuItem(value: 'Bike', child: Text('Bike')),
                      ],
                      onChanged: (val) {
                        if (val != null)
                          setState(() => _selectedCategory = val);
                      },
                    ),
                  ),

                  // Status Selector
                  SizedBox(
                    width: selectorWidth,
                    height: 42,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'All',
                          child: Text('All Status'),
                        ),
                        DropdownMenuItem(
                          value: 'Exited',
                          child: Text(
                            'Completed (Out)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Active',
                          child: Text(
                            'Active (Inside)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatus = val);
                      },
                    ),
                  ),

                  if (_searchQuery.isNotEmpty ||
                      _selectedCategory != 'All' ||
                      _selectedStatus != 'All')
                    IconButton(
                      tooltip: 'Reset Filters',
                      icon: const Icon(
                        Icons.filter_alt_off_rounded,
                        color: Colors.redAccent,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _selectedCategory = 'All';
                          _selectedStatus = 'All';
                          _searchQuery = '';
                        });
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChip(
    String label,
    ReportDateFilter filter,
    ColorScheme colors,
  ) {
    final selected = _dateFilter == filter;

    return InkWell(
      onTap: () async {
        setState(() => _dateFilter = filter);
        if (filter == ReportDateFilter.custom) {
          await _pickCustomDateRange();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary
              : colors.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? colors.primary
                : colors.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? colors.onPrimary
                : colors.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: _customStartDate,
        end: _customEndDate,
      ),
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
    }
  }

  // -------------------------------------------------------------
  // Table Row & Actions
  // -------------------------------------------------------------

  Widget _buildTableActionsRow(ThemeData theme, int count) {
    final colorScheme = theme.colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Records Found:',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count vehicles',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
        ),
        Text(
          'Showing detailed audit log',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Data Table
  // -------------------------------------------------------------

  Widget _buildDataTable(ThemeData theme, List<ParkingTicketModel> tickets) {
    final colorScheme = theme.colorScheme;

    if (tickets.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No parking tickets match your filter criteria',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting the date range or removing category/status filters.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1050),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              ),
              dataRowMinHeight: 52,
              dataRowMaxHeight: 58,
              horizontalMargin: 20,
              columnSpacing: 24,
              columns: const [
                DataColumn(
                  label: Text(
                    'TICKET #',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'VEHICLE #',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'CATEGORY',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'DRIVER & PHONE',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'ENTRY TIME',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'EXIT TIME',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'DURATION',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'CHARGES',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'STATUS',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'ACTION',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
              rows: tickets.map((ticket) {
                final start = ticket.startTime?.toDate();
                final end = ticket.endTime?.toDate();
                final isInside = ticket.status.toLowerCase() == 'in';

                String durationStr = '--';
                if (start != null) {
                  final compareEnd = end ?? DateTime.now();
                  final diff = compareEnd.difference(start);
                  if (!diff.isNegative) {
                    final h = diff.inHours;
                    final m = diff.inMinutes % 60;
                    durationStr = h > 0 ? '${h}h ${m}m' : '${m}m';
                  }
                }

                final chargeAmount = ticket.charges;

                return DataRow(
                  cells: [
                    // Ticket #
                    DataCell(
                      InkWell(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: ticket.ticketNumber),
                          );
                          AppToast.information(context, 'Ticket number copied', ticket.ticketNumber);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ticket.ticketNumber.isNotEmpty
                                  ? ticket.ticketNumber
                                  : ticket.id.substring(0, 8),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy_rounded,
                              size: 12,
                              color: colorScheme.primary.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Vehicle #
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          ticket.vehicleNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                    // Category
                    DataCell(
                      _buildCategoryBadge(ticket.vehicleCategory, colorScheme),
                    ),

                    // Driver & Phone
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            ticket.driverName.isNotEmpty
                                ? ticket.driverName
                                : 'Walk-in Driver',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (ticket.phoneNumber.isNotEmpty)
                            Text(
                              ticket.phoneNumber,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Entry Time
                    DataCell(
                      Text(
                        start != null
                            ? DateFormat('MMM dd, hh:mm a').format(start)
                            : '--',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),

                    // Exit Time
                    DataCell(
                      Text(
                        isInside
                            ? 'Still Inside'
                            : (end != null
                                  ? DateFormat('MMM dd, hh:mm a').format(end)
                                  : '--'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isInside
                              ? Colors.orange.shade800
                              : colorScheme.onSurface,
                          fontWeight: isInside
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),

                    // Duration
                    DataCell(
                      Text(
                        durationStr,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Charges
                    DataCell(
                      Text(
                        isInside
                            ? 'Pending'
                            : 'Rs. ${chargeAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isInside
                              ? Colors.grey
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                    ),

                    // Status
                    DataCell(_buildStatusBadge(isInside)),

                    // Action
                    DataCell(
                      IconButton(
                        tooltip: 'View Ticket Receipt',
                        icon: const Icon(Icons.receipt_long_rounded, size: 20),
                        color: colorScheme.primary,
                        onPressed: () => _showReceiptModal(context, ticket),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String cat, ColorScheme colors) {
    final lower = cat.toLowerCase();
    IconData icon;
    String label;
    Color bg;
    Color fg;

    if (lower == 'valet') {
      icon = Icons.room_service_rounded;
      label = 'Valet';
      bg = const Color(0xFFEDE7F6);
      fg = const Color(0xFF512DA8);
    } else if (lower == 'bike') {
      icon = Icons.two_wheeler_rounded;
      label = 'Bike';
      bg = const Color(0xFFE0F7FA);
      fg = const Color(0xFF00838F);
    } else {
      icon = Icons.directions_car_rounded;
      label = 'Self Parking';
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isInside) {
    if (isInside) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'PARKED',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Colors.amber.shade900,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'EXITED',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Colors.green.shade800,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Modals & Export Dialog
  // -------------------------------------------------------------

  void _showReceiptModal(BuildContext context, ParkingTicketModel ticket) {
    final start = ticket.startTime?.toDate();
    final end = ticket.endTime?.toDate();
    final charge = ticket.charges > 0 ? ticket.charges : ticket.parkingCharges;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.receipt_rounded, color: Color(0xFF1B5E20)),
              const SizedBox(width: 10),
              const Text(
                'Parking Ticket Audit',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      ticket.ticketNumber,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _receiptRow(
                  'Vehicle Plate',
                  ticket.vehicleNumber,
                  isBold: true,
                ),
                _receiptRow('Category', ticket.vehicleCategory.toUpperCase()),
                _receiptRow('Location', ticket.locationName),
                _receiptRow(
                  'Driver Name',
                  ticket.driverName.isNotEmpty ? ticket.driverName : 'N/A',
                ),
                _receiptRow(
                  'Phone',
                  ticket.phoneNumber.isNotEmpty ? ticket.phoneNumber : 'N/A',
                ),
                _receiptRow(
                  'Check In',
                  start != null
                      ? DateFormat('yyyy-MM-dd hh:mm:ss a').format(start)
                      : '--',
                ),
                _receiptRow(
                  'Check Out',
                  end != null
                      ? DateFormat('yyyy-MM-dd hh:mm:ss a').format(end)
                      : 'Still Parked',
                ),
                _receiptRow(
                  'Grace Period',
                  '${ticket.graceTimeSeconds ~/ 60} minutes',
                ),
                _receiptRow(
                  'Status',
                  ticket.status.toUpperCase(),
                  isBold: true,
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Charges:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rs. ${charge.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showExportDialog(BuildContext context) {
    final filtered = _filteredTickets;
    final range = _getDateRange();
    final dateRangeStr =
        '${DateFormat('MMM dd, yyyy').format(range.start)} - ${DateFormat('MMM dd, yyyy').format(range.end)}';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.print, color: Color(0xFF1B5E20)),
              SizedBox(width: 10),
              Text(
                'Audit Report Summary',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'REPORT OVERVIEW',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Period: $dateRangeStr',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Total Registered Vehicles: ${filtered.length}'),
                        Text('Completed Exits: $_exitedCount'),
                        Text('Currently Active: $_activeCount'),
                        Text(
                          'Total Revenue Collected: Rs. ${NumberFormat('#,##0').format(_totalRevenue)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Summary text copied to clipboard can be printed or pasted directly into Excel / Google Sheets.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final buffer = StringBuffer();
                buffer.writeln(
                  'Ticket,Vehicle,Category,Entry,Exit,Charges,Status,Entry Gate,Exit Gate',
                );
                for (final t in filtered) {
                  final s = t.startTime?.toDate() != null
                      ? DateFormat(
                          'yyyy-MM-dd HH:mm',
                        ).format(t.startTime!.toDate())
                      : '--';
                  final e = t.endTime?.toDate() != null
                      ? DateFormat(
                          'yyyy-MM-dd HH:mm',
                        ).format(t.endTime!.toDate())
                      : 'INSIDE';
                  final c = t.charges > 0 ? t.charges : t.parkingCharges;
                  final values = [
                    t.ticketNumber,
                    t.vehicleNumber,
                    t.vehicleCategory,
                    s,
                    e,
                    t.status.toLowerCase() == 'in' ? '' : c.toStringAsFixed(2),
                    t.status,
                    t.entryOperatorId,
                    t.exitOperatorId,
                  ];
                  buffer.writeln(values.map(_csvCell).join(','));
                }
                try {
                  final filename =
                      'parking_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
                  final savedTo = await downloadReport(
                    filename,
                    buffer.toString(),
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  AppToast.success(context, 'Report downloaded', savedTo);
                } catch (e) {
                  if (!ctx.mounted) return;
                  AppToast.error(context, 'Could not download report', '$e');
                }
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  Widget _receiptRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Small KPI Widget
// -------------------------------------------------------------

class _StatCardItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _StatCardItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
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
              fontSize: 22,
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
