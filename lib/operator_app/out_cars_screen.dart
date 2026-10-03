import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_model/parking_ticket_model.dart';
import '../services/app_data_cache.dart';

/// Shows the history of checked-out (exited) vehicles for the current
/// operator's location. Only vehicles with status != 'in' are displayed.
class OutCarsScreen extends StatefulWidget {
  const OutCarsScreen({super.key});

  @override
  State<OutCarsScreen> createState() => _OutCarsScreenState();
}

class _OutCarsScreenState extends State<OutCarsScreen> {
  final AppDataCache _cache = AppDataCache.instance;
  final TextEditingController _searchController = TextEditingController();

  List<ParkingTicketModel> _allTickets = [];
  bool _isLoading = false;

  String _searchQuery = '';
  String _selectedCategory = 'All';
  _DateFilter _dateFilter = _DateFilter.today;

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

    final locId = _cache.locationId;
    final data = await _cache.getTickets(specificLocationId: locId);

    if (mounted) {
      setState(() {
        _allTickets = data;
        _isLoading = false;
      });
    }
  }

  // -----------------------------------------------------------------
  // Filtering
  // -----------------------------------------------------------------

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd =
        todayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    switch (_dateFilter) {
      case _DateFilter.today:
        return DateTimeRange(start: todayStart, end: todayEnd);
      case _DateFilter.yesterday:
        final yStart = todayStart.subtract(const Duration(days: 1));
        final yEnd = todayStart.subtract(const Duration(milliseconds: 1));
        return DateTimeRange(start: yStart, end: yEnd);
      case _DateFilter.thisWeek:
        final daysFromMonday = now.weekday - 1;
        final weekStart = todayStart.subtract(Duration(days: daysFromMonday));
        return DateTimeRange(start: weekStart, end: todayEnd);
      case _DateFilter.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: monthStart, end: todayEnd);
      case _DateFilter.allTime:
        return DateTimeRange(
          start: DateTime(2020),
          end: todayEnd,
        );
    }
  }

  List<ParkingTicketModel> get _filteredTickets {
    final range = _getDateRange();

    return _allTickets.where((ticket) {
      // Only show exited vehicles
      if (ticket.status.toLowerCase() == 'in') return false;

      // Date filter by exit time
      final exitTime = ticket.endTime?.toDate();
      if (exitTime == null) return false;
      if (exitTime.isBefore(range.start) || exitTime.isAfter(range.end)) {
        return false;
      }

      // Category filter
      if (_selectedCategory != 'All') {
        final cat = ticket.vehicleCategory.toLowerCase();
        if (_selectedCategory.toLowerCase() != cat) return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final plate = ticket.vehicleNumber.toLowerCase();
        final tNum = ticket.ticketNumber.toLowerCase();
        final driver = ticket.driverName.toLowerCase();
        final phone = ticket.phoneNumber.toLowerCase();

        final matches = plate.contains(_searchQuery) ||
            tNum.contains(_searchQuery) ||
            driver.contains(_searchQuery) ||
            phone.contains(_searchQuery);
        if (!matches) return false;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        final aTime = a.endTime?.toDate() ?? DateTime(2000);
        final bTime = b.endTime?.toDate() ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
  }

  // -----------------------------------------------------------------
  // Aggregations
  // -----------------------------------------------------------------

  double get _totalRevenue {
    double total = 0;
    for (final t in _filteredTickets) {
      total += t.charges;
    }
    return total;
  }

  String get _avgDuration {
    int totalMinutes = 0;
    int count = 0;

    for (final t in _filteredTickets) {
      final start = t.startTime?.toDate();
      final end = t.endTime?.toDate();
      if (start == null || end == null) continue;
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

  // -----------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locationName = _cache.locationName ?? 'Current Facility';
    final filtered = _filteredTickets;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          _buildHeader(theme, locationName),
          Expanded(
            child: _isLoading && _allTickets.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCards(theme, filtered),
                          const SizedBox(height: 20),
                          _buildFilterBar(theme),
                          const SizedBox(height: 16),
                          _buildRecordsHeader(theme, filtered.length),
                          const SizedBox(height: 12),
                          _buildTicketList(theme, filtered),
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

  // -----------------------------------------------------------------
  // Header
  // -----------------------------------------------------------------

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
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.exit_to_app_rounded, color: Colors.red.shade700, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Out Cars History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      locationName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  // Summary Cards
  // -----------------------------------------------------------------

  Widget _buildSummaryCards(ThemeData theme, List<ParkingTicketModel> filtered) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final int cols = w >= 900 ? 4 : (w >= 600 ? 2 : 1);
        const spacing = 16.0;
        final cardWidth = (w - (spacing * (cols - 1))) / cols;

        final cards = [
          _SummaryCard(
            title: 'TOTAL EXITS',
            value: '${filtered.length}',
            icon: Icons.logout_rounded,
            color: const Color(0xFFC62828),
          ),
          _SummaryCard(
            title: 'REVENUE COLLECTED',
            value: 'Rs. ${NumberFormat('#,##0').format(_totalRevenue)}',
            icon: Icons.payments_rounded,
            color: const Color(0xFF2E7D32),
          ),
          _SummaryCard(
            title: 'AVG DURATION',
            value: _avgDuration,
            icon: Icons.timer_outlined,
            color: const Color(0xFF1565C0),
          ),
          _SummaryCard(
            title: 'FREE EXITS',
            value: '${filtered.where((t) => t.charges == 0).length}',
            icon: Icons.money_off_rounded,
            color: const Color(0xFFFB8C00),
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

  // -----------------------------------------------------------------
  // Filter Bar
  // -----------------------------------------------------------------

  Widget _buildFilterBar(ThemeData theme) {
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
              _filterChip('Today', _DateFilter.today, colorScheme),
              _filterChip('Yesterday', _DateFilter.yesterday, colorScheme),
              _filterChip('This Week', _DateFilter.thisWeek, colorScheme),
              _filterChip('This Month', _DateFilter.thisMonth, colorScheme),
              _filterChip('All Time', _DateFilter.allTime, colorScheme),
            ],
          ),

          const Divider(height: 24),

          // Search + Category Filter
          LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: compact ? constraints.maxWidth : constraints.maxWidth * 0.45,
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
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                SizedBox(
                  width: compact ? constraints.maxWidth : 180,
                  height: 42,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Categories')),
                      DropdownMenuItem(value: 'Valet', child: Text('Valet')),
                      DropdownMenuItem(value: 'Self', child: Text('Self Parking')),
                      DropdownMenuItem(value: 'Bike', child: Text('Bike')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _DateFilter filter, ColorScheme colors) {
    final selected = _dateFilter == filter;

    return InkWell(
      onTap: () => setState(() => _dateFilter = filter),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? colors.primary : colors.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // Records Header
  // -----------------------------------------------------------------

  Widget _buildRecordsHeader(ThemeData theme, int count) {
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Text(
          'Exit Records',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count vehicles',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.red.shade700,
            ),
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------
  // Ticket List
  // -----------------------------------------------------------------

  Widget _buildTicketList(ThemeData theme, List<ParkingTicketModel> tickets) {
    final colorScheme = theme.colorScheme;

    if (tickets.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(Icons.directions_car_filled_rounded,
                size: 56, color: colorScheme.onSurface.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            Text(
              'No exited vehicles found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting the date range or search filters.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tickets.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final ticket = tickets[index];
        return _OutCarCard(ticket: ticket);
      },
    );
  }
}

// =================================================================
// Out Car Card
// =================================================================

class _OutCarCard extends StatelessWidget {
  final ParkingTicketModel ticket;

  const _OutCarCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final start = ticket.startTime?.toDate();
    final end = ticket.endTime?.toDate();

    String durationStr = '--';
    if (start != null && end != null) {
      final diff = end.difference(start);
      if (!diff.isNegative) {
        final d = diff.inDays;
        final h = diff.inHours % 24;
        final m = diff.inMinutes % 60;
        if (d > 0) {
          durationStr = '${d}d ${h}h';
        } else if (h > 0) {
          durationStr = '${h}h ${m}m';
        } else {
          durationStr = '${m}m';
        }
      }
    }

    final charge = ticket.charges;
    final isFree = charge == 0;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.13)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDetailSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Vehicle icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    _categoryIcon(ticket.vehicleCategory),
                    size: 22,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(width: 12),

                // Vehicle info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              ticket.vehicleNumber,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .4,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          _categoryBadge(context, ticket.vehicleCategory),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            ticket.ticketNumber,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: colorScheme.onSurface.withValues(alpha: 0.52),
                            ),
                          ),
                          if (ticket.locationName.isNotEmpty) ...[
                            Text(
                              '  •  ${ticket.locationName}',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurface.withValues(alpha: 0.52),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.logout_rounded, size: 12, color: Colors.red.shade400),
                          const SizedBox(width: 4),
                          Text(
                            end != null ? DateFormat('MMM dd, hh:mm a').format(end) : '--',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.timer_outlined, size: 12, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            durationStr,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if (ticket.exitOperatorName.isNotEmpty || ticket.entryOperatorName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (ticket.exitOperatorName.isNotEmpty) ...[
                              Icon(Icons.badge_outlined, size: 11, color: colorScheme.onSurface.withValues(alpha: 0.45)),
                              const SizedBox(width: 3),
                              Text(
                                'Out by: ${ticket.exitOperatorName}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                            if (ticket.exitOperatorName.isNotEmpty && ticket.entryOperatorName.isNotEmpty)
                              Text(
                                ' • ',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            if (ticket.entryOperatorName.isNotEmpty) ...[
                              Text(
                                'In: ${ticket.entryOperatorName}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Charge amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isFree ? 'FREE' : 'Rs. ${charge.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isFree ? Colors.orange.shade800 : const Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'EXITED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .3,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: colorScheme.onSurface.withValues(alpha: 0.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final start = ticket.startTime?.toDate();
    final end = ticket.endTime?.toDate();

    String durationStr = '--';
    if (start != null && end != null) {
      final diff = end.difference(start);
      if (!diff.isNegative) {
        final d = diff.inDays;
        final h = diff.inHours % 24;
        final m = diff.inMinutes % 60;
        if (d > 0) {
          durationStr = '${d}d ${h}h ${m}m';
        } else if (h > 0) {
          durationStr = '${h}h ${m}m';
        } else {
          durationStr = '${m}m';
        }
      }
    }

    final charge = ticket.charges;
    final isFree = charge == 0;
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: colorScheme.outline.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _categoryIcon(ticket.vehicleCategory),
                          color: Colors.red.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.vehicleNumber,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .5,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${ticket.vehicleCategory}  •  ${ticket.locationName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Charge card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isFree
                          ? Colors.orange.shade50
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFree
                            ? Colors.orange.shade200
                            : const Color(0xFFA5D6A7),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isFree ? 'FREE EXIT' : 'AMOUNT COLLECTED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .8,
                            color: isFree ? Colors.orange.shade800 : const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isFree ? 'Rs. 0' : 'Rs. ${charge.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: isFree ? Colors.orange.shade800 : const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Details
                  Text(
                    'Parking Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _detailRow(context, Icons.receipt_long_outlined, 'Ticket #', ticket.ticketNumber),
                  _detailRow(context, Icons.login_rounded, 'Entry Time',
                      start != null ? fmt.format(start) : '--'),
                  _detailRow(context, Icons.logout_rounded, 'Exit Time',
                      end != null ? fmt.format(end) : '--'),
                  _detailRow(context, Icons.timer_outlined, 'Duration', durationStr),
                  _detailRow(context, Icons.category_outlined, 'Category', ticket.vehicleCategory),
                  _detailRow(context, Icons.location_on_outlined, 'Location', ticket.locationName),
                  _detailRow(context, Icons.person_outline_rounded, 'Driver',
                      ticket.driverName.isEmpty ? '--' : ticket.driverName),
                  _detailRow(context, Icons.phone_outlined, 'Phone',
                      ticket.phoneNumber.isEmpty ? '--' : ticket.phoneNumber),
                  _detailRow(context, Icons.attach_money_rounded, 'Base Rate',
                      'Rs. ${ticket.parkingCharges.toStringAsFixed(0)}'),
                  _detailRow(context, Icons.free_breakfast_outlined, 'Grace Time',
                      _formatGraceTime(ticket.graceTimeSeconds)),
                  if (ticket.entryOperatorName.isNotEmpty)
                    _detailRow(context, Icons.person_pin_outlined, 'Entered By', ticket.entryOperatorName),
                  if (ticket.exitOperatorName.isNotEmpty)
                    _detailRow(context, Icons.badge_outlined, 'Exited By', ticket.exitOperatorName),
                  if (ticket.notes.isNotEmpty && ticket.notes != 'clear')
                    _detailRow(context, Icons.notes_rounded, 'Notes', ticket.notes),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(BuildContext context, IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 17, color: colorScheme.onSurface.withValues(alpha: 0.40)),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.50),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface.withValues(alpha: 0.80),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'bike':
        return Icons.two_wheeler_rounded;
      case 'valet':
        return Icons.room_service_rounded;
      case 'self':
      default:
        return Icons.directions_car_rounded;
    }
  }

  static Widget _categoryBadge(BuildContext context, String category) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .3,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  static String _formatGraceTime(int seconds) {
    if (seconds <= 0) return 'No grace';
    final d = Duration(seconds: seconds);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }
}

// =================================================================
// Summary Card
// =================================================================

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.13)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// Date Filter Enum
// =================================================================

enum _DateFilter { today, yesterday, thisWeek, thisMonth, allTime }
