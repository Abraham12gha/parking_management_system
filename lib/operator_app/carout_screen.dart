import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../resources/widget/app_toast.dart';
import '../services/app_data_cache.dart';

class CaroutScreen extends StatefulWidget {
  final VoidCallback onBack;

  const CaroutScreen({super.key, required this.onBack});

  @override
  State<CaroutScreen> createState() => _CaroutScreenState();
}

class _CaroutScreenState extends State<CaroutScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _savingNotes = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<_Vehicle>>? _activeVehiclesStream;
  String? _userLocationId;
  String? _locationError;

  Timer? _refreshTimer;

  String _searchQuery = '';
  String _selectedCategory = 'All';

  // We store the Firestore document ID instead of the entire object.
  // This guarantees that when Firestore updates, we use the newest data.
  String? _selectedVehicleId;

  @override
  void initState() {
    super.initState();

    _initializeLocationStream();

    // Refresh duration and calculated amount while the screen is open.
    //
    // 15 seconds is enough because your billing thresholds are measured
    // in minutes.
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _initializeLocationStream() async {
    try {
      String? locationId;
      if (AppDataCache.instance.isLoaded &&
          AppDataCache.instance.locationId != null) {
        locationId = AppDataCache.instance.locationId;
      } else {
        final user = _auth.currentUser;

        if (user == null) {
          throw Exception('No authenticated user found.');
        }

        final userSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userSnapshot.exists) {
          throw Exception('User profile not found.');
        }

        final userData = userSnapshot.data();
        locationId = userData?['location']?.toString().trim();
      }

      if (locationId == null || locationId.isEmpty) {
        throw Exception('No location is assigned to this operator.');
      }

      if (!mounted) return;

      setState(() {
        _userLocationId = locationId;
        _activeVehiclesStream = _firestore
            .collection('parking_tickets')
            .where('status', isEqualTo: 'in')
            .where('locationId', isEqualTo: locationId)
            .snapshots()
            .map(_mapVehicles);
        _locationError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _locationError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // FIRESTORE STREAM
  // ===========================================================================

  List<_Vehicle> _mapVehicles(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final vehicles = snapshot.docs
        .map((doc) => _Vehicle.fromFirestore(doc.id, doc.data()))
        .where((vehicle) => vehicle.startTime != null)
        .toList();

    // Newest tickets first.
    vehicles.sort((a, b) {
      final aTime = a.startTime ?? DateTime(2000);
      final bTime = b.startTime ?? DateTime(2000);

      return bTime.compareTo(aTime);
    });

    return vehicles;
  }

  // ===========================================================================
  // FIND SELECTED VEHICLE
  // ===========================================================================

  _Vehicle? _getSelectedVehicle(List<_Vehicle> vehicles) {
    if (_selectedVehicleId == null) {
      return null;
    }

    for (final vehicle in vehicles) {
      if (vehicle.id == _selectedVehicleId) {
        return vehicle;
      }
    }

    return null;
  }

  // ===========================================================================
  // FILTER
  // ===========================================================================

  List<_Vehicle> _filterVehicles(List<_Vehicle> vehicles) {
    final query = _searchQuery.trim().toLowerCase();

    return vehicles.where((vehicle) {
      final matchesSearch =
          query.isEmpty ||
          vehicle.vehicleNumber.toLowerCase().contains(query) ||
          vehicle.ticketNumber.toLowerCase().contains(query);

      final matchesCategory =
          _selectedCategory == 'All' ||
          vehicle.category.toLowerCase() == _selectedCategory.toLowerCase();

      return matchesSearch && matchesCategory;
    }).toList();
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: _locationError != null
          ? _buildLocationError(theme, _locationError!)
          : _activeVehiclesStream == null
          ? _buildLoading(theme)
          : StreamBuilder<List<_Vehicle>>(
              stream: _activeVehiclesStream!,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildFirestoreError(theme, snapshot.error.toString());
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return _buildLoading(theme);
                }

                final allVehicles = snapshot.data ?? [];

                final filteredVehicles = _filterVehicles(allVehicles);

                final selectedVehicle = _getSelectedVehicle(allVehicles);

                // If the selected ticket disappeared from Firestore,
                // clear the selection.
                if (_selectedVehicleId != null && selectedVehicle == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _selectedVehicleId = null;
                      });
                    }
                  });
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 900;

                    if (isCompact) {
                      return _buildCompactLayout(
                        theme,
                        allVehicles,
                        filteredVehicles,
                        selectedVehicle,
                      );
                    }

                    return _buildDesktopLayout(
                      theme,
                      allVehicles,
                      filteredVehicles,
                      selectedVehicle,
                    );
                  },
                );
              },
            ),
    );
  }

  // ===========================================================================
  // LOADING
  // ===========================================================================

  Widget _buildLoading(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        _buildHeader(theme, 0),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: colorScheme.primary),
                const SizedBox(height: 15),
                Text(
                  'Loading parked vehicles...',
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // LOCATION ERROR
  // ===========================================================================

  Widget _buildLocationError(ThemeData theme, String error) {
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        _buildHeader(theme, 0),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_off_rounded,
                    size: 50,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Unable to determine operator location',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _initializeLocationStream,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // FIRESTORE ERROR
  // ===========================================================================

  Widget _buildFirestoreError(ThemeData theme, String error) {
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        _buildHeader(theme, 0),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 50,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Unable to load parking tickets',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // DESKTOP
  // ===========================================================================

  Widget _buildDesktopLayout(
    ThemeData theme,
    List<_Vehicle> allVehicles,
    List<_Vehicle> filteredVehicles,
    _Vehicle? selectedVehicle,
  ) {
    return Column(
      children: [
        _buildHeader(theme, allVehicles.length),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: _buildVehicleSelectionPanel(
                    theme,
                    filteredVehicles,
                    compact: false,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 4,
                  child: selectedVehicle == null
                      ? _buildSelectVehicleState(theme)
                      : _buildCheckoutPanel(
                          theme,
                          selectedVehicle,
                          compact: false,
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // COMPACT
  // ===========================================================================

  Widget _buildCompactLayout(
    ThemeData theme,
    List<_Vehicle> allVehicles,
    List<_Vehicle> filteredVehicles,
    _Vehicle? selectedVehicle,
  ) {
    return Column(
      children: [
        _buildHeader(theme, allVehicles.length),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildVehicleSelectionPanel(
                  theme,
                  filteredVehicles,
                  compact: true,
                ),
                const SizedBox(height: 14),
                if (selectedVehicle == null)
                  SizedBox(height: 400, child: _buildSelectVehicleState(theme))
                else
                  _buildCheckoutPanel(theme, selectedVehicle, compact: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(ThemeData theme, int activeCount) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
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
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.logout_rounded,
              color: colorScheme.primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Car Out',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Find a parked vehicle and complete its checkout',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          _buildActiveCount(theme, activeCount),
        ],
      ),
    );
  }

  Widget _buildActiveCount(ThemeData theme, int count) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '$count',
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'vehicles inside',
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // VEHICLE SELECTION PANEL
  // ===========================================================================

  Widget _buildVehicleSelectionPanel(
    ThemeData theme,
    List<_Vehicle> vehicles, {
    required bool compact,
  }) {
    final colorScheme = theme.colorScheme;

    final panel = Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.13)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Select Vehicle',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${vehicles.length} found',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Search vehicle number or ticket...',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();

                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                            )
                          : null,
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _categoryChip(theme, 'All'),
                      _categoryChip(theme, 'Self'),
                      _categoryChip(theme, 'Bike'),
                      _categoryChip(theme, 'Valet'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: colorScheme.outline.withValues(alpha: 0.10),
          ),
          Expanded(
            child: vehicles.isEmpty
                ? _buildNoVehiclesFound(theme)
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: vehicles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];

                      return _VehicleCard(
                        vehicle: vehicle,
                        selected: _selectedVehicleId == vehicle.id,
                        onTap: () {
                          setState(() {
                            _selectedVehicleId = vehicle.id;
                            _notesController.text = vehicle.notes;
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (compact) {
      return SizedBox(height: 500, child: panel);
    }

    return panel;
  }

  // ===========================================================================
  // CATEGORY CHIP
  // ===========================================================================

  Widget _categoryChip(ThemeData theme, String category) {
    final colorScheme = theme.colorScheme;

    final selected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(category),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _selectedCategory = category;
          });
        },
        showCheckmark: false,
        side: BorderSide(
          color: selected
              ? colorScheme.primary
              : colorScheme.outline.withValues(alpha: 0.15),
        ),
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primary.withValues(alpha: 0.10),
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.60),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      ),
    );
  }

  // ===========================================================================
  // VEHICLE CARD
  // ===========================================================================

  Widget _VehicleCard({
    required _Vehicle vehicle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        final duration = vehicle.startTime == null
            ? '--'
            : _calculateDuration(vehicle.startTime!);

        final currentCharge = vehicle.startTime == null
            ? 0.0
            : _calculateParkingCharge(
                vehicle.startTime!,
                vehicle.parkingCharges,
                vehicle.graceTimeSeconds,
              );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.primary.withValues(alpha: 0.055)
                    : colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? colorScheme.primary.withValues(alpha: 0.45)
                      : colorScheme.outline.withValues(alpha: 0.13),
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _categoryIcon(vehicle.category),
                      size: 22,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                vehicle.vehicleNumber,
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
                            _smallCategoryBadge(context, vehicle.category),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${vehicle.ticketNumber}  •  ${vehicle.location}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.52,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            duration,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rs. ${currentCharge.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 7),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.chevron_right_rounded,
                    size: selected ? 20 : 19,
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.25),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _smallCategoryBadge(BuildContext context, String category) {
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

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'bike':
        return Icons.two_wheeler_rounded;

      case 'valet':
        return Icons.local_parking_rounded;

      case 'self':
      default:
        return Icons.directions_car_rounded;
    }
  }

  // ===========================================================================
  // EMPTY RIGHT PANEL
  // ===========================================================================

  Widget _buildSelectVehicleState(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.13)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.directions_car_filled_rounded,
                  size: 34,
                  color: colorScheme.primary.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Select a Vehicle',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a vehicle from the list to review\n'
                'its parking time and checkout amount.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: colorScheme.onSurface.withValues(alpha: 0.52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // CHECKOUT PANEL
  // ===========================================================================

  Widget _buildCheckoutPanel(
    ThemeData theme,
    _Vehicle vehicle, {
    required bool compact,
  }) {
    final colorScheme = theme.colorScheme;

    final startTime = vehicle.startTime;

    if (startTime == null) {
      return _buildInvalidTicket(
        theme,
        'This ticket does not have a valid startTime.',
      );
    }

    final duration = _calculateDuration(startTime);

    final price = _calculateParkingCharge(
      startTime,
      vehicle.parkingCharges,
      vehicle.graceTimeSeconds,
    );

    final panel = Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.13)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 15),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    _categoryIcon(vehicle.category),
                    color: colorScheme.primary,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.vehicleNumber,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${vehicle.category}  •  ${vehicle.location}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colorScheme.onSurface.withValues(alpha: 0.52),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Change vehicle',
                  onPressed: () {
                    setState(() {
                      _selectedVehicleId = null;
                    });
                  },
                  icon: const Icon(Icons.swap_horiz_rounded),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: colorScheme.outline.withValues(alpha: 0.10),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildParkingSummary(theme, vehicle, duration),
                  const SizedBox(height: 18),
                  Text(
                    'Parking Charges',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 9),
                  _buildChargeCard(theme, vehicle, price, duration),
                  const SizedBox(height: 18),
                  Text(
                    'Ticket Information',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 9),
                  _infoCard(theme, [
                    _infoRow(
                      theme,
                      Icons.receipt_long_outlined,
                      'Ticket',
                      vehicle.ticketNumber,
                    ),
                    _infoRow(
                      theme,
                      Icons.login_outlined,
                      'Started',
                      _formatDateTime(startTime),
                    ),
                    _infoRow(
                      theme,
                      Icons.location_on_outlined,
                      'Location',
                      vehicle.location,
                    ),
                    _infoRow(
                      theme,
                      Icons.person_outline_rounded,
                      'Driver',
                      vehicle.driverName.isEmpty ? '--' : vehicle.driverName,
                    ),
                    _infoRow(
                      theme,
                      Icons.phone_outlined,
                      'Phone',
                      vehicle.phoneNumber.isEmpty ? '--' : vehicle.phoneNumber,
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Text(
                    'Notes',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Add vehicle notes',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _savingNotes
                          ? null
                          : () => _saveVehicleNotes(vehicle),
                      icon: _savingNotes
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(_savingNotes ? 'Saving…' : 'Save Notes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.10),
                ),
              ),
            ),
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  _showConfirmDialog(context, vehicle, price);
                },
                icon: const Icon(Icons.logout_rounded, size: 19),
                label: Text(
                  'Complete Car Out • Rs. ${price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (compact) {
      return SizedBox(height: 650, child: panel);
    }

    return panel;
  }

  Future<void> _saveVehicleNotes(_Vehicle vehicle) async {
    setState(() => _savingNotes = true);
    try {
      await _firestore.collection('parking_tickets').doc(vehicle.id).update({
        'notes': _notesController.text.trim(),
      });
      if (mounted)
        AppToast.success(
          context,
          'Notes updated',
          'Changes saved for ${vehicle.vehicleNumber}.',
        );
    } catch (e) {
      if (mounted) AppToast.error(context, 'Could not save notes', '$e');
    } finally {
      if (mounted) setState(() => _savingNotes = false);
    }
  }

  // ===========================================================================
  // CHARGE CARD
  // ===========================================================================

  Widget _buildChargeCard(
    ThemeData theme,
    _Vehicle vehicle,
    double price,
    String duration,
  ) {
    final colorScheme = theme.colorScheme;

    final billingPeriods = _billingPeriods(
      vehicle.startTime!,
      vehicle.graceTimeSeconds,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          // ACTUAL LOCATION GRACE TIME
          _chargeRow(
            theme,
            'Location grace time',
            _formatGraceTime(vehicle.graceTimeSeconds),
          ),

          const SizedBox(height: 9),

          _chargeRow(theme, 'Parking duration', duration),

          const SizedBox(height: 9),

          // ACTUAL PARKING CHARGE
          _chargeRow(
            theme,
            'Parking charge',
            'Rs. ${vehicle.parkingCharges.toStringAsFixed(0)}',
          ),

          const SizedBox(height: 9),

          _chargeRow(theme, 'Extra grace after charge', '15 min'),

          const SizedBox(height: 9),

          _chargeRow(theme, 'Billing periods', billingPeriods.toString()),

          const SizedBox(height: 13),

          Divider(
            height: 1,
            color: colorScheme.outline.withValues(alpha: 0.13),
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                'Rs. ${price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PARKING SUMMARY
  // ===========================================================================

  Widget _buildParkingSummary(
    ThemeData theme,
    _Vehicle vehicle,
    String duration,
  ) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: colorScheme.primary, size: 24),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PARKED FOR',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                    color: colorScheme.primary.withValues(alpha: 0.70),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  duration,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'GRACE TIME',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .7,
                  color: colorScheme.onSurface.withValues(alpha: 0.40),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatGraceTime(vehicle.graceTimeSeconds),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CONFIRM CAR OUT
  // ===========================================================================

  void _showConfirmDialog(
    BuildContext context,
    _Vehicle vehicle,
    double displayedPrice,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Confirm Car Out',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will complete the checkout and archive the ticket.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.directions_car_rounded,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                vehicle.vehicleNumber,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              'Rs. ${displayedPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Grace: ${_formatGraceTime(vehicle.graceTimeSeconds)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              'Ticket: ${vehicle.ticketNumber}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          setDialogState(() {
                            isProcessing = true;
                          });

                          try {
                            await _completeCarOut(vehicle);

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isProcessing = false;
                              });
                            }
                          }
                        },
                  icon: isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(isProcessing ? 'Processing...' : 'Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // COMPLETE CAR OUT
  //
  // ATOMIC OPERATION:
  //
  // 1. Read parking_tickets/{ticketId}
  // 2. Calculate final charge from ticket's own settings
  // 3. Mark the original ticket complete in parking_tickets/{ticketId}
  //
  // If anything fails, Firestore rolls back the transaction.
  // ===========================================================================

  Future<void> _completeCarOut(_Vehicle vehicle) async {
    final originalRef = _firestore
        .collection('parking_tickets')
        .doc(vehicle.id);

    try {
      await _firestore.runTransaction((transaction) async {
        // --------------------------------------------------------------
        // READ ORIGINAL ACTIVE TICKET
        // --------------------------------------------------------------

        final originalSnapshot = await transaction.get(originalRef);

        if (!originalSnapshot.exists) {
          throw Exception('This parking ticket no longer exists.');
        }

        final originalData = originalSnapshot.data();

        if (originalData == null) {
          throw Exception('Parking ticket contains no data.');
        }

        final ticketLocationId = originalData['locationId']?.toString();
        if (_userLocationId == null || ticketLocationId != _userLocationId) {
          throw Exception(
            'A vehicle can only be checked out at a gate in its entry location.',
          );
        }

        // --------------------------------------------------------------
        // CHECK STATUS
        // --------------------------------------------------------------

        final currentStatus = originalData['status']?.toString().toLowerCase();

        if (currentStatus != 'in') {
          throw Exception('This vehicle has already been checked out.');
        }

        // --------------------------------------------------------------
        // START TIME
        // --------------------------------------------------------------

        final startTime = firestoreDate(originalData['startTime']);

        if (startTime == null) {
          throw Exception('Ticket startTime is missing.');
        }

        // --------------------------------------------------------------
        // GET PRICING FROM THE TICKET
        //
        // Do NOT use cached operator settings here.
        //
        // The ticket contains the pricing snapshot that was
        // assigned when the car entered.
        // --------------------------------------------------------------

        final parkingCharge = firestoreDouble(originalData['parkingCharges']);

        final graceTimeSeconds = firestoreInt(originalData['graceTimeSeconds']);

        // --------------------------------------------------------------
        // CHECKOUT TIME
        // --------------------------------------------------------------

        final checkoutTime = DateTime.now();

        // --------------------------------------------------------------
        // CALCULATE FINAL AMOUNT
        // --------------------------------------------------------------

        final finalCharge = _calculateParkingChargeAtTime(
          startTime,
          parkingCharge,
          graceTimeSeconds,
          checkoutTime,
        );

        // --------------------------------------------------------------
        // COPY ALL ORIGINAL DATA
        // --------------------------------------------------------------

        final backupData = Map<String, dynamic>.from(originalData);

        // --------------------------------------------------------------
        // Keep the original document id so reports can read completed
        // tickets under the same location-scoped rules as active tickets.
        // --------------------------------------------------------------

        backupData['id'] = originalRef.id;

        // --------------------------------------------------------------
        // STATUS
        // --------------------------------------------------------------

        backupData['status'] = 'out';
        // Attribute the completed exit and collected revenue to the gate
        // operator who processed it. Keep operatorId as the entry operator
        // for compatibility with older screens and records.
        backupData['entryOperatorId'] =
            originalData['entryOperatorId'] ?? originalData['operatorId'] ?? '';
        final cachedOpName = AppDataCache.instance.operatorName?.trim();
        final exitOpName = (cachedOpName != null && cachedOpName.isNotEmpty)
            ? cachedOpName
            : (_auth.currentUser?.displayName ?? '');
        backupData['exitOperatorId'] = _auth.currentUser?.uid ?? '';
        backupData['exitOperatorName'] = exitOpName;
        backupData['entryOperatorName'] =
            originalData['entryOperatorName'] ?? '';
        backupData['exitLocationId'] = _userLocationId ?? '';

        // --------------------------------------------------------------
        // END TIME
        // --------------------------------------------------------------

        backupData['endTime'] = Timestamp.fromDate(checkoutTime);

        backupData['checkoutCompletedAt'] = Timestamp.fromDate(checkoutTime);

        // --------------------------------------------------------------
        // FINAL AMOUNT
        //
        // Keep parkingCharges as the original base rate.
        //
        // Example:
        //
        // parkingCharges       = 500
        // checkoutAmount       = 1000
        // finalParkingCharges  = 1000
        // --------------------------------------------------------------

        backupData['checkoutAmount'] = finalCharge;

        // Keep the canonical amount populated for older reports and
        // dashboard widgets that still read `charges` directly.
        backupData['charges'] = finalCharge;

        backupData['finalParkingCharges'] = finalCharge;

        // --------------------------------------------------------------
        // AUDIT
        // --------------------------------------------------------------

        backupData['backupCreatedAt'] = FieldValue.serverTimestamp();

        backupData['updatedAt'] = Timestamp.fromDate(checkoutTime);

        // --------------------------------------------------------------
        // UPDATE ORIGINAL TICKET
        // --------------------------------------------------------------

        transaction.set(originalRef, backupData);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedVehicleId = null;
        _searchQuery = '';
      });

      _searchController.clear();

      _showSuccess('${vehicle.vehicleNumber} checked out successfully.');
    } catch (e) {
      if (!mounted) {
        return;
      }

      String message = e.toString();

      if (message.startsWith('Exception: ')) {
        message = message.substring('Exception: '.length);
      }

      _showError(message);
    }
  }

  // ===========================================================================
  // BILLING CALCULATION
  //
  // EXAMPLE:
  //
  // graceTimeSeconds = 5700
  //                 = 95 minutes
  //
  // parkingCharges = 500
  //
  // 0 - 94:59     = Rs. 0
  // 95:00         = Rs. 500
  // 140:00        = Rs. 1000
  // 185:00        = Rs. 1500
  //
  // After grace:
  //
  // First charge happens at the end of grace.
  //
  // Next charge:
  // 30 min parking + 15 min grace = 45 min later.
  //
  // ===========================================================================

  double _calculateParkingCharge(
    DateTime startTime,
    double parkingCharge,
    int graceTimeSeconds,
  ) {
    final liveGrace = AppDataCache.instance.graceTimeSeconds;
    final effectiveGrace = graceTimeSeconds > 0 ? graceTimeSeconds : liveGrace;

    return _calculateParkingChargeAtTime(
      startTime,
      parkingCharge,
      effectiveGrace,
      DateTime.now(),
    );
  }

  double _calculateParkingChargeAtTime(
    DateTime startTime,
    double parkingCharge,
    int graceTimeSeconds,
    DateTime endTime,
  ) {
    if (parkingCharge <= 0) {
      return 0;
    }

    var elapsed = endTime.difference(startTime);

    if (elapsed.isNegative) {
      elapsed = Duration.zero;
    }

    // --------------------------------------------------------------
    // LOCATION GRACE PERIOD
    // --------------------------------------------------------------

    final gracePeriod = Duration(seconds: graceTimeSeconds);

    // Vehicle is still FREE.
    if (elapsed < gracePeriod) {
      return 0;
    }

    // --------------------------------------------------------------
    // FIRST CHARGE
    // --------------------------------------------------------------

    const subsequentBillingWindow = Duration(minutes: 45);

    final timeAfterGrace = elapsed - gracePeriod;

    // Each additional charge occurs every:
    //
    // 30 minutes + 15 minutes grace
    //
    // = 45 minutes.
    final additionalCharges =
        timeAfterGrace.inSeconds ~/ subsequentBillingWindow.inSeconds;

    // First charge + additional charges.
    final totalCharges = 1 + additionalCharges;

    return parkingCharge * totalCharges;
  }

  // ===========================================================================
  // BILLING PERIODS
  // ===========================================================================

  int _billingPeriods(DateTime startTime, int graceTimeSeconds) {
    var elapsed = DateTime.now().difference(startTime);

    if (elapsed.isNegative) {
      elapsed = Duration.zero;
    }

    final gracePeriod = Duration(seconds: graceTimeSeconds);

    // Still completely free.
    if (elapsed < gracePeriod) {
      return 0;
    }

    const subsequentBillingWindow = Duration(minutes: 45);

    final timeAfterGrace = elapsed - gracePeriod;

    final additionalCharges =
        timeAfterGrace.inSeconds ~/ subsequentBillingWindow.inSeconds;

    return 1 + additionalCharges;
  }

  // ===========================================================================
  // DURATION
  // ===========================================================================

  String _calculateDuration(DateTime startTime) {
    var difference = DateTime.now().difference(startTime);

    if (difference.isNegative) {
      difference = Duration.zero;
    }

    final days = difference.inDays;

    final hours = difference.inHours % 24;

    final minutes = difference.inMinutes % 60;

    if (days > 0) {
      return '${days}d ${hours}h';
    }

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes}m';
  }

  // ===========================================================================
  // GRACE TIME FORMAT
  // ===========================================================================

  String _formatGraceTime(int seconds) {
    if (seconds <= 0) {
      return 'No grace';
    }

    final duration = Duration(seconds: seconds);

    final hours = duration.inHours;

    final minutes = duration.inMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m FREE';
    }

    if (hours > 0) {
      return '${hours}h FREE';
    }

    return '${minutes}m FREE';
  }

  // ===========================================================================
  // FIRESTORE DATE
  // ===========================================================================

  DateTime? firestoreDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  // ===========================================================================
  // FIRESTORE DOUBLE
  // ===========================================================================

  double firestoreDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  // ===========================================================================
  // FIRESTORE INT
  // ===========================================================================

  int firestoreInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  // ===========================================================================
  // FORMAT DATE
  // ===========================================================================

  String _formatDateTime(DateTime value) {
    final localValue = value.toLocal();

    final hour = localValue.hour;

    final minute = localValue.minute.toString().padLeft(2, '0');

    final period = hour >= 12 ? 'PM' : 'AM';

    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '${localValue.day.toString().padLeft(2, '0')}/'
        '${localValue.month.toString().padLeft(2, '0')}/'
        '${localValue.year} '
        '$displayHour:$minute $period';
  }

  // ===========================================================================
  // CHARGE ROW
  // ===========================================================================

  Widget _chargeRow(ThemeData theme, String label, String value) {
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // INFO CARD
  // ===========================================================================

  Widget _infoCard(ThemeData theme, List<Widget> children) {
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.13)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 42,
                color: colorScheme.outline.withValues(alpha: 0.10),
              ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // INFO ROW
  // ===========================================================================

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: colorScheme.onSurface.withValues(alpha: 0.40),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // INVALID TICKET
  // ===========================================================================

  Widget _buildInvalidTicket(ThemeData theme, String message) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  // ===========================================================================
  // NO VEHICLES
  // ===========================================================================

  Widget _buildNoVehiclesFound(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 29,
                color: colorScheme.onSurface.withValues(alpha: 0.40),
              ),
            ),
            const SizedBox(height: 13),
            Text(
              'No Vehicles Found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Try another vehicle number or category.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: colorScheme.onSurface.withValues(alpha: 0.50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SUCCESS
  // ===========================================================================

  void _showSuccess(String message) {
    if (!mounted) {
      return;
    }

    AppToast.success(context, 'Vehicle released', message);
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    AppToast.error(context, 'Could not release vehicle', message);
  }
}

// =============================================================================
// VEHICLE MODEL
// =============================================================================

class _Vehicle {
  final String id;

  final String vehicleNumber;
  final String category;
  final String location;
  final String ticketNumber;

  final String driverName;
  final String phoneNumber;
  final String notes;

  // Price for one billing charge.
  final double parkingCharges;

  // Location-specific free grace period.
  final int graceTimeSeconds;

  final DateTime? startTime;

  final String status;

  final String locationId;
  final int locationNumericId;

  const _Vehicle({
    required this.id,
    required this.vehicleNumber,
    required this.category,
    required this.location,
    required this.ticketNumber,
    required this.driverName,
    required this.phoneNumber,
    required this.notes,
    required this.parkingCharges,
    required this.graceTimeSeconds,
    required this.startTime,
    required this.status,
    required this.locationId,
    required this.locationNumericId,
  });

  // ===========================================================================
  // FROM FIRESTORE
  // ===========================================================================

  factory _Vehicle.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? startTime;

    final rawStartTime = data['startTime'];

    if (rawStartTime is Timestamp) {
      startTime = rawStartTime.toDate();
    } else if (rawStartTime is DateTime) {
      startTime = rawStartTime;
    } else if (rawStartTime is String) {
      startTime = DateTime.tryParse(rawStartTime);
    }

    return _Vehicle(
      id: id,

      vehicleNumber: data['vehicleNumber']?.toString() ?? '',

      category: _formatCategory(data['vehicleCategory']?.toString() ?? ''),

      location: data['locationName']?.toString() ?? '',

      ticketNumber: data['ticketNumber']?.toString() ?? '',

      driverName: data['driverName']?.toString() ?? '',

      phoneNumber: data['phoneNumber']?.toString() ?? '',

      notes: data['notes']?.toString() ?? '',

      parkingCharges: _toDouble(data['parkingCharges']),

      graceTimeSeconds: _toInt(data['graceTimeSeconds']),

      startTime: startTime,

      status: data['status']?.toString() ?? '',

      locationId: data['locationId']?.toString() ?? '',

      locationNumericId: _toInt(data['locationNumericId']),
    );
  }

  // ===========================================================================
  // CATEGORY
  // ===========================================================================

  static String _formatCategory(String value) {
    if (value.isEmpty) {
      return 'Unknown';
    }

    return value[0].toUpperCase() + value.substring(1);
  }

  // ===========================================================================
  // DOUBLE
  // ===========================================================================

  static double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  // ===========================================================================
  // INT
  // ===========================================================================

  static int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }
}
