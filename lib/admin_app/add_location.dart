import 'package:flutter/material.dart';
import '../services/location_service.dart';

class AddLocationAdmin extends StatefulWidget {
  const AddLocationAdmin({super.key});

  @override
  State<AddLocationAdmin> createState() => _AddLocationAdminState();
}

class _AddLocationAdminState extends State<AddLocationAdmin> {
  final LocationService _addLocationService = LocationService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _locationNameController = TextEditingController();

  final TextEditingController _addressController = TextEditingController();

  final TextEditingController _parkingChargesController = TextEditingController(
    text: '100',
  );

  // Grace time
  int _graceHours = 0;
  int _graceMinutes = 30;

  @override
  void dispose() {
    _locationNameController.dispose();
    _addressController.dispose();
    _parkingChargesController.dispose();
    super.dispose();
  }

  int get _totalGraceTimeMinutes {
    return (_graceHours * 60) + _graceMinutes;
  }

  String get _formattedGraceTime {
    if (_graceHours == 0 && _graceMinutes == 0) {
      return 'No grace time';
    }

    final List<String> parts = [];

    if (_graceHours > 0) {
      parts.add('$_graceHours ${_graceHours == 1 ? 'hour' : 'hours'}');
    }

    if (_graceMinutes > 0) {
      parts.add('$_graceMinutes ${_graceMinutes == 1 ? 'minute' : 'minutes'}');
    }

    return parts.join(' ');
  }

  void _setGraceTime(int hours, int minutes) {
    setState(() {
      _graceHours = hours;
      _graceMinutes = minutes;
    });
  }

  void _changeHours(int amount) {
    setState(() {
      _graceHours = (_graceHours + amount).clamp(0, 24);
    });
  }

  void _changeMinutes(int amount) {
    int totalMinutes = _totalGraceTimeMinutes + amount;

    totalMinutes = totalMinutes.clamp(0, 1440);

    setState(() {
      _graceHours = totalMinutes ~/ 60;
      _graceMinutes = totalMinutes % 60;
    });
  }


  Future<void> _addLocation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final locationName = _locationNameController.text.trim();
    final address = _addressController.text.trim();

    final parkingCharges =
    int.parse(_parkingChargesController.text.trim());

    // Convert the selected grace time into total seconds.
    //
    // Example:
    // 1 hour 25 minutes
    // = (1 * 60 + 25) minutes
    // = 85 minutes
    // = 5100 seconds
    final graceTimeSeconds =
        ((_graceHours * 60) + _graceMinutes) * 60;

    try {
      await _addLocationService.addLocation(
        locationName: locationName,
        address: address,
        parkingCharges: parkingCharges,
        graceTimeSeconds: graceTimeSeconds,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location added successfully'),
        ),
      );

      _locationNameController.clear();
      _addressController.clear();
      _parkingChargesController.text = '100';

      setState(() {
        _graceHours = 0;
        _graceMinutes = 30;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add location: $e'),
        ),
      );

      debugPrint('Add location error: $e');
    }
  }



  // ------------------------------------------------------------
  // SECTION TITLE
  // ------------------------------------------------------------

  Widget _sectionTitle({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // FIELD LABEL
  // ------------------------------------------------------------

  Widget _fieldLabel(BuildContext context, String title, {String? helper}) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 3),
          Text(
            helper,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
            ),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------
  // CARD
  // ------------------------------------------------------------

  Widget _card({required BuildContext context, required Widget child}) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: child,
    );
  }

  // ------------------------------------------------------------
  // PARKING CHARGES
  // ------------------------------------------------------------

  Widget _parkingCharges(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(
          context,
          'Parking Charges',
          helper: 'Amount charged for each parking hour.',
        ),

        const SizedBox(height: 10),

        Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Decrease by Rs. 50',
                onPressed: () {
                  final current =
                      int.tryParse(_parkingChargesController.text) ?? 0;

                  final value = current - 50;

                  if (value >= 0) {
                    setState(() {
                      _parkingChargesController.text = value.toString();
                    });
                  }
                },
                icon: const Icon(Icons.remove),
              ),

              const VerticalDivider(width: 1, thickness: 1),

              Expanded(
                child: TextFormField(
                  controller: _parkingChargesController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    prefixText: 'Rs. ',
                    hintText: '100',
                    border: InputBorder.none,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter parking charges';
                    }

                    final amount = int.tryParse(value.trim());

                    if (amount == null) {
                      return 'Enter a valid amount';
                    }

                    if (amount < 0) {
                      return 'Amount cannot be negative';
                    }

                    return null;
                  },
                ),
              ),

              const VerticalDivider(width: 1, thickness: 1),

              IconButton(
                tooltip: 'Increase by Rs. 50',
                onPressed: () {
                  final current =
                      int.tryParse(_parkingChargesController.text) ?? 0;

                  setState(() {
                    _parkingChargesController.text = (current + 50).toString();
                  });
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // GRACE TIME
  // ------------------------------------------------------------

  Widget _graceTime(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(
          context,
          'Grace Time',
          helper: 'Free parking time before charges begin.',
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _timeSelector(
                  context: context,
                  title: 'Hours',
                  value: _graceHours,
                  onDecrease: () => _changeHours(-1),
                  onIncrease: () => _changeHours(1),
                ),
              ),

              Container(width: 1, height: 60, color: theme.dividerColor),

              Expanded(
                child: _timeSelector(
                  context: context,
                  title: 'Minutes',
                  value: _graceMinutes,
                  onDecrease: () => _changeMinutes(-5),
                  onIncrease: () => _changeMinutes(5),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Text(
          'Quick select',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _preset(context, 'No grace', 0, 0),
            _preset(context, '15 min', 0, 15),
            _preset(context, '30 min', 0, 30),
            _preset(context, '1 hour', 1, 0),
            _preset(context, '2 hours', 2, 0),
          ],
        ),

        const SizedBox(height: 14),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 20, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Free parking: $_formattedGraceTime',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // TIME SELECTOR
  // ------------------------------------------------------------

  Widget _timeSelector({
    required BuildContext context,
    required String title,
    required int value,
    required VoidCallback onDecrease,
    required VoidCallback onIncrease,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _smallButton(context, Icons.remove, onDecrease),

            SizedBox(
              width: 48,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            _smallButton(context, Icons.add, onIncrease),
          ],
        ),
      ],
    );
  }

  Widget _smallButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed,
  ) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // PRESET
  // ------------------------------------------------------------

  Widget _preset(BuildContext context, String label, int hours, int minutes) {
    final theme = Theme.of(context);

    final selected = _graceHours == hours && _graceMinutes == minutes;

    return OutlinedButton(
      onPressed: () {
        _setGraceTime(hours, minutes);
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : null,
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : theme.dividerColor,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? theme.colorScheme.primary : null,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SUMMARY
  // ------------------------------------------------------------

  Widget _summary(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final locationName = _locationNameController.text.trim();

    final parking = _parkingChargesController.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(Icons.summarize_outlined, color: colorScheme.primary),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location Summary',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _summaryItem(
                      context,
                      Icons.location_on_outlined,
                      locationName.isEmpty ? 'Location name' : locationName,
                    ),

                    _summaryItem(
                      context,
                      Icons.payments_outlined,
                      'Rs. ${parking.isEmpty ? '0' : parking}/hour',
                    ),

                    _summaryItem(
                      context,
                      Icons.timer_outlined,
                      _formattedGraceTime,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 17,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
        ),

        const SizedBox(width: 6),

        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // LOCATION INFORMATION CARD
  // ------------------------------------------------------------

  Widget _locationInformation(BuildContext context) {
    final theme = Theme.of(context);

    return _card(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            context: context,
            icon: Icons.location_on_outlined,
            title: 'Location Information',
            subtitle: 'Enter the basic details of the parking location.',
          ),

          const SizedBox(height: 28),

          _fieldLabel(context, 'Location Name'),

          const SizedBox(height: 8),

          TextFormField(
            controller: _locationNameController,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'e.g. Dolmen Mall Clifton',
              prefixIcon: const Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the location name';
              }

              return null;
            },
          ),

          const SizedBox(height: 24),

          _fieldLabel(
            context,
            'Proper Address',
            helper: 'Enter the complete address of the location.',
          ),

          const SizedBox(height: 8),

          TextFormField(
            controller: _addressController,
            minLines: 5,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'e.g. Block 4, Clifton, Karachi, Pakistan',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 65),
                child: Icon(Icons.home_outlined),
              ),
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the proper address';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // PARKING SETTINGS CARD
  // ------------------------------------------------------------

  Widget _parkingSettings(BuildContext context) {
    return _card(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            context: context,
            icon: Icons.settings_outlined,
            title: 'Parking Settings',
            subtitle: 'Configure charges and customer grace time.',
          ),

          const SizedBox(height: 28),

          _parkingCharges(context),

          const SizedBox(height: 28),

          _graceTime(context),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // Two columns on desktop.
    final bool isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 40 : 20,
                vertical: isDesktop ? 28 : 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ==========================
                        // PAGE HEADER
                        // ==========================
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.add_location_alt_outlined,
                                color: theme.colorScheme.primary,
                              ),
                            ),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add Parking Location',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    'Create and configure a new valet parking location.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ==========================
                        // MAIN CONTENT
                        // ==========================
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _locationInformation(context),
                              ),

                              const SizedBox(width: 20),

                              Expanded(
                                flex: 5,
                                child: _parkingSettings(context),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _locationInformation(context),

                              const SizedBox(height: 20),

                              _parkingSettings(context),
                            ],
                          ),

                        const SizedBox(height: 20),

                        // ==========================
                        // SUMMARY
                        // ==========================
                        _summary(context),

                        const SizedBox(height: 24),

                        // ==========================
                        // ACTION BUTTONS
                        // ==========================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const SizedBox(width: 12),

                            ElevatedButton.icon(
                              onPressed: _addLocation,
                              icon: const Icon(Icons.check),
                              label: const Text('Add Location'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(170, 48),
                                elevation: 0,
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
