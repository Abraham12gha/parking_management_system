// import 'package:flutter/material.dart';
//
// import '../services/location_service.dart';
//
// class AddLocationAdmin extends StatefulWidget {
//   const AddLocationAdmin({super.key});
//
//   @override
//   State<AddLocationAdmin> createState() =>
//       _AddLocationAdminState();
// }
//
// class _AddLocationAdminState extends State<AddLocationAdmin> {
//   final LocationService _addLocationService = LocationService();
//   final _formKey = GlobalKey<FormState>();
//
//   final TextEditingController _locationNameController = TextEditingController();
//   final TextEditingController _addressController = TextEditingController();
//
//   @override
//   void dispose() {
//     _locationNameController.dispose();
//     _addressController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _addLocation() async {
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }
//
//     final locationName = _locationNameController.text.trim();
//     final address = _addressController.text.trim();
//
//     try {
//       await _addLocationService.addLocation(
//         locationName: locationName,
//         address: address,
//       );
//
//       if (!mounted) return;
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Location added successfully'),
//         ),
//       );
//
//       _locationNameController.clear();
//       _addressController.clear();
//     } catch (e) {
//       if (!mounted) return;
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Failed to add location'),
//         ),
//       );
//
//       debugPrint('Add location error: $e');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;
//
//     return Scaffold(
//       // No AppBar
//       backgroundColor: theme.scaffoldBackgroundColor,
//       body: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(40),
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 700),
//             child: Form(
//               key: _formKey,
//               child: Container(
//                 padding: const EdgeInsets.all(32),
//                 decoration: BoxDecoration(
//                   color: colorScheme.surface,
//                   borderRadius: BorderRadius.circular(16),
//                   border: Border.all(color: theme.dividerColor),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withValues(alpha: 0.06),
//                       blurRadius: 20,
//                       offset: const Offset(0, 8),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Add Software Counter Location',
//                       style: theme.textTheme.headlineSmall?.copyWith(
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//
//                     const SizedBox(height: 8),
//
//                     Text(
//                       'Enter the location details for the software counter.',
//                       style: theme.textTheme.bodyMedium?.copyWith(
//                         color: theme.textTheme.bodyMedium?.color?.withValues(
//                           alpha: 0.65,
//                         ),
//                       ),
//                     ),
//
//                     const SizedBox(height: 32),
//
//                     // Location Name
//                     Text(
//                       'Location Name',
//                       style: theme.textTheme.titleSmall?.copyWith(
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//
//                     const SizedBox(height: 8),
//
//                     TextFormField(
//                       controller: _locationNameController,
//                       textInputAction: TextInputAction.next,
//                       decoration: InputDecoration(
//                         hintText: 'Enter location name',
//                         prefixIcon: const Icon(Icons.location_on_outlined),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(10),
//                           borderSide: BorderSide(color: theme.dividerColor),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(10),
//                           borderSide: BorderSide(
//                             color: colorScheme.primary,
//                             width: 2,
//                           ),
//                         ),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return 'Please enter the location name';
//                         }
//                         return null;
//                       },
//                     ),
//
//                     const SizedBox(height: 24),
//
//                     // Proper Address
//                     Text(
//                       'Location Proper Address',
//                       style: theme.textTheme.titleSmall?.copyWith(
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//
//                     const SizedBox(height: 8),
//
//                     TextFormField(
//                       controller: _addressController,
//                       minLines: 4,
//                       maxLines: 6,
//                       textInputAction: TextInputAction.newline,
//                       decoration: InputDecoration(
//                         hintText: 'Enter complete location address',
//                         prefixIcon: const Padding(
//                           padding: EdgeInsets.only(bottom: 70),
//                           child: Icon(Icons.home_outlined),
//                         ),
//                         alignLabelWithHint: true,
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(10),
//                           borderSide: BorderSide(color: theme.dividerColor),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(10),
//                           borderSide: BorderSide(
//                             color: colorScheme.primary,
//                             width: 2,
//                           ),
//                         ),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return 'Please enter the proper address';
//                         }
//                         return null;
//                       },
//                     ),
//
//                     const SizedBox(height: 32),
//
//                     // Add Location Button
//                     SizedBox(
//                       width: double.infinity,
//                       height: 52,
//                       child: ElevatedButton.icon(
//                         onPressed: _addLocation,
//                         icon: const Icon(Icons.add_location_alt_outlined),
//                         label: const Text(
//                           'Add Location',
//                           style: TextStyle(
//                             fontSize: 15,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: colorScheme.primary,
//                           foregroundColor: colorScheme.onPrimary,
//                           elevation: 0,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

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

  final TextEditingController _parkingChargesController =
  TextEditingController(text: '100');

  @override
  void dispose() {
    _locationNameController.dispose();
    _addressController.dispose();
    _parkingChargesController.dispose();
    super.dispose();
  }

  Future<void> _addLocation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final locationName = _locationNameController.text.trim();
    final address = _addressController.text.trim();

    // Convert parking charges into a number
    final parkingCharges =
    int.parse(_parkingChargesController.text.trim());

    try {
      await _addLocationService.addLocation(
        locationName: locationName,
        address: address,
        parkingCharges: parkingCharges,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location added successfully')),
      );

      _locationNameController.clear();
      _addressController.clear();
      _parkingChargesController.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to add location')));

      debugPrint('Add location error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Software Counter Location',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Enter the location details and parking charges.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Location Name
                    Text(
                      'Location Name',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _locationNameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Enter location name',
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
                            color: colorScheme.primary,
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

                    // Address
                    Text(
                      'Location Proper Address',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _addressController,
                      minLines: 4,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Enter complete location address',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 70),
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
                            color: colorScheme.primary,
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

                    const SizedBox(height: 24),

                    // Parking Charges
                    Text(
                      'Parking Charges',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          // Minus Button
                          IconButton(
                            onPressed: () {
                              final currentValue =
                                  int.tryParse(
                                    _parkingChargesController.text,
                                  ) ??
                                  0;

                              final newValue = currentValue - 50;

                              if (newValue >= 0) {
                                _parkingChargesController.text = newValue
                                    .toString();
                              }
                            },
                            icon: const Icon(Icons.remove),
                            tooltip: 'Decrease by Rs. 50',
                          ),

                          const VerticalDivider(width: 1, thickness: 1),

                          // Amount Input
                          Expanded(
                            child: TextFormField(
                              controller: _parkingChargesController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                hintText: '0',
                                prefixText: 'Rs. ',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter parking charges';
                                }

                                final charges = int.tryParse(value.trim());

                                if (charges == null) {
                                  return 'Please enter a valid number';
                                }

                                if (charges < 0) {
                                  return 'Charges cannot be negative';
                                }

                                return null;
                              },
                            ),
                          ),

                          const VerticalDivider(width: 1, thickness: 1),

                          // Plus Button
                          IconButton(
                            onPressed: () {
                              final currentValue =
                                  int.tryParse(
                                    _parkingChargesController.text,
                                  ) ??
                                  0;

                              final newValue = currentValue + 50;

                              _parkingChargesController.text = newValue
                                  .toString();
                            },
                            icon: const Icon(Icons.add),
                            tooltip: 'Increase by Rs. 50',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Use + or − to change by Rs. 50, or enter a custom amount.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Add Location Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _addLocation,
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text(
                          'Add Location',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
