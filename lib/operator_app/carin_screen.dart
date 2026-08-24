import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
enum VehicleCategory { bike, selfParking, valetParking }

class CarinScreen extends StatefulWidget {
  final VoidCallback onBack;
  const CarinScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<CarinScreen> createState() => _CarinScreenState();
}

class _CarinScreenState extends State<CarinScreen> {
  VehicleCategory _selectedCategory = VehicleCategory.valetParking;

  // Controllers for the form fields.
  final _vehicleNumberController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _driverNameController.dispose();
    _phoneNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Theme.of(context).colorScheme.surface,
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogHeader(
                onClose: widget.onBack,
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vehicle Category',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CategorySelector(
                        selected: _selectedCategory,
                        onSelected: (category) {
                          setState(() => _selectedCategory = category);
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Vehicle Details',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _VehicleDetailsForm(
                        vehicleNumberController: _vehicleNumberController,
                        driverNameController: _driverNameController,
                        phoneNumberController: _phoneNumberController,
                        notesController: _notesController,
                      ),
                    ],
                  ),
                ),
              ),
              _DialogFooter(
                onCancel: widget.onBack,
                onGenerateTicket: () {
                  // TODO: Validate fields, create the vehicle entry
                  // record, and save it (e.g. to Firestore).
                },
              ),
            ],
          ),
        ),
      ),
            ),
    ));
  }
}

// ============================================================
// Header: title on the left, close (X) button on the right,
// plus a row of ticket/time/operator meta info underneath.
// ============================================================
class _DialogHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _DialogHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFEFF1EF),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Vehicle Entry',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                // TODO: Replace these placeholder values with the
                // real ticket number, timestamp, and logged-in
                _HeaderMetaRow(
                  ticketNumber: 'TKT-9001',
                  dateTime: DateFormat('h:mm a, MMM dd, yyyy').format(DateTime.now()),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            color: const Color(0xFF616161),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetaRow extends StatelessWidget {
  final String ticketNumber;
  final String dateTime;

  const _HeaderMetaRow({
    required this.ticketNumber,
    required this.dateTime,
  });

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 13, color: Color(0xFF616161));
    const dotSpacing = SizedBox(width: 10);

    // Wrap lets these bits of meta info flow onto a new line
    // instead of overflowing on narrow windows.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Icon(Icons.confirmation_number_outlined,
            size: 15, color: Color(0xFF616161)),
        const SizedBox(width: 4),
        Text('Ticket #$ticketNumber', style: textStyle),
        dotSpacing,
        const Text('•', style: textStyle),
        dotSpacing,
        const Icon(Icons.access_time, size: 15, color: Color(0xFF616161)),
        const SizedBox(width: 4),
        Text(dateTime, style: textStyle),
      ],
    );
  }
}

// ============================================================
// The 3 selectable vehicle category cards: Bike, Self Parking,
// Valet Parking.
// ============================================================
class _CategorySelector extends StatelessWidget {
  final VehicleCategory selected;
  final ValueChanged<VehicleCategory> onSelected;

  const _CategorySelector({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CategoryCard(
            icon: Icons.two_wheeler,
            label: 'Bike',
            isSelected: selected == VehicleCategory.bike,
            onTap: () => onSelected(VehicleCategory.bike),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CategoryCard(
            icon: Icons.local_parking,
            label: 'Self Parking',
            isSelected: selected == VehicleCategory.selfParking,
            onTap: () => onSelected(VehicleCategory.selfParking),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CategoryCard(
            icon: Icons.directions_car,
            label: 'Valet Parking',
            isSelected: selected == VehicleCategory.valetParking,
            onTap: () => onSelected(VehicleCategory.valetParking),
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFA8E6A3) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? Colors.black87 : const Color(0xFF424242),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.black87 : const Color(0xFF424242),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Vehicle Details form: Vehicle Number + Driver Name side by
// side, Phone Number below (half width), then a full-width
// Notes textarea.
// ============================================================
class _VehicleDetailsForm extends StatelessWidget {
  final TextEditingController vehicleNumberController;
  final TextEditingController driverNameController;
  final TextEditingController phoneNumberController;
  final TextEditingController notesController;

  const _VehicleDetailsForm({
    required this.vehicleNumberController,
    required this.driverNameController,
    required this.phoneNumberController,
    required this.notesController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vehicle Number + Driver Name row.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _FormField(
                label: 'Vehicle Number',
                isRequired: true,
                controller: vehicleNumberController,
                hintText: 'E.g. ABC-1234',
                icon: Icons.badge_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _FormField(
                label: 'Driver Name',
                controller: driverNameController,
                hintText: 'Optional',
                icon: Icons.person_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Phone Number only takes up half the row width, matching
        // the design (left column only).
        Row(
          children: [
            Expanded(
              child: _FormField(
                label: 'Phone Number',
                controller: phoneNumberController,
                hintText: 'Optional',
                icon: Icons.call_outlined,
              ),
            ),
            const SizedBox(width: 16),
            // Empty spacer so the field above stays half-width.
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
        const SizedBox(height: 16),
        // Notes textarea, full width.
        _FormField(
          label: 'Notes',
          controller: notesController,
          hintText: 'Any damage notes or special instructions...',
          icon: Icons.notes,
          maxLines: 3,
        ),
      ],
    );
  }
}

// A single labeled text field, reused for every input above.
class _FormField extends StatelessWidget {
  final String label;
  final bool isRequired;
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final int maxLines;

  const _FormField({
    required this.label,
    this.isRequired = false,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          // Notes gets its icon aligned to the top instead of centered.
          textAlignVertical: maxLines > 1 ? null : TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
            prefixIcon: maxLines > 1
                ? Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Icon(icon, size: 18, color: const Color(0xFF9E9E9E)),
            )
                : Icon(icon, size: 18, color: const Color(0xFF9E9E9E)),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogFooter extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onGenerateTicket;

  const _DialogFooter({
    required this.onCancel,
    required this.onGenerateTicket,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: .end,
        spacing: 12,
        children: [
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF424242),
              side: const BorderSide(color: Color(0xFFBDBDBD)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: onGenerateTicket,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.local_print_shop_outlined, size: 18),
            label: const Text('Generate + Print'),
          ),
        ],
      ),
    );
  }
}