import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
import '../services/company_settings_service.dart';
import '../theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  // Operator Information
  String _operatorName = 'Loading...';
  String _operatorEmail = 'Loading...';
  String _operatorLocation = 'Loading...';
  bool _loadingOperatorInfo = true;
  // Branding
  final _appNameController = TextEditingController(text: 'My Admin App');

  Uint8List? _logoBytes;
  String? _logoUrl;

  // Payment
  final _paymentFormKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _merchantIdController = TextEditingController();

  // General
  bool _notificationsEnabled = true;
  bool _maintenanceMode = false;
  String _language = 'English';

  @override
  void dispose() {
    _appNameController.dispose();
    _apiKeyController.dispose();
    _merchantIdController.dispose();
    super.dispose();
  }
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

      _showMessage(
        'Could not pick image: $e',
        isError: true,
      );
    }
  }

  Future<void> _saveBranding() async {
    final appName = _appNameController.text.trim();

    if (appName.isEmpty) {
      _showMessage(
        'App name cannot be empty',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    try {
      String? newLogoUrl;

      if (_logoBytes != null) {
        newLogoUrl = await CloudinaryService.instance.uploadImage(
          bytes: _logoBytes!,
          fileName: 'app_logo.jpg',
        );

        debugPrint('Cloudinary URL: $newLogoUrl');
      }

      await CompanySettingsService.instance.updateSettings(
        appName: appName,
        logoUrl: newLogoUrl,
      );

      debugPrint('Firestore settings saved successfully');

      if (!mounted) return;

      setState(() {
        if (newLogoUrl != null) {
          _logoUrl = newLogoUrl;
          _logoBytes = null;
        }
      });

      _showMessage('Branding updated');
    } catch (e, stackTrace) {
      debugPrint('SAVE BRANDING ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');

      if (!mounted) return;

      _showMessage(
        'Could not save branding: $e',
        isError: true,
      );
    }
  }


  void _savePaymentSettings() {
    if (_paymentFormKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      // TODO: persist _apiKeyController.text and _merchantIdController.text.
      _showMessage('Payment settings saved');
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Future<void> _loadCompanySettings() async {
    try {
      final settings =
      await CompanySettingsService.instance.getSettings();

      if (!mounted) return;

      setState(() {
        _appNameController.text = settings.appName;
        _logoUrl = settings.logoUrl;
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not load company settings',
        isError: true,
      );
    }
  }












  Future<void> _loadOperatorInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _operatorName = 'Not available';
          _operatorEmail = 'Not available';
          _operatorLocation = 'Not available';
          _loadingOperatorInfo = false;
        });

        return;
      }

      final userDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDocument.data();

      if (!mounted) return;

      setState(() {
        _operatorName =
            userData?['name']?.toString() ??
                user.displayName ??
                'Not available';

        _operatorEmail =
            user.email ?? 'Not available';

        _operatorLocation =
            userData?['location']?.toString() ??
                'Not available';

        _loadingOperatorInfo = false;
      });
    } catch (e) {
      debugPrint('LOAD OPERATOR INFO ERROR: $e');

      if (!mounted) return;

      setState(() {
        _operatorName = 'Not available';
        _operatorEmail = 'Not available';
        _operatorLocation = 'Not available';
        _loadingOperatorInfo = false;
      });
    }
  }




  @override
  void initState() {
    super.initState();
    _loadCompanySettings();
    _loadOperatorInfo();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [




// ---------------- Operator Information ----------------
    _SectionCard(
    title: 'Operator Information',
      icon: Icons.person_outline_rounded,
      children: [
        if (_loadingOperatorInfo)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(),
            ),
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





    // ---------------- App Branding ----------------
        _SectionCard(
          title: 'App Branding',
          icon: Icons.storefront_outlined,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LogoPicker(
                  logoBytes: _logoBytes,
                  logoUrl: _logoUrl,
                  onTap: _pickLogo,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('App Logo',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: colorScheme.onSurface)),
                      const SizedBox(height: 4),
                      Text(
                        'PNG or JPG, square image recommended (min 256x256).',
                        style: TextStyle(fontSize: 12.5, color: colorScheme.onSurface.withOpacity(0.6)),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _pickLogo,
                        icon: const Icon(Icons.upload_rounded, size: 18),
                        label: const Text('Upload New Logo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                          side: BorderSide(color: colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _LabeledField(
              label: 'App Name',
              controller: _appNameController,
              hint: 'Enter your app name',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: _SaveButton(label: 'Save Changes', onPressed: _saveBranding),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ---------------- Payment Settings ----------------
        _SectionCard(
          title: 'Payment/Charges Settings',
          icon: Icons.payments_outlined,
          children: [
            Form(
              key: _paymentFormKey,
              child: Column(
                children: [
                  _LabeledField(
                    label: 'Payment Gateway API Key',
                    controller: _apiKeyController,
                    hint: '500',
                    icon: Icons.payments_outlined,
                    obscure: true,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'API key is required' : null,
                  ),
                  const SizedBox(height: 16),
                  _LabeledField(
                    label: 'New Parking Charges',
                    controller: _merchantIdController,
                    hint: 'e.g 850',
                    icon: Icons.payments_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Merchant ID is required' : null,
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _SaveButton(label: 'Save Changes', onPressed: _savePaymentSettings),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ---------------- Appearance ----------------
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
                      icon: mode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      value: mode == ThemeMode.dark,
                      onChanged: mode == ThemeMode.system ? null : (v) => ThemeController.toggleDark(v),
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
        // ---------------- General ----------------
        _SectionCard(
          title: 'General',
          icon: Icons.tune_rounded,
          children: [
            _SwitchTile(
              title: 'Push Notifications',
              subtitle: 'Get notified about orders and activity',
              icon: Icons.notifications_active_outlined,
              value: _notificationsEnabled,
              onChanged: (v) => setState(() => _notificationsEnabled = v),
            ),
            _SwitchTile(
              title: 'Maintenance Mode',
              subtitle: 'Temporarily take the storefront offline',
              icon: Icons.build_outlined,
              value: _maintenanceMode,
              onChanged: (v) => setState(() => _maintenanceMode = v),
            ),
            const SizedBox(height: 8),
            _LanguageRow(
              value: _language,
              onChanged: (v) => setState(() => _language = v ?? _language),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {},
                icon: Icon(Icons.lock_outline_rounded, color: colorScheme.primary),
                label: Text('Change Password',
                    style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ==================== Reusable pieces ====================

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.children});

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
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4)),
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
              Text(title, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

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
                Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12.5, color: colorScheme.onSurface.withOpacity(0.6))),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: colorScheme.primary),
        ],
      ),
    );
  }
}

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
        Text(widget.label,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: colorScheme.onSurface.withOpacity(0.85))),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.obscure && _obscured,
          validator: widget.validator,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.35)),
            prefixIcon: widget.icon != null ? Icon(widget.icon, size: 19, color: colorScheme.onSurface.withOpacity(0.5)) : null,
            suffixIcon: widget.obscure
                ? IconButton(
              icon: Icon(_obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19),
              color: colorScheme.onSurface.withOpacity(0.5),
              onPressed: () => setState(() => _obscured = !_obscured),
            )
                : null,
            filled: true,
            fillColor: colorScheme.onSurface.withOpacity(0.03),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.1)),
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
                  ? DecorationImage(
                image: image,
                fit: BoxFit.cover,
              )
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
                border: Border.all(
                  color: colorScheme.surface,
                  width: 2,
                ),
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
        Icon(Icons.language_rounded, size: 20, color: colorScheme.onSurface.withOpacity(0.7)),
        const SizedBox(width: 14),
        Expanded(
          child: Text('App Language', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
        ),
        DropdownButton<String>(
          value: value,
          underline: const SizedBox.shrink(),
          items: _languages.map((lang) => DropdownMenuItem(value: lang, child: Text(lang))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}




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
          child: Icon(
            icon,
            color: colorScheme.primary,
            size: 20,
          ),
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
