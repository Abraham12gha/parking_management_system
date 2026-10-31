import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

import '../app_model/location_model.dart';
import '../app_model/parking_membership_model.dart';
import '../app_settings.dart';
import '../resources/widget/app_toast.dart';
import '../services/company_settings_service.dart';
import '../services/location_service.dart';
import '../services/membership_service.dart';
import '../services/report_download.dart';
import '../services/tenant_context.dart';

class _MembershipPlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final plate = newValue.text.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (plate.length > 12 || !RegExp(r'^[A-Z0-9-]*$').hasMatch(plate)) {
      return oldValue;
    }
    return TextEditingValue(
      text: plate,
      selection: TextSelection.collapsed(offset: plate.length),
    );
  }
}

class _AmountThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) return newValue.copyWith(text: '');
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(raw)) return oldValue;

    final parts = raw.split('.');
    final integer = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final formatted = parts.length == 1 ? integer : '$integer.${parts.last}';
    final rawBeforeCursor = newValue.text
        .substring(0, newValue.selection.end.clamp(0, newValue.text.length))
        .replaceAll(',', '')
        .length;
    var cursor = 0;
    var consumed = 0;
    while (cursor < formatted.length && consumed < rawBeforeCursor) {
      if (formatted[cursor] != ',') consumed++;
      cursor++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}

class MembershipsScreen extends ConsumerStatefulWidget {
  const MembershipsScreen({super.key});

  @override
  ConsumerState<MembershipsScreen> createState() => _MembershipsScreenState();
}

class _MembershipsScreenState extends ConsumerState<MembershipsScreen> {
  final _searchController = TextEditingController();
  final _locations = <LocationModel>[];
  StreamSubscription<List<LocationModel>>? _locationsSub;
  String _search = '';
  Future<AppSettings>? _settingsFuture;

  @override
  void initState() {
    super.initState();
    _locationsSub = LocationService().getLocations().listen((locations) {
      if (mounted)
        setState(() {
          _locations
            ..clear()
            ..addAll(locations);
        });
    });
    _settingsFuture = _loadBrandSettings();
  }

  Future<AppSettings> _loadBrandSettings() async {
    try {
      if (!TenantContext.instance.isReady) {
        await TenantContext.instance.loadForCurrentUser();
      }
      return await CompanySettingsService.instance.getSettings();
    } catch (_) {
      return const AppSettings(appName: 'Parking Management');
    }
  }

  @override
  void dispose() {
    _locationsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addMembership() async {
    if (_locations.isEmpty) {
      AppToast.warning(
        context,
        'Locations not ready',
        'Load the company locations before adding a membership.',
      );
      return;
    }
    final created = await showDialog<ParkingMembership>(
      context: context,
      builder: (_) => _MembershipFormDialog(locations: List.of(_locations)),
    );
    if (!mounted || created == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => FutureBuilder<AppSettings>(
        future: _settingsFuture,
        builder: (context, snapshot) => _MembershipCardDialog(
          membership: created,
          settings:
              snapshot.data ?? const AppSettings(appName: 'Parking Management'),
        ),
      ),
    );
  }

  Future<void> _showCard(ParkingMembership membership) async {
    final settings = await (_settingsFuture ??= _loadBrandSettings());
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _MembershipCardDialog(membership: membership, settings: settings),
    );
  }

  Future<void> _toggleMembership(ParkingMembership member) async {
    final activating = member.status.toLowerCase() != 'active';
    final action = activating ? 'activate' : 'deactivate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${activating ? 'Activate' : 'Deactivate'} member?'),
        content: Text(
          '${member.fullName} will ${action} for new member check-ins. The member and visit records will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(activating ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await MembershipService.instance.setMembershipActive(
        member,
        active: activating,
      );
      if (mounted) {
        AppToast.success(
          context,
          activating ? 'Member activated' : 'Member deactivated',
          activating
              ? 'This member can check in while the card is valid.'
              : 'The member record and visit history were kept.',
        );
      }
    } catch (error) {
      if (mounted) AppToast.error(context, 'Could not update member', '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberships = ref.watch(membershipsProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Parking memberships',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addMembership,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add member'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Create flexible memberships, print portrait cards, and track every member visit.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search name, plate, phone, or location',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: memberships.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text('Could not load members: $error')),
                data: (all) {
                  final filtered = all
                      .where(
                        (m) =>
                            '${m.fullName} ${m.vehicleNumber} ${m.phoneNumber} ${m.locationName}'
                                .toLowerCase()
                                .contains(_search),
                      )
                      .toList();
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No memberships found. Add a member to issue the first card.',
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final member = filtered[index];
                      final active = member.isValidAt(DateTime.now());
                      final manuallyInactive =
                          member.status.toLowerCase() != 'active';
                      final statusLabel = manuallyInactive
                          ? 'Inactive'
                          : active
                          ? 'Active'
                          : 'Expired';
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              active
                                  ? Icons.card_membership
                                  : Icons.event_busy_outlined,
                            ),
                          ),
                          title: Text(
                            member.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${member.vehicleNumber}  •  ${member.locationName}\nExpires ${DateFormat.yMMMd().format(member.expiresAt)}  •  Rs. ${NumberFormat('#,##0.##').format(member.amount)}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(
                                label: Text(statusLabel),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: active
                                    ? Colors.green.withValues(alpha: .12)
                                    : null,
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Member actions',
                                onSelected: (action) {
                                  if (action == 'toggle') {
                                    _toggleMembership(member);
                                  } else if (action == 'card') {
                                    _showCard(member);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(
                                      manuallyInactive
                                          ? 'Activate member'
                                          : 'Deactivate member',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'card',
                                    child: Text('View or download card'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembershipFormDialog extends StatefulWidget {
  const _MembershipFormDialog({required this.locations});
  final List<LocationModel> locations;

  @override
  State<_MembershipFormDialog> createState() => _MembershipFormDialogState();
}

class _MembershipFormDialogState extends State<_MembershipFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _plate = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _months = TextEditingController(text: '1');
  final _amount = TextEditingController();
  String? _locationId;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _plate.dispose();
    _phone.dispose();
    _email.dispose();
    _months.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final location = widget.locations.firstWhere(
      (item) => item.id == _locationId,
    );
    setState(() => _saving = true);
    try {
      final membership = await MembershipService.instance.createMembership(
        fullName: _name.text,
        vehicleNumber: _plate.text,
        phoneNumber: _phone.text,
        email: _email.text,
        locationId: location.id,
        locationName: location.locationName,
        durationMonths: int.parse(_months.text.trim()),
        amount: double.parse(_amount.text.replaceAll(',', '').trim()),
      );
      if (mounted) Navigator.of(context).pop(membership);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '$label is required.' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add parking member'),
      content: SizedBox(
        width: 580,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Member name *',
                    hintText: 'Enter the member’s full name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => _required(v, 'Name'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _plate,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [_MembershipPlateFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Vehicle number *',
                    hintText: 'e.g. ABC-123',
                    helperText:
                        'Spaces are removed and letters are capitalized.',
                    prefixIcon: Icon(Icons.directions_car_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final value = (v ?? '').toUpperCase().replaceAll(
                      RegExp(r'\s+'),
                      '',
                    );
                    return RegExp(r'^[A-Z0-9-]{3,12}$').hasMatch(value)
                        ? null
                        : 'Use 3–12 letters, numbers, or dashes.';
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number *',
                    hintText: 'Enter a contact number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => _required(v, 'Phone'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    hintText: 'name@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)
                        ? null
                        : 'Enter a valid email.';
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _locationId,
                  decoration: const InputDecoration(
                    labelText: 'Parking location *',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.locations
                      .map(
                        (location) => DropdownMenuItem(
                          value: location.id,
                          child: Text(
                            location.locationName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _locationId = value),
                  validator: (value) =>
                      value == null ? 'Choose a parking location.' : null,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _months,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration (months) *',
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final months = int.tryParse((v ?? '').trim());
                          return months == null || months < 1 || months > 600
                              ? 'Enter 1–600 months.'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _amount,
                        inputFormatters: [_AmountThousandsFormatter()],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount (Rs.) *',
                          prefixIcon: Icon(Icons.payments_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final amount = double.tryParse(
                            (v ?? '').replaceAll(',', '').trim(),
                          );
                          return amount == null ||
                                  !amount.isFinite ||
                                  amount < 0
                              ? 'Enter a valid amount.'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  '* Required fields. Expiry is calculated from today; the admin sets the membership amount.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.card_membership),
          label: Text(_saving ? 'Saving…' : 'Create membership'),
        ),
      ],
    );
  }
}

class _MembershipCardDialog extends StatefulWidget {
  const _MembershipCardDialog({
    required this.membership,
    required this.settings,
  });
  final ParkingMembership membership;
  final AppSettings settings;

  @override
  State<_MembershipCardDialog> createState() => _MembershipCardDialogState();
}

class _MembershipCardDialogState extends State<_MembershipCardDialog> {
  bool _downloading = false;

  Future<void> _downloadPdf() async {
    setState(() => _downloading = true);
    try {
      pw.MemoryImage? logo;
      final logoUrl = widget.settings.logoUrl?.trim();
      if (logoUrl != null && logoUrl.isNotEmpty) {
        try {
          final response = await http
              .get(Uri.parse(logoUrl))
              .timeout(const Duration(seconds: 4));
          if (response.statusCode == 200)
            logo = pw.MemoryImage(response.bodyBytes);
        } catch (_) {}
      }
      final member = widget.membership;
      final document = pw.Document();
      document.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(340, 560),
          margin: const pw.EdgeInsets.all(14),
          build: (_) => pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.blueGrey700, width: 1.2),
              borderRadius: pw.BorderRadius.circular(18),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null)
                  pw.Image(logo, height: 38, fit: pw.BoxFit.contain),
                pw.SizedBox(height: 6),
                pw.Text(
                  widget.settings.appName,
                  maxLines: 2,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'PARKING MEMBERSHIP',
                  style: pw.TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.5,
                    color: PdfColors.blueGrey600,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: member.qrPayload,
                  width: 128,
                  height: 128,
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  member.fullName,
                  maxLines: 2,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                _pdfRow('Vehicle', member.vehicleNumber),
                _pdfRow('Phone', member.phoneNumber),
                if (member.email.isNotEmpty) _pdfRow('Email', member.email),
                _pdfRow('Location', member.locationName),
                _pdfRow(
                  'Status',
                  member.status.toLowerCase() != 'active'
                      ? 'INACTIVE'
                      : member.isValidAt(DateTime.now())
                      ? 'ACTIVE'
                      : 'EXPIRED',
                ),
                _pdfRow(
                  'Valid until',
                  DateFormat('dd MMM yyyy').format(member.expiresAt),
                ),
                pw.Spacer(),
                pw.Divider(color: PdfColors.blueGrey200),
                pw.Text(
                  'Contact software development:',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.blueGrey700,
                  ),
                ),
                pw.Text(
                  'Abraham Daniel  •  +92 3193526506',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'abrahamdaniel963@gmail.com',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),
        ),
      );
      final safePlate = member.vehicleNumber.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );
      final path = await downloadReportBytes(
        'parking_membership_$safePlate.pdf',
        await document.save(),
      );
      if (mounted) AppToast.success(context, 'Membership card saved', path);
    } catch (error) {
      if (mounted) AppToast.error(context, 'Could not save card', '$error');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  static pw.Widget _pdfRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 62,
          child: pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.blueGrey600,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            maxLines: 2,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Membership card'),
      content: SingleChildScrollView(
        child: Center(
          child: _MembershipCardView(
            membership: widget.membership,
            settings: widget.settings,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: _downloading ? null : _downloadPdf,
          icon: _downloading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(_downloading ? 'Creating PDF…' : 'Download PDF'),
        ),
      ],
    );
  }
}

class _MembershipCardView extends StatelessWidget {
  const _MembershipCardView({required this.membership, required this.settings});
  final ParkingMembership membership;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 310,
      child: AspectRatio(
        aspectRatio: .62,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.primary, colors.tertiary],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: .18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              if (settings.logoUrl?.isNotEmpty == true)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    settings.logoUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.local_parking,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.local_parking_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              const SizedBox(height: 6),
              Text(
                settings.appName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'PARKING MEMBERSHIP',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .78),
                  letterSpacing: 1.4,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: membership.qrPayload,
                  version: QrVersions.auto,
                  size: 112,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                membership.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _cardDetail('VEHICLE', membership.vehicleNumber),
              _cardDetail('PHONE', membership.phoneNumber),
              if (membership.email.isNotEmpty)
                _cardDetail('EMAIL', membership.email),
              _cardDetail('LOCATION', membership.locationName),
              _cardDetail(
                'STATUS',
                membership.status.toLowerCase() != 'active'
                    ? 'INACTIVE'
                    : membership.isValidAt(DateTime.now())
                    ? 'ACTIVE'
                    : 'EXPIRED',
              ),
              _cardDetail(
                'EXPIRES',
                DateFormat('dd MMM yyyy').format(membership.expiresAt),
              ),
              const Spacer(),
              Divider(color: Colors.white.withValues(alpha: .35)),
              const Text(
                'Contact software development:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 8),
              ),
              const Text(
                'Abraham Daniel  •  +92 3193526506',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'abrahamdaniel963@gmail.com',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardDetail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .72),
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
