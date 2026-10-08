import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../resources/widget/app_toast.dart';
import '../app_model/location_model.dart';
import '../services/location_service.dart';
import 'add_location.dart';

class LocationsManagementScreen extends StatefulWidget {
  const LocationsManagementScreen({super.key});

  @override
  State<LocationsManagementScreen> createState() =>
      _LocationsManagementScreenState();
}

class _LocationsManagementScreenState extends State<LocationsManagementScreen> {
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showAddForm = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              formattedTime = 'No grace time (billing starts immediately)';
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
                      // Header
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
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  location.locationName,
                                  style: theme.textTheme.bodySmall?.copyWith(
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
                        'Set free parking duration before hourly charges begin. Changes sync instantly to all operators active at this facility.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Time Selector Box
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
                                  Text(
                                    'Hours',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          size: 22,
                                        ),
                                        onPressed: currentHours > 0
                                            ? () => setDialogState(
                                                () => currentHours--,
                                              )
                                            : null,
                                      ),
                                      Text(
                                        '$currentHours',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          size: 22,
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
                                  Text(
                                    'Minutes',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          size: 22,
                                        ),
                                        onPressed: currentMinutes >= 5
                                            ? () => setDialogState(
                                                () => currentMinutes -= 5,
                                              )
                                            : null,
                                      ),
                                      Text(
                                        '$currentMinutes',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          size: 22,
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
                      Text(
                        'Quick Presets:',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _presetChip(
                            'No grace',
                            0,
                            0,
                            currentHours,
                            currentMinutes,
                            (h, m) {
                              setDialogState(() {
                                currentHours = h;
                                currentMinutes = m;
                              });
                            },
                          ),
                          _presetChip(
                            '10 min',
                            0,
                            10,
                            currentHours,
                            currentMinutes,
                            (h, m) {
                              setDialogState(() {
                                currentHours = h;
                                currentMinutes = m;
                              });
                            },
                          ),
                          _presetChip(
                            '15 min',
                            0,
                            15,
                            currentHours,
                            currentMinutes,
                            (h, m) {
                              setDialogState(() {
                                currentHours = h;
                                currentMinutes = m;
                              });
                            },
                          ),
                          _presetChip(
                            '30 min',
                            0,
                            30,
                            currentHours,
                            currentMinutes,
                            (h, m) {
                              setDialogState(() {
                                currentHours = h;
                                currentMinutes = m;
                              });
                            },
                          ),
                          _presetChip(
                            '45 min',
                            0,
                            45,
                            currentHours,
                            currentMinutes,
                            (h, m) {
                              setDialogState(() {
                                currentHours = h;
                                currentMinutes = m;
                              });
                            },
                          ),
                          _presetChip(
                            '1 hour',
                            1,
                            0,
                            currentHours,
                            currentMinutes,
                            (h, m) {
                              setDialogState(() {
                                currentHours = h;
                                currentMinutes = m;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Preview summary banner
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
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.sync_rounded, size: 18),
                            label: const Text('Save & Update Operators'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
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
                                  AppToast.success(
                                    context,
                                    'Grace time updated',
                                    '${location.locationName} now allows ${location.formattedGraceTime}. Operators updated in real time.',
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  AppToast.error(
                                    context,
                                    'Could not update grace time',
                                    'Failed to update grace time: $e',
                                  );
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

  Widget _presetChip(
    String label,
    int hours,
    int minutes,
    int curH,
    int curM,
    void Function(int, int) onSelect,
  ) {
    final isSelected = curH == hours && curM == minutes;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelect(hours, minutes),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  void _openEditLocationDialog(BuildContext context, LocationModel location) {
    final nameCtrl = TextEditingController(text: location.locationName);
    final addrCtrl = TextEditingController(text: location.address);
    final chargesCtrl = TextEditingController(
      text: location.parkingCharges.toString(),
    );
    int hours = location.graceTimeSeconds ~/ 3600;
    int mins = (location.graceTimeSeconds % 3600) ~/ 60;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.edit_location_alt_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Edit Location Details',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Location Name',
                              prefixIcon: Icon(Icons.business_outlined),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Enter location name'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: addrCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Address',
                              prefixIcon: Icon(Icons.place_outlined),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Enter address'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: chargesCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Hourly Charges (PKR)',
                              prefixIcon: Icon(Icons.payments_outlined),
                              prefixText: 'Rs. ',
                            ),
                            validator: (v) =>
                                v == null || int.tryParse(v.trim()) == null
                                ? 'Enter valid rate'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Grace Period:',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: hours,
                                  decoration: const InputDecoration(
                                    labelText: 'Hours',
                                  ),
                                  items: List.generate(
                                    25,
                                    (i) => DropdownMenuItem(
                                      value: i,
                                      child: Text('$i hrs'),
                                    ),
                                  ),
                                  onChanged: (v) =>
                                      setDialogState(() => hours = v ?? 0),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: (mins ~/ 5) * 5,
                                  decoration: const InputDecoration(
                                    labelText: 'Minutes',
                                  ),
                                  items: List.generate(
                                    12,
                                    (i) => DropdownMenuItem(
                                      value: i * 5,
                                      child: Text('${i * 5} min'),
                                    ),
                                  ),
                                  onChanged: (v) =>
                                      setDialogState(() => mins = v ?? 0),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogCtx).pop(),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) return;
                                  Navigator.of(dialogCtx).pop();
                                  final totalSec = (hours * 3600) + (mins * 60);
                                  await _locationService.updateLocation(
                                    locationId: location.id,
                                    locationName: nameCtrl.text.trim(),
                                    address: addrCtrl.text.trim(),
                                    parkingCharges: int.parse(
                                      chargesCtrl.text.trim(),
                                    ),
                                    graceTimeSeconds: totalSec,
                                  );
                                  if (mounted) {
                                    AppToast.success(
                                      context,
                                      'Location updated',
                                      'Your changes have been saved.',
                                    );
                                  }
                                },
                                child: const Text('Save Changes'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteLocation(BuildContext context, LocationModel location) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text(
          'Are you sure you want to remove "${location.locationName}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await _locationService.deleteLocation(location.id);
              if (mounted) {
                AppToast.success(
                  context,
                  'Location deleted',
                  '"${location.locationName}" was removed.',
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLocationAnalysis(
    BuildContext context,
    LocationModel location,
  ) async {
    final result = await FirebaseFirestore.instance
        .collection('parking_tickets')
        .where('locationId', isEqualTo: location.id)
        .get();
    final tickets = result.docs.map((doc) => doc.data()).toList();
    final active = tickets
        .where((ticket) => '${ticket['status']}'.toLowerCase() == 'in')
        .length;
    final completed = tickets.length - active;
    final revenue = tickets.fold<num>(0, (sum, ticket) {
      if ('${ticket['status']}'.toLowerCase() == 'in') return sum;
      return sum +
          (ticket['checkoutAmount'] as num? ??
              ticket['finalParkingCharges'] as num? ??
              ticket['charges'] as num? ??
              0);
    });
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${location.locationName} Analysis'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('All-time ticket records: ${tickets.length}'),
            const SizedBox(height: 8),
            Text('Currently parked: $active'),
            const SizedBox(height: 8),
            Text('Completed visits: $completed'),
            const SizedBox(height: 8),
            Text('Recorded revenue: Rs. ${revenue.toStringAsFixed(0)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_showAddForm) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: colorScheme.surface,
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showAddForm = false),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back to Locations List'),
                ),
              ],
            ),
          ),
          const Expanded(child: AddLocationAdmin()),
        ],
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: StreamBuilder<List<LocationModel>>(
        stream: _locationService.getLocations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allLocations = snapshot.data ?? [];
          final filtered = allLocations.where((loc) {
            if (_searchQuery.isEmpty) return true;
            return loc.locationName.toLowerCase().contains(_searchQuery) ||
                loc.address.toLowerCase().contains(_searchQuery);
          }).toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.location_city_rounded,
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
                                      'Locations & Grace Periods',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Manage facility rates and grace periods. Changing grace time immediately updates all operators in real time.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .textTheme
                                                .bodyMedium
                                                ?.color
                                                ?.withValues(alpha: 0.65),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  setState(() => _showAddForm = true),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add Location'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Search and Stats Bar
                    LayoutBuilder(
                      builder: (context, searchConstraints) {
                        final compact = searchConstraints.maxWidth < 520;
                        final searchField = TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search location by name or address...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            filled: true,
                            fillColor: colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: theme.dividerColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        );
                        final total = Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Text(
                            'Total Locations: ${allLocations.length}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                        return compact
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  searchField,
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: total,
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: searchField),
                                  const SizedBox(width: 16),
                                  total,
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Location Cards Grid
                    if (filtered.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(48),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.location_off_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No parking locations found'
                                  : 'No locations matching "$_searchQuery"',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_searchQuery.isEmpty)
                              ElevatedButton(
                                onPressed: () =>
                                    setState(() => _showAddForm = true),
                                child: const Text('Add First Location'),
                              ),
                          ],
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isDesktop ? 2 : 1,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 290,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final loc = filtered[index];
                          return _buildLocationCard(context, loc);
                        },
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context, LocationModel location) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasGrace = location.graceTimeSeconds > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
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
          // Top Row: Name, code, menu
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  location.numericId > 0
                      ? '#LOC-${location.numericId.toString().padLeft(2, '0')}'
                      : '#LOC',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  location.locationName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (v) {
                  if (v == 'grace') _openGraceTimeDialog(context, location);
                  if (v == 'edit') _openEditLocationDialog(context, location);
                  if (v == 'delete') _confirmDeleteLocation(context, location);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'grace',
                    child: Text('Change Grace Time'),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Details'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete Location',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Address
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  location.address,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Badges Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Rate Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 15,
                      color: Color(0xFF1976D2),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Rs. ${location.parkingCharges}/hr',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                  ],
                ),
              ),

              // Grace Time Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: hasGrace
                      ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 15,
                      color: hasGrace
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasGrace
                          ? 'Grace: ${location.formattedGraceTime}'
                          : 'No Grace Period',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: hasGrace
                            ? const Color(0xFF2E7D32)
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              // Real-time active vehicles inside indicator
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('parking_tickets')
                    .where('locationId', isEqualTo: location.id)
                    .where('status', isEqualTo: 'in')
                    .snapshots(),
                builder: (context, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.directions_car_filled_rounded,
                          size: 15,
                          color: Color(0xFFE65100),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$count Parked',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const Spacer(),

          // Actions
          Divider(color: theme.dividerColor, height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => _openEditLocationDialog(context, location),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Details'),
              ),
              TextButton.icon(
                onPressed: () => _showLocationAnalysis(context, location),
                icon: const Icon(Icons.insights_outlined, size: 16),
                label: const Text('Analyze'),
              ),
              ElevatedButton.icon(
                onPressed: () => _openGraceTimeDialog(context, location),
                icon: const Icon(Icons.timer_rounded, size: 16),
                label: const Text('Change Grace Time'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
