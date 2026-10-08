import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../resources/widget/app_toast.dart';
import '../app_model/location_model.dart';
import '../app_model/parking_ticket_model.dart';
import '../services/app_data_cache.dart';
import '../services/location_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  final void Function(int index)? onNavigate;

  const AdminDashboardScreen({super.key, this.onNavigate});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final LocationService _locationService = LocationService();
  final AppDataCache _cache = AppDataCache.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedLocationId = 'ALL';
  List<LocationModel> _locations = [];
  StreamSubscription<List<LocationModel>>? _locationsSub;

  List<ParkingTicketModel> _todayTickets = [];
  bool _isLoadingTickets = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _subscribeLocations();
    _loadTodayTickets();

    // Auto-refresh stats every 30 seconds for real-time accuracy under heavy traffic
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadTodayTickets();
    });
  }

  @override
  void dispose() {
    _locationsSub?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _subscribeLocations() {
    _locationsSub = _locationService.getLocations().listen((list) {
      if (mounted) {
        setState(() => _locations = list);
      }
    });
  }

  Future<void> _loadTodayTickets() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    try {
      final tickets = await _cache.getTickets(
        specificLocationId: _selectedLocationId == 'ALL'
            ? null
            : _selectedLocationId,
        startDate: todayStart,
        endDate: todayEnd,
      );

      if (mounted) {
        setState(() {
          _todayTickets = tickets;
          _isLoadingTickets = false;
        });
      }
    } catch (e) {
      debugPrint('AdminDashboard ticket fetch error: $e');
      if (mounted) {
        setState(() => _isLoadingTickets = false);
      }
    }
  }

  // Aggregates for selected scope
  List<ParkingTicketModel> get _scopedTickets {
    if (_selectedLocationId == 'ALL') return _todayTickets;
    return _todayTickets
        .where((t) => t.locationId == _selectedLocationId)
        .toList();
  }

  int get _todayCheckIns => _scopedTickets.length;

  int get _todayCheckOuts =>
      _scopedTickets.where((t) => t.status.toLowerCase() != 'in').length;

  double get _todayRevenue {
    double total = 0;
    for (final t in _scopedTickets) {
      if (t.status.toLowerCase() != 'in') {
        total += t.charges;
      }
    }
    return total;
  }

  String get _peakHourString {
    final map = <int, int>{};
    for (int i = 0; i < 24; i++) map[i] = 0;

    for (final t in _scopedTickets) {
      final start = t.startTime?.toDate();
      if (start != null) {
        map[start.hour] = (map[start.hour] ?? 0) + 1;
      }
    }

    int maxHour = 0;
    int maxCount = 0;
    map.forEach((h, c) {
      if (c > maxCount) {
        maxCount = c;
        maxHour = h;
      }
    });

    if (maxCount == 0) return 'No Traffic Yet';
    final period = maxHour >= 12 ? 'PM' : 'AM';
    final h = maxHour % 12 == 0 ? 12 : maxHour % 12;
    return '${h.toString().padLeft(2, '0')}:00 $period ($maxCount vehicles)';
  }

  void _openGraceTimeDialog(BuildContext context, LocationModel location) {
    int currentHours = location.graceTimeSeconds ~/ 3600;
    int currentMinutes = (location.graceTimeSeconds % 3600) ~/ 60;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final int totalSeconds =
                (currentHours * 3600) + (currentMinutes * 60);

            String formattedTime;
            if (currentHours == 0 && currentMinutes == 0) {
              formattedTime = 'No grace period (charges begin immediately)';
            } else {
              final parts = <String>[];
              if (currentHours > 0)
                parts.add(
                  '$currentHours ${currentHours == 1 ? 'hour' : 'hours'}',
                );
              if (currentMinutes > 0)
                parts.add(
                  '$currentMinutes ${currentMinutes == 1 ? 'minute' : 'minutes'}',
                );
              formattedTime = '${parts.join(' ')} free parking';
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.timer_outlined,
                              color: colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Change Grace Time',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  location.locationName,
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Set customer free parking grace duration. This updates in real time for all operators currently signed in at this location.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Counter Container
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Row(
                          children: [
                            // Hours
                            Expanded(
                              child: Column(
                                children: [
                                  const Text(
                                    'Hours',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                        onPressed: currentHours > 0
                                            ? () => setDialogState(
                                                () => currentHours--,
                                              )
                                            : null,
                                      ),
                                      Text(
                                        '$currentHours',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        onPressed: currentHours < 24
                                            ? () => setDialogState(
                                                () => currentHours++,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 50,
                              color: theme.dividerColor,
                            ),
                            // Minutes
                            Expanded(
                              child: Column(
                                children: [
                                  const Text(
                                    'Minutes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                        onPressed: currentMinutes >= 5
                                            ? () => setDialogState(
                                                () => currentMinutes -= 5,
                                              )
                                            : null,
                                      ),
                                      Text(
                                        '$currentMinutes',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        onPressed: currentMinutes < 55
                                            ? () => setDialogState(
                                                () => currentMinutes += 5,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quick Presets
                      const Text(
                        'Quick Select:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _presetChoice(
                            'No grace',
                            0,
                            0,
                            currentHours,
                            currentMinutes,
                            (h, m) => setDialogState(() {
                              currentHours = h;
                              currentMinutes = m;
                            }),
                          ),
                          _presetChoice(
                            '10 min',
                            0,
                            10,
                            currentHours,
                            currentMinutes,
                            (h, m) => setDialogState(() {
                              currentHours = h;
                              currentMinutes = m;
                            }),
                          ),
                          _presetChoice(
                            '15 min',
                            0,
                            15,
                            currentHours,
                            currentMinutes,
                            (h, m) => setDialogState(() {
                              currentHours = h;
                              currentMinutes = m;
                            }),
                          ),
                          _presetChoice(
                            '30 min',
                            0,
                            30,
                            currentHours,
                            currentMinutes,
                            (h, m) => setDialogState(() {
                              currentHours = h;
                              currentMinutes = m;
                            }),
                          ),
                          _presetChoice(
                            '45 min',
                            0,
                            45,
                            currentHours,
                            currentMinutes,
                            (h, m) => setDialogState(() {
                              currentHours = h;
                              currentMinutes = m;
                            }),
                          ),
                          _presetChoice(
                            '1 hour',
                            1,
                            0,
                            currentHours,
                            currentMinutes,
                            (h, m) => setDialogState(() {
                              currentHours = h;
                              currentMinutes = m;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Preview
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: colorScheme.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                formattedTime,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.sync, size: 18),
                            label: const Text('Save & Update Operators'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () async {
                              Navigator.of(dialogCtx).pop();
                              try {
                                await _locationService.updateGraceTime(
                                  locationId: location.id,
                                  graceTimeSeconds: totalSeconds,
                                );
                                if (mounted) {
                                  AppToast.success(context, 'Grace time updated', '${location.locationName} now allows ${location.formattedGraceTime}. Operators synced instantly.');
                                }
                              } catch (e) {
                                if (mounted) {
                                  AppToast.error(context, 'Could not update grace time', '$e');
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _presetChoice(
    String label,
    int h,
    int m,
    int curH,
    int curM,
    void Function(int, int) onSelect,
  ) {
    final isSelected = curH == h && curM == m;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelect(h, m),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(now);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 950;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 16,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Control Banner: Facility Filter + Date
                _buildTopFilterHeader(context, dateStr, isDesktop),
                const SizedBox(height: 20),

                // Primary Real-time KPI Cards
                _buildKpiMetricsGrid(context, isDesktop),
                const SizedBox(height: 24),

                // Location Fleet & Live Grace Time Manager
                _buildLocationFleetSection(context, isDesktop),
                const SizedBox(height: 24),

                // Hourly Inflow Chart + Category Breakdown
                _buildTrafficVisualizer(context, isDesktop),
                const SizedBox(height: 24),

                // Live Recent Transactions Stream
                _buildRecentTransactionsCard(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopFilterHeader(
    BuildContext context,
    String dateStr,
    bool isDesktop,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!isDesktop) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Live Dashboard',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(dateStr, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedLocationId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'ALL',
                  child: Text('All Facilities'),
                ),
                ..._locations.map(
                  (loc) => DropdownMenuItem(
                    value: loc.id,
                    child: Text(
                      loc.locationName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedLocationId = value;
                  _isLoadingTickets = true;
                });
                _loadTodayTickets();
              },
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.dashboard_rounded,
              color: colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Live Dashboard',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fiber_manual_record,
                            size: 10,
                            color: Color(0xFF2E7D32),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'LIVE SYNC ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Location Dropdown Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLocationId,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                onChanged: (newVal) {
                  if (newVal != null) {
                    setState(() {
                      _selectedLocationId = newVal;
                      _isLoadingTickets = true;
                    });
                    _loadTodayTickets();
                  }
                },
                items: [
                  const DropdownMenuItem(
                    value: 'ALL',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.domain_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'All Facilities (System-Wide)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  ..._locations.map(
                    (loc) => DropdownMenuItem(
                      value: loc.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(loc.locationName),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Manual refresh
          IconButton(
            tooltip: 'Refresh Metrics',
            onPressed: () {
              setState(() => _isLoadingTickets = true);
              _loadTodayTickets();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMetricsGrid(BuildContext context, bool isDesktop) {
    return StreamBuilder<List<ParkingTicketModel>>(
      stream: _cache.systemWideActiveTicketsStream(
        locationId: _selectedLocationId == 'ALL' ? null : _selectedLocationId,
      ),
      builder: (context, snapshot) {
        final activeVehicles = snapshot.data ?? [];
        final activeCount = activeVehicles.length;
        final cards = [
          // 1. Live Parked Vehicles
          _kpiCard(
            context,
            title: 'Active Vehicles Inside',
            value: '$activeCount',
            subtitle: 'Currently Parked',
            icon: Icons.directions_car_filled_rounded,
            color: const Color(0xFF1976D2),
            badge: 'LIVE',
            badgeColor: const Color(0xFF2E7D32),
          ),

          // 2. Today's Total Check-Ins
          _kpiCard(
            context,
            title: "Today's Total Entries",
            value: '$_todayCheckIns',
            subtitle: 'Check-In Volume',
            icon: Icons.login_rounded,
            color: const Color(0xFF00796B),
          ),

          // 3. Today's Total Check-Outs
          _kpiCard(
            context,
            title: "Today's Total Exits",
            value: '$_todayCheckOuts',
            subtitle: 'Turnover Completed',
            icon: Icons.logout_rounded,
            color: const Color(0xFFE65100),
          ),

          // 4. Today's Revenue
          _kpiCard(
            context,
            title: "Today's Revenue",
            value: 'Rs. ${_todayRevenue.toStringAsFixed(0)}',
            subtitle: 'Excludes Free Grace Exits',
            icon: Icons.payments_rounded,
            color: const Color(0xFF512DA8),
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1050
                ? 4
                : width >= 560
                ? 2
                : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: columns == 1
                    ? 164
                    : columns == 2
                    ? 176
                    : 160,
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) => cards[index],
            );
          },
        );
      },
    );
  }

  Widget _kpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? badge,
    Color? badgeColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: badgeColor ?? color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        badge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeColor ?? color,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Location Fleet Card with Instant Grace Time Changer
  Widget _buildLocationFleetSection(BuildContext context, bool isDesktop) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 650
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: colorScheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Facilities & Grace Periods Quick Control',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Change grace times across facilities. All operators receive instant real-time synchronization.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => widget.onNavigate?.call(2),
                          icon: const Icon(
                            Icons.manage_accounts_rounded,
                            size: 16,
                          ),
                          label: const Text('Manage All Locations'),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Facilities & Grace Periods Quick Control',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Change grace times across facilities. All operators receive instant real-time synchronization.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => widget.onNavigate?.call(
                          2,
                        ), // Navigate to Locations tab
                        icon: const Icon(
                          Icons.manage_accounts_rounded,
                          size: 16,
                        ),
                        label: const Text('Manage All Locations'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Divider(color: theme.dividerColor, height: 1),
          const SizedBox(height: 16),

          if (_locations.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _locations.length,
              separatorBuilder: (_, __) =>
                  Divider(color: theme.dividerColor.withValues(alpha: 0.5)),
              itemBuilder: (context, index) {
                final loc = _locations[index];
                return _buildFleetLocationRow(context, loc);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFleetLocationRow(BuildContext context, LocationModel location) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Code Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              location.numericId > 0
                  ? '#LOC-${location.numericId.toString().padLeft(2, '0')}'
                  : '#LOC',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name & Address
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.locationName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
                Text(
                  location.address,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Rate
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  size: 16,
                  color: Color(0xFF1976D2),
                ),
                const SizedBox(width: 6),
                Text(
                  'Rs. ${location.parkingCharges}/hr',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Current Grace Time Badge
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: location.graceTimeSeconds > 0
                    ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 15,
                    color: location.graceTimeSeconds > 0
                        ? const Color(0xFF2E7D32)
                        : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    location.graceTimeSeconds > 0
                        ? location.formattedGraceTime
                        : 'No Grace',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: location.graceTimeSeconds > 0
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick Change Grace Time Button
          ElevatedButton.icon(
            onPressed: () => _openGraceTimeDialog(context, location),
            icon: const Icon(Icons.edit_calendar_rounded, size: 15),
            label: const Text('Change Grace Time'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Traffic Inflow Visualizer & Category distribution
  Widget _buildTrafficVisualizer(BuildContext context, bool isDesktop) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hourly Inflow distribution
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s Hourly Traffic Inflow',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Entry volume distribution by hour (Peak congestion analysis)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Peak: $_peakHourString',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildHourlyBars(context),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Vehicle Category Share
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle Categories',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Traffic composition breakdown',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                _buildCategoryBreakdown(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyBars(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final counts = List.filled(24, 0);
    for (final t in _scopedTickets) {
      final start = t.startTime?.toDate();
      if (start != null) {
        counts[start.hour]++;
      }
    }

    int maxCount = counts.reduce((a, b) => a > b ? a : b);
    if (maxCount == 0) maxCount = 1;

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(24, (hour) {
          final count = counts[hour];
          final heightPercent = (count / maxCount).clamp(0.05, 1.0);
          final isRush = count > 0 && count == maxCount;

          return Expanded(
            child: Tooltip(
              message: '${hour.toString().padLeft(2, '0')}:00 - $count entries',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    count > 0 ? '$count' : '',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isRush ? FontWeight.bold : FontWeight.normal,
                      color: isRush
                          ? colorScheme.primary
                          : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 110 * heightPercent,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: isRush
                          ? colorScheme.primary
                          : colorScheme.primary.withValues(
                              alpha: count > 0 ? 0.45 : 0.1,
                            ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hour % 4 == 0 ? '${hour}h' : '',
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCategoryBreakdown(BuildContext context) {
    int valet = 0;
    int self = 0;
    int bike = 0;

    for (final t in _scopedTickets) {
      final cat = t.vehicleCategory.toLowerCase();
      if (cat == 'valet') {
        valet++;
      } else if (cat == 'bike') {
        bike++;
      } else {
        self++;
      }
    }

    final total = _scopedTickets.isEmpty ? 1 : _scopedTickets.length;

    return Column(
      children: [
        _categoryBar(
          'Valet Parking',
          valet,
          total,
          const Color(0xFF512DA8),
          Icons.room_service_rounded,
        ),
        const SizedBox(height: 14),
        _categoryBar(
          'Self Parking',
          self,
          total,
          const Color(0xFF2E7D32),
          Icons.directions_car_rounded,
        ),
        const SizedBox(height: 14),
        _categoryBar(
          'Bike / Motorcycle',
          bike,
          total,
          const Color(0xFF00838F),
          Icons.two_wheeler_rounded,
        ),
      ],
    );
  }

  Widget _categoryBar(
    String label,
    int count,
    int total,
    Color color,
    IconData icon,
  ) {
    final pct = (count / total * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const Spacer(),
            Text(
              '$count ($pct%)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: count / total,
          backgroundColor: color.withValues(alpha: 0.12),
          valueColor: AlwaysStoppedAnimation(color),
          borderRadius: BorderRadius.circular(4),
          minHeight: 6,
        ),
      ],
    );
  }

  // Live Recent Transactions Stream Across Facilities
  Widget _buildRecentTransactionsCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Query<Map<String, dynamic>> query = _firestore
        .collection('parking_tickets')
        .orderBy('createdAt', descending: true)
        .limit(10);

    if (_selectedLocationId != 'ALL') {
      query = query.where('locationId', isEqualTo: _selectedLocationId);
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live System Activity Stream',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Real-time check-ins and check-outs across facilities',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    widget.onNavigate?.call(5), // Navigate to Reports tab
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text('View Full Reports'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: theme.dividerColor, height: 1),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No recent activity recorded today'),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    Divider(color: theme.dividerColor.withValues(alpha: 0.5)),
                itemBuilder: (context, index) {
                  final ticket = ParkingTicketModel.fromFirestore(docs[index]);
                  final isInside = ticket.status.toLowerCase() == 'in';
                  final time =
                      (isInside ? ticket.startTime : ticket.endTime)
                          ?.toDate() ??
                      DateTime.now();
                  final timeFormatted = DateFormat('hh:mm a').format(time);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            (isInside
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFE65100))
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isInside ? Icons.login_rounded : Icons.logout_rounded,
                        color: isInside
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE65100),
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          ticket.vehicleNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            ticket.ticketNumber,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${ticket.locationName} • Operator: ${ticket.entryOperatorName.isNotEmpty ? ticket.entryOperatorName : ticket.operatorId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isInside
                              ? 'PARKED'
                              : 'Rs. ${ticket.charges.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isInside
                                ? const Color(0xFF2E7D32)
                                : colorScheme.primary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          timeFormatted,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
