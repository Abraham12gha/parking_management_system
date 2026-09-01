import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme_controller.dart';

class SettingScreenOperator extends StatefulWidget {
  const SettingScreenOperator({super.key});

  @override
  State<SettingScreenOperator> createState() => _SettingScreenOperatorState();
}

class _SettingScreenOperatorState extends State<SettingScreenOperator> {

  // ============================================================
  // Operator Information
  // ============================================================

  String _operatorName = '';
  String _operatorEmail = '';
  String _operatorLocation = '';

  int? _parkingCharges;
  int? _graceTimeSeconds;


  bool _loadingOperatorInfo = true;
  bool _loadingParkingCharges = true;

  static const String _operatorNameKey = 'operator_name';
  static const String _operatorEmailKey = 'operator_email';
  static const String _operatorLocationKey = 'operator_location';
  static const String _parkingChargesKey = 'parking_charges';
  static const String _graceTimeKey = 'grace_time_seconds';

  // ============================================================
  // Branding
  // ============================================================

  final _appNameController = TextEditingController(text: 'My Admin App');

  Uint8List? _logoBytes;
  String? _logoUrl;

  // ============================================================
  // Payment
  // ============================================================

  final _paymentFormKey = GlobalKey<FormState>();

  final _apiKeyController = TextEditingController();
  final _merchantIdController = TextEditingController();

  // ============================================================
  // General
  // ============================================================

  bool _notificationsEnabled = true;
  bool _maintenanceMode = false;
  String _language = 'English';



  Future<void> _loadCachedOperatorInfo() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedName =
    prefs.getString(_operatorNameKey);

    final cachedEmail =
    prefs.getString(_operatorEmailKey);

    final cachedLocation =
    prefs.getString(_operatorLocationKey);

    debugPrint('===== LOADING CACHED OPERATOR INFO =====');
    debugPrint('Cached name: $cachedName');
    debugPrint('Cached email: $cachedEmail');
    debugPrint('Cached location: $cachedLocation');

    if (!mounted) return;

    setState(() {
      _operatorName = cachedName ?? '';
      _operatorEmail = cachedEmail ?? '';
      _operatorLocation = cachedLocation ?? '';

      // We don't need the loading spinner if cache exists.
      _loadingOperatorInfo =
          cachedName == null &&
              cachedEmail == null &&
              cachedLocation == null;
    });

    // Now get the latest data from Firestore.
    await _loadOperatorInfo();
  }

  String _formatGraceTime(int? seconds) {
    if (seconds == null || seconds <= 0) {
      return 'No free time';
    }

    final duration = Duration(seconds: seconds);

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return '$hours ${hours == 1 ? 'hour' : 'hours'} '
          '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }

    if (hours > 0) {
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }

    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
  }

  Future<void> _loadCachedParkingCharges() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedCharges =
    prefs.getInt(_parkingChargesKey);

    final cachedGraceTime =
    prefs.getInt(_graceTimeKey);

    debugPrint(
      'Cached parking charges: $cachedCharges',
    );

    debugPrint(
      'Cached grace time: $cachedGraceTime',
    );

    if (!mounted) return;

    if (cachedCharges != null) {
      setState(() {
        _parkingCharges = cachedCharges;
        _graceTimeSeconds = cachedGraceTime ?? 0;
        _loadingParkingCharges = false;
      });
    }

    // Get latest value from Firestore in background.
    await _loadParkingCharges();
  }

  Future<void> _loadParkingCharges() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint(
          'PARKING SETTINGS: No authenticated user.',
        );

        if (!mounted) return;

        setState(() {
          _loadingParkingCharges = false;
        });

        return;
      }

      // ----------------------------------------------------------
      // Get operator document
      // ----------------------------------------------------------

      final userDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDocument.exists) {
        debugPrint(
          'PARKING SETTINGS: User document not found.',
        );

        if (!mounted) return;

        setState(() {
          _loadingParkingCharges = false;
        });

        return;
      }

      final userData = userDocument.data();

      // ----------------------------------------------------------
      // Get location ID
      // ----------------------------------------------------------

      final locationId =
      userData?['location']?.toString();

      if (locationId == null || locationId.isEmpty) {
        debugPrint(
          'PARKING SETTINGS: Location ID missing.',
        );

        if (!mounted) return;

        setState(() {
          _loadingParkingCharges = false;
        });

        return;
      }

      debugPrint(
        'PARKING SETTINGS: Location ID = $locationId',
      );

      // ----------------------------------------------------------
      // Get location
      // ----------------------------------------------------------

      final locationDocument = await FirebaseFirestore.instance
          .collection('locations')
          .doc(locationId)
          .get();

      if (!locationDocument.exists) {
        debugPrint(
          'PARKING SETTINGS: Location not found.',
        );

        if (!mounted) return;

        setState(() {
          _loadingParkingCharges = false;
        });

        return;
      }

      final locationData = locationDocument.data();

      // ----------------------------------------------------------
      // Get parking settings
      // ----------------------------------------------------------

      final charges = locationData?['parkingCharges'];
      final graceTime = locationData?['graceTimeSeconds'];

      if (charges == null) {
        debugPrint(
          'PARKING SETTINGS: parkingCharges missing.',
        );

        if (!mounted) return;

        setState(() {
          _loadingParkingCharges = false;
        });

        return;
      }

      final int latestCharges =
      (charges as num).toInt();

      final int latestGraceTime =
      graceTime != null
          ? (graceTime as num).toInt()
          : 0;

      debugPrint(
        'Latest parking charges: $latestCharges',
      );

      debugPrint(
        'Latest grace time: $latestGraceTime seconds',
      );

      // ----------------------------------------------------------
      // SAVE TO CACHE
      // ----------------------------------------------------------

      final prefs =
      await SharedPreferences.getInstance();

      await prefs.setInt(
        _parkingChargesKey,
        latestCharges,
      );

      await prefs.setInt(
        _graceTimeKey,
        latestGraceTime,
      );

      debugPrint(
        'Parking settings saved to cache.',
      );

      // ----------------------------------------------------------
      // UPDATE UI
      // ----------------------------------------------------------

      if (!mounted) return;

      setState(() {
        _parkingCharges = latestCharges;
        _graceTimeSeconds = latestGraceTime;
        _loadingParkingCharges = false;
      });

      debugPrint(
        'Parking settings loaded successfully.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'PARKING SETTINGS ERROR: $e',
      );

      debugPrint(
        'STACK TRACE: $stackTrace',
      );

      // Keep cached values if Firestore fails.
      if (!mounted) return;

      setState(() {
        _loadingParkingCharges = false;
      });
    }
  }

  // ============================================================
  // INIT STATE
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadCachedParkingCharges();
    _loadCachedOperatorInfo();
  }



  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _appNameController.dispose();
    _apiKeyController.dispose();
    _merchantIdController.dispose();

    super.dispose();
  }

  // ============================================================
  // PICK LOGO
  // ============================================================

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();

      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      if (!mounted) return;

      setState(() {
        _logoBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage('Could not pick image: $e', isError: true);
    }
  }

  // ============================================================
  // LOAD OPERATOR INFORMATION
  // ============================================================

  Future<void> _loadOperatorInfo() async {
    try {
      debugPrint('===== LOADING LATEST OPERATOR INFO =====');

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint('No authenticated user.');

        if (!mounted) return;

        setState(() {
          _loadingOperatorInfo = false;
        });

        return;
      }

      debugPrint('UID: ${user.uid}');
      debugPrint('Email: ${user.email}');

      final userDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      debugPrint(
        'User document exists: ${userDocument.exists}',
      );

      if (!userDocument.exists) {
        debugPrint(
          'users/${user.uid} does not exist.',
        );

        if (!mounted) return;

        setState(() {
          _loadingOperatorInfo = false;
        });

        return;
      }

      final userData = userDocument.data();

      debugPrint('User data: $userData');

      // ==========================================================
      // OPERATOR NAME
      // ==========================================================

      final firstName =
      userData?['firstName']?.toString();

      // ==========================================================
      // EMAIL
      // ==========================================================

      final email =
          userData?['email']?.toString() ??
              user.email ??
              '';

      // ==========================================================
      // LOCATION ID
      // ==========================================================

      final locationId =
      userData?['location']?.toString();

      String locationName = '';

      // ==========================================================
      // GET LOCATION NAME
      // ==========================================================

      if (locationId != null &&
          locationId.isNotEmpty) {

        debugPrint(
          'Getting location: $locationId',
        );

        final locationDocument =
        await FirebaseFirestore.instance
            .collection('locations')
            .doc(locationId)
            .get();

        debugPrint(
          'Location document exists: '
              '${locationDocument.exists}',
        );

        if (locationDocument.exists) {
          final locationData =
          locationDocument.data();

          debugPrint(
            'Location data: $locationData',
          );

          locationName =
              locationData?['locationName']
                  ?.toString() ??
                  '';
        }
      }

      // ==========================================================
      // SAVE TO CACHE
      // ==========================================================

      final prefs =
      await SharedPreferences.getInstance();

      await prefs.setString(
        _operatorNameKey,
        firstName ?? '',
      );

      await prefs.setString(
        _operatorEmailKey,
        email,
      );

      await prefs.setString(
        _operatorLocationKey,
        locationName,
      );

      debugPrint(
        'Operator information saved to cache.',
      );

      // ==========================================================
      // UPDATE UI
      // ==========================================================

      if (!mounted) return;

      setState(() {
        _operatorName =
        firstName?.isNotEmpty == true
            ? firstName!
            : 'Not available';

        _operatorEmail =
        email.isNotEmpty
            ? email
            : 'Not available';

        _operatorLocation =
        locationName.isNotEmpty
            ? locationName
            : 'Not assigned';

        _loadingOperatorInfo = false;
      });

      debugPrint(
        'Latest operator information loaded successfully.',
      );

    } catch (e, stackTrace) {
      debugPrint(
        'LOAD OPERATOR INFO ERROR: $e',
      );

      debugPrint(
        'STACK TRACE: $stackTrace',
      );

      // IMPORTANT:
      // Do NOT delete the cached data if Firestore fails.
      // The user should still see the last known data.

      if (!mounted) return;

      setState(() {
        _loadingOperatorInfo = false;
      });
    }
  }

  // ============================================================
  // SAVE PAYMENT SETTINGS
  // ============================================================

  void _savePaymentSettings() {
    if (_paymentFormKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();

      // TODO:
      // Save API key and Merchant ID to Firestore
      // when payment integration is implemented.

      _showMessage('Payment settings saved');
    }
  }

  // ============================================================
  // SHOW MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? Colors.redAccent
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ========================================================
        // Operator Information
        // ========================================================
        _SectionCard(
          title: 'Operator Information',
          icon: Icons.person_outline_rounded,
          children: [
            if (_loadingOperatorInfo)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Column(
                children: [
                  _OperatorInfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Name',
                    value: _operatorName,
                  ),

                  const SizedBox(height: 16),

                  _OperatorInfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: _operatorEmail,
                  ),

                  const SizedBox(height: 16),

                  _OperatorInfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: _operatorLocation,
                  ),
                ],
              ),
          ],
        ),

        const SizedBox(height: 20),

        // ========================================================
        // Parking Charges
        // ========================================================
        // ========================================================
// Parking Settings
// ========================================================
        _SectionCard(
          title: 'Parking Settings',
          icon: Icons.local_parking_outlined,
          children: [
            if (_loadingParkingCharges &&
                _parkingCharges == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool compact = constraints.maxWidth < 600;

                  if (compact) {
                    return Column(
                      children: [
                        _ParkingSettingCard(
                          icon: Icons.payments_outlined,
                          title: 'Parking Charge',
                          value: _parkingCharges == null
                              ? 'Not available'
                              : 'Rs. $_parkingCharges',
                          unit: 'per hour',
                          description:
                          'Amount charged for each parking hour.',
                        ),

                        const SizedBox(height: 12),

                        _ParkingSettingCard(
                          icon: Icons.timer_outlined,
                          title: 'Grace Time',
                          value: _formatGraceTime(
                            _graceTimeSeconds,
                          ),
                          unit: 'free parking',
                          description:
                          'Free time before parking charges begin.',
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: _ParkingSettingCard(
                          icon: Icons.payments_outlined,
                          title: 'Parking Charge',
                          value: _parkingCharges == null
                              ? 'Not available'
                              : 'Rs. $_parkingCharges',
                          unit: 'per hour',
                          description:
                          'Amount charged for each parking hour.',
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: _ParkingSettingCard(
                          icon: Icons.timer_outlined,
                          title: 'Grace Time',
                          value: _formatGraceTime(
                            _graceTimeSeconds,
                          ),
                          unit: 'free parking',
                          description:
                          'Free time before parking charges begin.',
                        ),
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 14),

            // Simple explanation for operators
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.035),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 19,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      'Customers can park for the grace time for free. '
                          'Parking charges apply after the free period ends.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),


        const SizedBox(height: 20),

        // ========================================================
        // Appearance
        // ========================================================
        _SectionCard(
          title: 'Appearance',
          icon: Icons.palette_outlined,
          children: [
            ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeController.themeMode,
              builder: (context, mode, _) {
                return Column(
                  children: [
                    _SwitchTile(
                      title: 'Dark Mode',
                      subtitle: 'Switch between light and dark theme',
                      icon: mode == ThemeMode.dark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      value: mode == ThemeMode.dark,
                      onChanged: mode == ThemeMode.system
                          ? null
                          : (v) => ThemeController.toggleDark(v),
                    ),

                    _SwitchTile(
                      title: 'Use System Theme',
                      subtitle: 'Automatically match your device setting',
                      icon: Icons.smartphone_rounded,
                      value: mode == ThemeMode.system,
                      onChanged: (v) => ThemeController.useSystem(v),
                    ),
                  ],
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ========================================================
        // General
        // ========================================================
        _SectionCard(
          title: 'General',
          icon: Icons.tune_rounded,
          children: [
            _SwitchTile(
              title: 'Push Notifications',
              subtitle: 'Get notified about orders and activity',
              icon: Icons.notifications_active_outlined,
              value: _notificationsEnabled,
              onChanged: (v) {
                setState(() {
                  _notificationsEnabled = v;
                });
              },
            ),

            _SwitchTile(
              title: 'Maintenance Mode',
              subtitle: 'Temporarily take the storefront offline',
              icon: Icons.build_outlined,
              value: _maintenanceMode,
              onChanged: (v) {
                setState(() {
                  _maintenanceMode = v;
                });
              },
            ),

            const SizedBox(height: 8),

            _LanguageRow(
              value: _language,
              onChanged: (v) {
                setState(() {
                  _language = v ?? _language;
                });
              },
            ),

            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {},
                icon: Icon(
                  Icons.lock_outline_rounded,
                  color: colorScheme.primary,
                ),
                label: Text(
                  'Change Password',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
      ],
    );
  }
}

// =================================================================
// SECTION CARD
// =================================================================

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 20),
              ),

              const SizedBox(width: 12),

              Text(
                title,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          ...children,
        ],
      ),
    );
  }
}

// =================================================================
// SWITCH TILE
// =================================================================

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurface.withOpacity(0.7)),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

// =================================================================
// LABELED FIELD
// =================================================================

class _LabeledField extends StatefulWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.obscure = false,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final String? Function(String?)? validator;

  @override
  State<_LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<_LabeledField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withOpacity(0.85),
          ),
        ),

        const SizedBox(height: 8),

        TextFormField(
          controller: widget.controller,
          obscureText: widget.obscure && _obscured,
          validator: widget.validator,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: widget.hint,

            hintStyle: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.35),
            ),

            prefixIcon: widget.icon != null
                ? Icon(
                    widget.icon,
                    size: 19,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  )
                : null,

            suffixIcon: widget.obscure
                ? IconButton(
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 19,
                    ),
                    color: colorScheme.onSurface.withOpacity(0.5),
                    onPressed: () {
                      setState(() {
                        _obscured = !_obscured;
                      });
                    },
                  )
                : null,

            filled: true,

            fillColor: colorScheme.onSurface.withOpacity(0.03),

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.onSurface.withOpacity(0.1),
              ),
            ),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.onSurface.withOpacity(0.1),
              ),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),

            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
        ),
      ],
    );
  }
}

// =================================================================
// SAVE BUTTON
// =================================================================

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ElevatedButton.icon(
      onPressed: onPressed,

      icon: const Icon(Icons.check_rounded, size: 18),

      label: Text(label),

      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
}

// =================================================================
// LOGO PICKER
// =================================================================

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({
    required this.logoBytes,
    required this.logoUrl,
    required this.onTap,
  });

  final Uint8List? logoBytes;
  final String? logoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    ImageProvider? image;

    if (logoBytes != null) {
      image = MemoryImage(logoBytes!);
    } else if (logoUrl != null && logoUrl!.isNotEmpty) {
      image = NetworkImage(logoUrl!);
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colorScheme.onSurface.withOpacity(0.08),
              ),
              image: image != null
                  ? DecorationImage(image: image, fit: BoxFit.cover)
                  : null,
            ),
            child: image == null
                ? Icon(
                    Icons.image_outlined,
                    color: colorScheme.primary.withOpacity(0.6),
                    size: 30,
                  )
                : null,
          ),

          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                color: colorScheme.onPrimary,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// LANGUAGE ROW
// =================================================================

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  static const List<String> _languages = ['English', 'Urdu', 'Arabic'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          Icons.language_rounded,
          size: 20,
          color: colorScheme.onSurface.withOpacity(0.7),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Text(
            'App Language',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),

        DropdownButton<String>(
          value: value,
          underline: const SizedBox.shrink(),

          items: _languages
              .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
              .toList(),

          onChanged: onChanged,
        ),
      ],
    );
  }
}

// =================================================================
// OPERATOR INFO ROW
// =================================================================

class _OperatorInfoRow extends StatelessWidget {
  const _OperatorInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 20),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withOpacity(0.55),
                ),
              ),

              const SizedBox(height: 3),

              Text(
                value,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


















class _ParkingSettingCard extends StatelessWidget {
  const _ParkingSettingCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String value;
  final String unit;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.onSurface.withOpacity(0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
              size: 23,
            ),
          ),

          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primary,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: colorScheme.onSurface.withOpacity(0.5),
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