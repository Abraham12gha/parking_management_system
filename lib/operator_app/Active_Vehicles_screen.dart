// import 'dart:async';
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
//
// class ActiveVehiclesScreen extends StatefulWidget {
//   const ActiveVehiclesScreen({super.key});
//
//   @override
//   State<ActiveVehiclesScreen> createState() => _ActiveVehiclesScreenState();
// }
//
// class _ActiveVehiclesScreenState extends State<ActiveVehiclesScreen> {
//   final TextEditingController _searchController = TextEditingController();
//
//   String _searchQuery = '';
//
//   Query<Map<String, dynamic>> get _activeVehiclesQuery {
//     return FirebaseFirestore.instance
//         .collection('parking_tickets')
//         .where('status', isEqualTo: 'in')
//         .orderBy('startTime', descending: true);
//   }
//
//   @override
//   void initState() {
//     super.initState();
//
//     _searchController.addListener(_onSearchChanged);
//   }
//
//   void _onSearchChanged() {
//     final query = _searchController.text.trim().toLowerCase();
//
//     if (query != _searchQuery && mounted) {
//       setState(() {
//         _searchQuery = query;
//       });
//     }
//   }
//
//   @override
//   void dispose() {
//     _searchController.removeListener(_onSearchChanged);
//     _searchController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//
//     return Column(
//       children: [
//         _buildTopSection(theme),
//
//         // Important:
//         // ActiveVehiclesScreen itself must receive a bounded height
//         // from its parent because this Expanded needs finite height.
//         Expanded(
//           child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//             stream: _activeVehiclesQuery.snapshots(),
//             builder: (context, snapshot) {
//               if (snapshot.hasError) {
//                 debugPrint(
//                   'Firestore Active Vehicles Error: ${snapshot.error}',
//                 );
//
//                 if (snapshot.error is FirebaseException) {
//                   final error = snapshot.error as FirebaseException;
//
//                   debugPrint(
//                     'Firestore error code: ${error.code}',
//                   );
//
//                   debugPrint(
//                     'Firestore error message: ${error.message}',
//                   );
//                 }
//
//                 return _buildErrorState(
//                   theme,
//                   error: snapshot.error.toString(),
//                 );
//               }
//
//               if (snapshot.connectionState == ConnectionState.waiting &&
//                   !snapshot.hasData) {
//                 return _buildLoadingState(theme);
//               }
//
//               final docs = snapshot.data?.docs ?? [];
//
//               final filteredDocs = docs.where((doc) {
//                 final data = doc.data();
//
//                 final vehicleNumber =
//                 (data['vehicleNumber'] ?? '')
//                     .toString()
//                     .toLowerCase();
//
//                 return vehicleNumber.contains(_searchQuery);
//               }).toList();
//
//               if (filteredDocs.isEmpty) {
//                 if (_searchQuery.isNotEmpty) {
//                   return _buildNoSearchResults(theme);
//                 }
//
//                 return _buildEmptyState(theme);
//               }
//
//               return RefreshIndicator(
//                 color: theme.colorScheme.primary,
//                 onRefresh: _refreshVehicles,
//                 child: ListView.separated(
//                   physics: const AlwaysScrollableScrollPhysics(),
//                   padding: const EdgeInsets.fromLTRB(
//                     16,
//                     8,
//                     16,
//                     24,
//                   ),
//                   itemCount: filteredDocs.length,
//                   separatorBuilder: (_, __) =>
//                   const SizedBox(height: 8),
//                   itemBuilder: (context, index) {
//                     final doc = filteredDocs[index];
//
//                     return _ActiveVehicleRow(
//                       key: ValueKey(doc.id),
//                       data: doc.data(),
//                       onDetails: () {
//                         _showVehicleDetails(
//                           context,
//                           doc.data(),
//                         );
//                       },
//                     );
//                   },
//                 ),
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
//
//   // ===========================================================================
//   // REFRESH
//   // ===========================================================================
//
//   Future<void> _refreshVehicles() async {
//     try {
//       await _activeVehiclesQuery.get(
//         const GetOptions(
//           source: Source.server,
//         ),
//       );
//     } catch (e) {
//       debugPrint('Refresh error: $e');
//     }
//   }
//
//   // ===========================================================================
//   // TOP SECTION
//   // ===========================================================================
//
//   Widget _buildTopSection(ThemeData theme) {
//     final colorScheme = theme.colorScheme;
//
//     return Container(
//       color: colorScheme.surface,
//       padding: const EdgeInsets.fromLTRB(
//         16,
//         12,
//         16,
//         12,
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: SizedBox(
//               height: 46,
//               child: TextField(
//                 controller: _searchController,
//                 textCapitalization: TextCapitalization.characters,
//                 style: TextStyle(
//                   color: colorScheme.onSurface,
//                   fontSize: 14,
//                 ),
//                 decoration: InputDecoration(
//                   hintText: 'Search vehicle number',
//                   hintStyle: TextStyle(
//                     color: colorScheme.onSurface.withValues(
//                       alpha: 0.5,
//                     ),
//                     fontSize: 14,
//                   ),
//                   prefixIcon: Icon(
//                     Icons.search_rounded,
//                     size: 21,
//                     color: colorScheme.onSurface.withValues(
//                       alpha: 0.6,
//                     ),
//                   ),
//                   suffixIcon: _searchQuery.isNotEmpty
//                       ? IconButton(
//                     onPressed: _searchController.clear,
//                     icon: Icon(
//                       Icons.close_rounded,
//                       size: 19,
//                       color: colorScheme.onSurface.withValues(
//                         alpha: 0.65,
//                       ),
//                     ),
//                   )
//                       : null,
//                   filled: true,
//                   fillColor:
//                   theme.inputDecorationTheme.fillColor ??
//                       colorScheme.surfaceContainerHighest,
//                   contentPadding: const EdgeInsets.symmetric(
//                     horizontal: 14,
//                   ),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(10),
//                     borderSide: BorderSide.none,
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(10),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(10),
//                     borderSide: BorderSide(
//                       color: colorScheme.primary,
//                       width: 1.2,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//
//           const SizedBox(width: 10),
//
//           // Active count
//           StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//             stream: _activeVehiclesQuery.snapshots(),
//             builder: (context, snapshot) {
//               final count = snapshot.data?.docs.length ?? 0;
//
//               final activeBackground =
//               theme.brightness == Brightness.dark
//                   ? colorScheme.primary.withValues(alpha: 0.16)
//                   : const Color(0xFFECFDF3);
//
//               final activeColor =
//               theme.brightness == Brightness.dark
//                   ? colorScheme.primary
//                   : const Color(0xFF15803D);
//
//               final dotColor =
//               theme.brightness == Brightness.dark
//                   ? colorScheme.primary
//                   : const Color(0xFF16A34A);
//
//               return Container(
//                 height: 46,
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                 ),
//                 decoration: BoxDecoration(
//                   color: activeBackground,
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Container(
//                       width: 7,
//                       height: 7,
//                       decoration: BoxDecoration(
//                         color: dotColor,
//                         shape: BoxShape.circle,
//                       ),
//                     ),
//                     const SizedBox(width: 7),
//                     Text(
//                       '$count',
//                       style: TextStyle(
//                         color: activeColor,
//                         fontSize: 15,
//                         fontWeight: FontWeight.w800,
//                       ),
//                     ),
//                     const SizedBox(width: 4),
//                     Text(
//                       'Active',
//                       style: TextStyle(
//                         color: activeColor,
//                         fontSize: 12,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ===========================================================================
//   // LOADING
//   // ===========================================================================
//
//   Widget _buildLoadingState(ThemeData theme) {
//     final colorScheme = theme.colorScheme;
//
//     return ListView.separated(
//       physics: const AlwaysScrollableScrollPhysics(),
//       padding: const EdgeInsets.all(16),
//       itemCount: 5,
//       separatorBuilder: (_, __) => const SizedBox(height: 8),
//       itemBuilder: (_, __) {
//         return Container(
//           height: 82,
//           decoration: BoxDecoration(
//             color: colorScheme.surface,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(
//               color: colorScheme.outline.withValues(
//                 alpha: 0.18,
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   // ===========================================================================
//   // EMPTY STATE
//   // ===========================================================================
//
//   Widget _buildEmptyState(ThemeData theme) {
//     final colorScheme = theme.colorScheme;
//
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             _emptyIcon(
//               theme,
//               Icons.local_parking_rounded,
//             ),
//             const SizedBox(height: 14),
//             Text(
//               'No Active Vehicles',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w700,
//                 color: colorScheme.onSurface,
//               ),
//             ),
//             const SizedBox(height: 5),
//             Text(
//               'There are currently no vehicles parked.',
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 13,
//                 color: colorScheme.onSurface.withValues(
//                   alpha: 0.6,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ===========================================================================
//   // SEARCH EMPTY STATE
//   // ===========================================================================
//
//   Widget _buildNoSearchResults(ThemeData theme) {
//     final colorScheme = theme.colorScheme;
//
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             _emptyIcon(
//               theme,
//               Icons.search_off_rounded,
//             ),
//             const SizedBox(height: 14),
//             Text(
//               'Vehicle Not Found',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w700,
//                 color: colorScheme.onSurface,
//               ),
//             ),
//             const SizedBox(height: 5),
//             Text(
//               'No active vehicle matches "$_searchQuery".',
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 13,
//                 color: colorScheme.onSurface.withValues(
//                   alpha: 0.6,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ===========================================================================
//   // ERROR STATE
//   // ===========================================================================
//
//   Widget _buildErrorState(
//       ThemeData theme, {
//         String? error,
//       }) {
//     final colorScheme = theme.colorScheme;
//
//     String errorMessage =
//         'Please check your connection and try again.';
//
//     if (error != null) {
//       final lower = error.toLowerCase();
//
//       if (lower.contains('index') ||
//           lower.contains('failed-precondition')) {
//         errorMessage =
//         'Firestore requires an index for this query.\n'
//             'Check the Debug Console for the Firebase index link.';
//       } else if (lower.contains('permission-denied')) {
//         errorMessage =
//         'Firestore permission denied.\n'
//             'Check your Firestore security rules.';
//       } else if (lower.contains('unauthenticated')) {
//         errorMessage =
//         'You are not authenticated with Firebase.';
//       } else if (lower.contains('network')) {
//         errorMessage =
//         'Network connection failed.\n'
//             'Please check your internet connection.';
//       }
//     }
//
//     return Center(
//       child: SingleChildScrollView(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             _emptyIcon(
//               theme,
//               Icons.error_outline_rounded,
//             ),
//             const SizedBox(height: 14),
//             Text(
//               'Unable to Load Vehicles',
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w700,
//                 color: colorScheme.onSurface,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               errorMessage,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 13,
//                 color: colorScheme.onSurface.withValues(
//                   alpha: 0.6,
//                 ),
//                 height: 1.4,
//               ),
//             ),
//             const SizedBox(height: 16),
//             OutlinedButton.icon(
//               onPressed: () {
//                 if (mounted) {
//                   setState(() {});
//                 }
//               },
//               icon: const Icon(Icons.refresh_rounded),
//               label: const Text('Try Again'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ===========================================================================
//   // EMPTY ICON
//   // ===========================================================================
//
//   Widget _emptyIcon(
//       ThemeData theme,
//       IconData icon,
//       ) {
//     final colorScheme = theme.colorScheme;
//
//     return Container(
//       width: 64,
//       height: 64,
//       decoration: BoxDecoration(
//         color: colorScheme.surfaceContainerHighest,
//         borderRadius: BorderRadius.circular(18),
//       ),
//       child: Icon(
//         icon,
//         size: 30,
//         color: colorScheme.onSurface.withValues(
//           alpha: 0.55,
//         ),
//       ),
//     );
//   }
//
//   // ===========================================================================
//   // VEHICLE DETAILS
//   // ===========================================================================
//
//   void _showVehicleDetails(
//       BuildContext context,
//       Map<String, dynamic> data,
//       ) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       useSafeArea: true,
//       backgroundColor: Colors.transparent,
//       builder: (sheetContext) {
//         return _VehicleDetailsSheet(
//           data: data,
//         );
//       },
//     );
//   }
// }
//
// // =============================================================================
// // ACTIVE VEHICLE ROW
// // =============================================================================
//
// class _ActiveVehicleRow extends StatefulWidget {
//   final Map<String, dynamic> data;
//   final VoidCallback onDetails;
//
//   const _ActiveVehicleRow({
//     super.key,
//     required this.data,
//     required this.onDetails,
//   });
//
//   @override
//   State<_ActiveVehicleRow> createState() =>
//       _ActiveVehicleRowState();
// }
//
// class _ActiveVehicleRowState extends State<_ActiveVehicleRow> {
//   Timer? _timer;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _timer = Timer.periodic(
//       const Duration(seconds: 30),
//           (_) {
//         if (mounted) {
//           setState(() {});
//         }
//       },
//     );
//   }
//
//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }
//
//   DateTime? _parseTimestamp(dynamic value) {
//     if (value is Timestamp) {
//       return value.toDate();
//     }
//
//     if (value is DateTime) {
//       return value;
//     }
//
//     return null;
//   }
//
//   String _formatDuration(DateTime? startTime) {
//     if (startTime == null) return '--';
//
//     var difference =
//     DateTime.now().difference(startTime);
//
//     if (difference.isNegative) {
//       difference = Duration.zero;
//     }
//
//     final days = difference.inDays;
//     final hours = difference.inHours % 24;
//     final minutes = difference.inMinutes % 60;
//
//     if (days > 0) {
//       return '${days}d ${hours}h';
//     }
//
//     if (hours > 0) {
//       return '${hours}h ${minutes}m';
//     }
//
//     return '${minutes}m';
//   }
//
//   String _capitalize(String value) {
//     if (value.isEmpty) return '--';
//
//     return value[0].toUpperCase() +
//         value.substring(1);
//   }
//
//   bool _isLongStay(DateTime? startTime) {
//     if (startTime == null) return false;
//
//     return DateTime.now()
//         .difference(startTime)
//         .inHours >=
//         4;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;
//
//     final data = widget.data;
//
//     final startTime = _parseTimestamp(
//       data['startTime'],
//     );
//
//     final vehicleNumber =
//     (data['vehicleNumber'] ?? '--')
//         .toString()
//         .toUpperCase();
//
//     final category = _capitalize(
//       (data['vehicleCategory'] ?? '').toString(),
//     );
//
//     final location =
//     (data['locationName'] ??
//         'Unknown location')
//         .toString();
//
//     final duration =
//     _formatDuration(startTime);
//
//     final isLongStay =
//     _isLongStay(startTime);
//
//     final borderColor = isLongStay
//         ? theme.brightness == Brightness.dark
//         ? const Color(0xFF8A6200)
//         : const Color(0xFFFDE68A)
//         : colorScheme.outline.withValues(
//       alpha: 0.18,
//     );
//
//     final timerColor = isLongStay
//         ? theme.brightness == Brightness.dark
//         ? const Color(0xFFFFB74D)
//         : const Color(0xFFB45309)
//         : theme.brightness == Brightness.dark
//         ? colorScheme.primary
//         : const Color(0xFF1D4ED8);
//
//     return ConstrainedBox(
//       constraints: const BoxConstraints(
//         minHeight: 78,
//       ),
//       child: Container(
//         decoration: BoxDecoration(
//           color: colorScheme.surface,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(
//             color: borderColor,
//           ),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(
//             horizontal: 12,
//             vertical: 10,
//           ),
//           child: Row(
//             children: [
//               // ------------------------------------------------------------
//               // CAR ICON
//               // ------------------------------------------------------------
//
//               Container(
//                 width: 44,
//                 height: 44,
//                 decoration: BoxDecoration(
//                   color:
//                   theme.brightness ==
//                       Brightness.dark
//                       ? const Color(0xFF172554)
//                       : const Color(0xFFEFF6FF),
//                   borderRadius:
//                   BorderRadius.circular(10),
//                 ),
//                 child: Icon(
//                   Icons.directions_car_rounded,
//                   size: 23,
//                   color:
//                   theme.brightness ==
//                       Brightness.dark
//                       ? const Color(0xFF60A5FA)
//                       : const Color(0xFF2563EB),
//                 ),
//               ),
//
//               const SizedBox(width: 11),
//
//               // ------------------------------------------------------------
//               // VEHICLE INFORMATION
//               // ------------------------------------------------------------
//
//               Expanded(
//                 child: Column(
//                   mainAxisAlignment:
//                   MainAxisAlignment.center,
//                   crossAxisAlignment:
//                   CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       vehicleNumber,
//                       maxLines: 1,
//                       overflow:
//                       TextOverflow.ellipsis,
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight:
//                         FontWeight.w800,
//                         letterSpacing: .3,
//                         color:
//                         colorScheme.onSurface,
//                       ),
//                     ),
//
//                     const SizedBox(height: 3),
//
//                     Row(
//                       children: [
//                         Flexible(
//                           child: Text(
//                             category,
//                             maxLines: 1,
//                             overflow:
//                             TextOverflow.ellipsis,
//                             style: TextStyle(
//                               fontSize: 11.5,
//                               color: colorScheme
//                                   .onSurface
//                                   .withValues(
//                                 alpha: 0.6,
//                               ),
//                               fontWeight:
//                               FontWeight.w500,
//                             ),
//                           ),
//                         ),
//
//                         Padding(
//                           padding:
//                           const EdgeInsets
//                               .symmetric(
//                             horizontal: 5,
//                           ),
//                           child: Text(
//                             '•',
//                             style: TextStyle(
//                               color: colorScheme
//                                   .onSurface
//                                   .withValues(
//                                 alpha: 0.25,
//                               ),
//                             ),
//                           ),
//                         ),
//
//                         Flexible(
//                           child: Text(
//                             location,
//                             maxLines: 1,
//                             overflow:
//                             TextOverflow.ellipsis,
//                             style: TextStyle(
//                               fontSize: 11.5,
//                               color: colorScheme
//                                   .onSurface
//                                   .withValues(
//                                 alpha: 0.6,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//
//               const SizedBox(width: 8),
//
//               // ------------------------------------------------------------
//               // DURATION + DETAILS
//               // ------------------------------------------------------------
//
//               Column(
//                 mainAxisAlignment:
//                 MainAxisAlignment.center,
//                 crossAxisAlignment:
//                 CrossAxisAlignment.end,
//                 children: [
//                   Row(
//                     mainAxisSize:
//                     MainAxisSize.min,
//                     children: [
//                       Icon(
//                         Icons.timer_outlined,
//                         size: 15,
//                         color: timerColor,
//                       ),
//                       const SizedBox(width: 4),
//                       Text(
//                         duration,
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontWeight:
//                           FontWeight.w800,
//                           color: timerColor,
//                         ),
//                       ),
//                     ],
//                   ),
//
//                   const SizedBox(height: 4),
//
//                   SizedBox(
//                     height: 28,
//                     child: TextButton(
//                       onPressed:
//                       widget.onDetails,
//                       style:
//                       TextButton.styleFrom(
//                         padding:
//                         const EdgeInsets
//                             .symmetric(
//                           horizontal: 7,
//                         ),
//                         minimumSize: Size.zero,
//                         tapTargetSize:
//                         MaterialTapTargetSize
//                             .shrinkWrap,
//                       ),
//                       child: const Text(
//                         'Details',
//                         style: TextStyle(
//                           fontSize: 11.5,
//                           fontWeight:
//                           FontWeight.w700,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // =============================================================================
// // VEHICLE DETAILS SHEET
// // =============================================================================
//
// class _VehicleDetailsSheet extends StatelessWidget {
//   final Map<String, dynamic> data;
//
//   const _VehicleDetailsSheet({
//     required this.data,
//   });
//
//   DateTime? _parseTimestamp(dynamic value) {
//     if (value is Timestamp) {
//       return value.toDate();
//     }
//
//     if (value is DateTime) {
//       return value;
//     }
//
//     return null;
//   }
//
//   String _formatDateTime(DateTime? value) {
//     if (value == null) return '--';
//
//     final hour = value.hour;
//
//     final minute =
//     value.minute.toString().padLeft(2, '0');
//
//     final period = hour >= 12 ? 'PM' : 'AM';
//
//     final displayHour =
//     hour % 12 == 0 ? 12 : hour % 12;
//
//     return '${value.day.toString().padLeft(2, '0')}/'
//         '${value.month.toString().padLeft(2, '0')}/'
//         '${value.year}  '
//         '$displayHour:$minute $period';
//   }
//
//   String _formatDuration(DateTime? startTime) {
//     if (startTime == null) return '--';
//
//     var difference =
//     DateTime.now().difference(startTime);
//
//     if (difference.isNegative) {
//       difference = Duration.zero;
//     }
//
//     final days = difference.inDays;
//     final hours = difference.inHours % 24;
//     final minutes = difference.inMinutes % 60;
//
//     if (days > 0) {
//       return '${days}d ${hours}h ${minutes}m';
//     }
//
//     if (hours > 0) {
//       return '${hours}h ${minutes}m';
//     }
//
//     return '${minutes}m';
//   }
//
//   String _value(dynamic value) {
//     if (value == null) return '--';
//
//     final result =
//     value.toString().trim();
//
//     return result.isEmpty ? '--' : result;
//   }
//
//   String _capitalize(String value) {
//     if (value.isEmpty) return '--';
//
//     return value[0].toUpperCase() +
//         value.substring(1);
//   }
//
//   String _formatCharges(dynamic value) {
//     if (value == null) {
//       return 'Rs. 0';
//     }
//
//     if (value is num) {
//       return 'Rs. ${value.toStringAsFixed(0)}';
//     }
//
//     final result =
//     value.toString().trim();
//
//     if (result.isEmpty) {
//       return 'Rs. 0';
//     }
//
//     return 'Rs. $result';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;
//
//     final startTime =
//     _parseTimestamp(data['startTime']);
//
//     final vehicleNumber =
//     (data['vehicleNumber'] ?? '--')
//         .toString()
//         .toUpperCase();
//
//     final category = _capitalize(
//       (data['vehicleCategory'] ?? '')
//           .toString(),
//     );
//
//     final location =
//     _value(data['locationName']);
//
//     final ticketNumber =
//     _value(data['ticketNumber']);
//
//     final driverName =
//     _value(data['driverName']);
//
//     final phoneNumber =
//     _value(data['phoneNumber']);
//
//     final notes =
//     _value(data['notes']);
//
//     final date =
//     _value(data['date']);
//
//     final status = _capitalize(
//       (data['status'] ?? '').toString(),
//     );
//
//     final charges =
//     _formatCharges(
//       data['parkingCharges'],
//     );
//
//     // IMPORTANT:
//     // The FractionallySizedBox gives the Column a real/bounded height.
//     // This makes the Expanded below safe.
//     return FractionallySizedBox(
//       heightFactor: 0.90,
//       child: Material(
//         color: colorScheme.surface,
//         borderRadius:
//         const BorderRadius.vertical(
//           top: Radius.circular(22),
//         ),
//         clipBehavior: Clip.antiAlias,
//         child: SafeArea(
//           top: false,
//           child: Column(
//             children: [
//               const SizedBox(height: 8),
//
//               // ------------------------------------------------------------
//               // HANDLE
//               // ------------------------------------------------------------
//
//               Container(
//                 width: 38,
//                 height: 4,
//                 decoration: BoxDecoration(
//                   color: colorScheme.onSurface
//                       .withValues(alpha: 0.18),
//                   borderRadius:
//                   BorderRadius.circular(10),
//                 ),
//               ),
//
//               // ------------------------------------------------------------
//               // HEADER
//               // ------------------------------------------------------------
//
//               Padding(
//                 padding:
//                 const EdgeInsets.fromLTRB(
//                   18,
//                   14,
//                   10,
//                   12,
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 44,
//                       height: 44,
//                       decoration:
//                       BoxDecoration(
//                         color:
//                         theme.brightness ==
//                             Brightness.dark
//                             ? const Color(
//                           0xFF172554,
//                         )
//                             : const Color(
//                           0xFFEFF6FF,
//                         ),
//                         borderRadius:
//                         BorderRadius.circular(
//                           11,
//                         ),
//                       ),
//                       child: Icon(
//                         Icons
//                             .directions_car_rounded,
//                         color:
//                         theme.brightness ==
//                             Brightness.dark
//                             ? const Color(
//                           0xFF60A5FA,
//                         )
//                             : const Color(
//                           0xFF2563EB,
//                         ),
//                       ),
//                     ),
//
//                     const SizedBox(width: 11),
//
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment:
//                         CrossAxisAlignment
//                             .start,
//                         children: [
//                           Text(
//                             'Vehicle Details',
//                             style: TextStyle(
//                               fontSize: 12,
//                               color: colorScheme
//                                   .onSurface
//                                   .withValues(
//                                 alpha: 0.6,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(
//                             height: 2,
//                           ),
//                           Text(
//                             vehicleNumber,
//                             maxLines: 1,
//                             overflow:
//                             TextOverflow
//                                 .ellipsis,
//                             style: TextStyle(
//                               fontSize: 20,
//                               fontWeight:
//                               FontWeight.w800,
//                               color: colorScheme
//                                   .onSurface,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//
//                     IconButton(
//                       onPressed: () =>
//                           Navigator.pop(
//                             context,
//                           ),
//                       icon: Icon(
//                         Icons.close_rounded,
//                         color: colorScheme
//                             .onSurface,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               Divider(
//                 height: 1,
//                 color: colorScheme.outline
//                     .withValues(
//                   alpha: 0.15,
//                 ),
//               ),
//
//               // ------------------------------------------------------------
//               // SCROLLABLE CONTENT
//               // ------------------------------------------------------------
//
//               Expanded(
//                 child: SingleChildScrollView(
//                   physics:
//                   const ClampingScrollPhysics(),
//                   padding:
//                   const EdgeInsets.fromLTRB(
//                     18,
//                     14,
//                     18,
//                     24,
//                   ),
//                   child: Column(
//                     crossAxisAlignment:
//                     CrossAxisAlignment
//                         .stretch,
//                     children: [
//                       _durationBox(
//                         context,
//                         duration:
//                         _formatDuration(
//                           startTime,
//                         ),
//                         startTime:
//                         _formatDateTime(
//                           startTime,
//                         ),
//                       ),
//
//                       const SizedBox(
//                         height: 14,
//                       ),
//
//                       _sectionTitle(
//                         context,
//                         'Vehicle',
//                       ),
//
//                       _detailsGrid(
//                         context,
//                         [
//                           _detailItem(
//                             context,
//                             Icons
//                                 .confirmation_number_outlined,
//                             'Vehicle Number',
//                             vehicleNumber,
//                           ),
//                           _detailItem(
//                             context,
//                             Icons
//                                 .category_outlined,
//                             'Category',
//                             category,
//                           ),
//                           _detailItem(
//                             context,
//                             Icons
//                                 .location_on_outlined,
//                             'Location',
//                             location,
//                           ),
//                           _detailItem(
//                             context,
//                             Icons
//                                 .verified_outlined,
//                             'Status',
//                             status,
//                           ),
//                         ],
//                       ),
//
//                       const SizedBox(
//                         height: 14,
//                       ),
//
//                       _sectionTitle(
//                         context,
//                         'Parking',
//                       ),
//
//                       _detailsGrid(
//                         context,
//                         [
//                           _detailItem(
//                             context,
//                             Icons
//                                 .receipt_long_outlined,
//                             'Ticket',
//                             ticketNumber,
//                           ),
//                           _detailItem(
//                             context,
//                             Icons
//                                 .payments_outlined,
//                             'Parking Charges',
//                             charges,
//                           ),
//                           _detailItem(
//                             context,
//                             Icons
//                                 .calendar_today_outlined,
//                             'Date',
//                             date,
//                           ),
//                           _detailItem(
//                             context,
//                             Icons.login_outlined,
//                             'Start Time',
//                             _formatDateTime(
//                               startTime,
//                             ),
//                           ),
//                         ],
//                       ),
//
//                       const SizedBox(
//                         height: 14,
//                       ),
//
//                       _sectionTitle(
//                         context,
//                         'Driver',
//                       ),
//
//                       _detailsGrid(
//                         context,
//                         [
//                           _detailItem(
//                             context,
//                             Icons
//                                 .person_outline_rounded,
//                             'Driver',
//                             driverName,
//                           ),
//                           _detailItem(
//                             context,
//                             Icons
//                                 .phone_outlined,
//                             'Phone',
//                             phoneNumber,
//                           ),
//                         ],
//                       ),
//
//                       if (notes != '--') ...[
//                         const SizedBox(
//                           height: 14,
//                         ),
//
//                         _sectionTitle(
//                           context,
//                           'Notes',
//                         ),
//
//                         Container(
//                           width: double.infinity,
//                           padding:
//                           const EdgeInsets
//                               .all(12),
//                           decoration:
//                           BoxDecoration(
//                             color: colorScheme
//                                 .surfaceContainerHighest,
//                             borderRadius:
//                             BorderRadius
//                                 .circular(
//                               10,
//                             ),
//                           ),
//                           child: Row(
//                             crossAxisAlignment:
//                             CrossAxisAlignment
//                                 .start,
//                             children: [
//                               Icon(
//                                 Icons.notes_rounded,
//                                 size: 18,
//                                 color: colorScheme
//                                     .onSurface
//                                     .withValues(
//                                   alpha: 0.55,
//                                 ),
//                               ),
//                               const SizedBox(
//                                 width: 9,
//                               ),
//                               Expanded(
//                                 child: Text(
//                                   notes,
//                                   style: TextStyle(
//                                     fontSize: 13,
//                                     color: colorScheme
//                                         .onSurface
//                                         .withValues(
//                                       alpha: 0.8,
//                                     ),
//                                     height: 1.4,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ===========================================================================
//   // DURATION BOX
//   // ===========================================================================
//
//   Widget _durationBox(
//       BuildContext context, {
//         required String duration,
//         required String startTime,
//       }) {
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;
//
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(13),
//       decoration: BoxDecoration(
//         color:
//         colorScheme.surfaceContainerHighest,
//         borderRadius:
//         BorderRadius.circular(11),
//         border: Border.all(
//           color: colorScheme.outline
//               .withValues(alpha: 0.18),
//         ),
//       ),
//       child: Row(
//         children: [
//           Icon(
//             Icons.timer_outlined,
//             size: 21,
//             color:
//             theme.brightness ==
//                 Brightness.dark
//                 ? colorScheme.primary
//                 : const Color(0xFF2563EB),
//           ),
//
//           const SizedBox(width: 10),
//
//           Expanded(
//             child: Column(
//               crossAxisAlignment:
//               CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'PARKED FOR',
//                   style: TextStyle(
//                     fontSize: 9,
//                     fontWeight:
//                     FontWeight.w800,
//                     letterSpacing: .7,
//                     color: colorScheme
//                         .onSurface
//                         .withValues(
//                       alpha: 0.5,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   duration,
//                   style: TextStyle(
//                     fontSize: 17,
//                     fontWeight:
//                     FontWeight.w800,
//                     color:
//                     colorScheme.onSurface,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           const SizedBox(width: 10),
//
//           Flexible(
//             child: Column(
//               crossAxisAlignment:
//               CrossAxisAlignment.end,
//               children: [
//                 Text(
//                   'STARTED',
//                   style: TextStyle(
//                     fontSize: 9,
//                     fontWeight:
//                     FontWeight.w800,
//                     letterSpacing: .7,
//                     color: colorScheme
//                         .onSurface
//                         .withValues(
//                       alpha: 0.5,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   startTime,
//                   textAlign: TextAlign.end,
//                   maxLines: 2,
//                   overflow:
//                   TextOverflow.ellipsis,
//                   style: TextStyle(
//                     fontSize: 11.5,
//                     fontWeight:
//                     FontWeight.w700,
//                     color: colorScheme
//                         .onSurface
//                         .withValues(
//                       alpha: 0.75,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ===========================================================================
//   // SECTION TITLE
//   // ===========================================================================
//
//   Widget _sectionTitle(
//       BuildContext context,
//       String title,
//       ) {
//     final colorScheme =
//         Theme.of(context).colorScheme;
//
//     return Padding(
//       padding:
//       const EdgeInsets.only(bottom: 8),
//       child: Text(
//         title,
//         style: TextStyle(
//           fontSize: 12,
//           fontWeight: FontWeight.w800,
//           color: colorScheme.onSurface
//               .withValues(alpha: 0.75),
//         ),
//       ),
//     );
//   }
//
//   // ===========================================================================
//   // DETAILS GRID
//   // ===========================================================================
//
//   Widget _detailsGrid(
//       BuildContext context,
//       List<Widget> items,
//       ) {
//     final colorScheme =
//         Theme.of(context).colorScheme;
//
//     final borderColor =
//     colorScheme.outline.withValues(
//       alpha: 0.18,
//     );
//
//     return Container(
//       decoration: BoxDecoration(
//         border: Border.all(
//           color: borderColor,
//         ),
//         borderRadius:
//         BorderRadius.circular(11),
//       ),
//       child: Column(
//         children: [
//           for (int i = 0;
//           i < items.length;
//           i += 2)
//             _detailsGridRow(
//               context,
//               items,
//               i,
//               borderColor,
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _detailsGridRow(
//       BuildContext context,
//       List<Widget> items,
//       int index,
//       Color borderColor,
//       ) {
//     final hasSecond =
//         index + 1 < items.length;
//
//     return IntrinsicHeight(
//       child: Row(
//         crossAxisAlignment:
//         CrossAxisAlignment.stretch,
//         children: [
//           Expanded(
//             child: Padding(
//               padding:
//               const EdgeInsets.all(11),
//               child: items[index],
//             ),
//           ),
//
//           Container(
//             width: 1,
//             color: borderColor,
//           ),
//
//           Expanded(
//             child: hasSecond
//                 ? Padding(
//               padding:
//               const EdgeInsets
//                   .all(11),
//               child:
//               items[index + 1],
//             )
//                 : const SizedBox(),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ===========================================================================
//   // DETAIL ITEM
//   // ===========================================================================
//
//   Widget _detailItem(
//       BuildContext context,
//       IconData icon,
//       String label,
//       String value,
//       ) {
//     final colorScheme =
//         Theme.of(context).colorScheme;
//
//     return Row(
//       crossAxisAlignment:
//       CrossAxisAlignment.start,
//       children: [
//         Icon(
//           icon,
//           size: 16,
//           color: colorScheme.onSurface
//               .withValues(alpha: 0.4),
//         ),
//
//         const SizedBox(width: 7),
//
//         Expanded(
//           child: Column(
//             crossAxisAlignment:
//             CrossAxisAlignment.start,
//             children: [
//               Text(
//                 label,
//                 maxLines: 1,
//                 overflow:
//                 TextOverflow.ellipsis,
//                 style: TextStyle(
//                   fontSize: 9.5,
//                   color: colorScheme
//                       .onSurface
//                       .withValues(
//                     alpha: 0.4,
//                   ),
//                   fontWeight:
//                   FontWeight.w700,
//                 ),
//               ),
//
//               const SizedBox(height: 2),
//
//               Text(
//                 value,
//                 maxLines: 2,
//                 overflow:
//                 TextOverflow.ellipsis,
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: colorScheme
//                       .onSurface
//                       .withValues(
//                     alpha: 0.8,
//                   ),
//                   fontWeight:
//                   FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/app_data_cache.dart';

class ActiveVehiclesScreen extends StatefulWidget {
  const ActiveVehiclesScreen({super.key});

  @override
  State<ActiveVehiclesScreen> createState() => _ActiveVehiclesScreenState();
}

class _ActiveVehiclesScreenState extends State<ActiveVehiclesScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedCategory = 'all';

  String? _accountLocationId;
  String? _accountLocationName;
  bool _loadingLocation = true;

  Future<void> _loadAccountLocation() async {
    if (AppDataCache.instance.isLoaded && AppDataCache.instance.locationId != null) {
      if (mounted) {
        setState(() {
          _accountLocationId = AppDataCache.instance.locationId;
          _accountLocationName = AppDataCache.instance.locationName;
          _loadingLocation = false;
        });
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _loadingLocation = false;
      });
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      setState(() {
        _loadingLocation = false;
      });
      return;
    }

    final locationId = userDoc.data()?['location'] as String?;

    if (locationId == null || locationId.isEmpty) {
      setState(() {
        _loadingLocation = false;
      });
      return;
    }

    // Get the location document
    final locationDoc = await FirebaseFirestore.instance
        .collection('locations')
        .doc(locationId)
        .get();

    setState(() {
      _accountLocationId = locationId;
      _accountLocationName =
      locationDoc.data()?['locationName'] as String?;
      _loadingLocation = false;
    });
  }

  Query<Map<String, dynamic>> get _activeVehiclesQuery {
    if (_accountLocationId == null || _accountLocationId!.isEmpty) {
      // Return a query that will not expose other locations.
      return FirebaseFirestore.instance
          .collection('parking_tickets')
          .where('locationId', isEqualTo: '__NO_LOCATION__');
    }

    return FirebaseFirestore.instance
        .collection('parking_tickets')
        .where('status', isEqualTo: 'in')
        .where(
      'locationId',
      isEqualTo: _accountLocationId,
    )
        .orderBy('startTime', descending: true);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    if (AppDataCache.instance.isLoaded && AppDataCache.instance.locationId != null) {
      _accountLocationId = AppDataCache.instance.locationId;
      _accountLocationName = AppDataCache.instance.locationName;
      _loadingLocation = false;
    } else {
      _loadAccountLocation();
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    if (query != _searchQuery && mounted) {
      setState(() {
        _searchQuery = query;
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  String _gateFilter = 'all'; // 'all', 'mine', 'others'

  bool _matchesFilter(Map<String, dynamic> data) {
    final operatorId = AppDataCache.instance.operatorId ??
        FirebaseAuth.instance.currentUser?.uid ?? '';
    final entryOperatorId = (data['entryOperatorId'] ?? data['operatorId'] ?? '')
        .toString();

    if (_gateFilter == 'mine' && entryOperatorId != operatorId) {
      return false;
    }
    if (_gateFilter == 'others' && (entryOperatorId.isEmpty || entryOperatorId == operatorId)) {
      return false;
    }

    final vehicleNumber = (data['vehicleNumber'] ?? '')
        .toString()
        .toLowerCase();

    final category = (data['vehicleCategory'] ?? '').toString().toLowerCase();

    final matchesSearch =
        vehicleNumber.contains(_searchQuery) || category.contains(_searchQuery);

    final matchesCategory =
        _selectedCategory == 'all' || category == _selectedCategory;

    return matchesSearch && matchesCategory;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loadingLocation) {
      return _buildLoadingState(theme);
    }

    return Column(
      children: [
        _buildHeader(theme),

        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _activeVehiclesQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Active Vehicles Error: ${snapshot.error}');

                return _buildErrorState(
                  theme,
                  error: snapshot.error.toString(),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return _buildLoadingState(theme);
              }

              final docs = snapshot.data?.docs ?? [];

              final filteredDocs = docs.where((doc) {
                return _matchesFilter(doc.data());
              }).toList();

              if (filteredDocs.isEmpty) {
                if (_searchQuery.isNotEmpty || _selectedCategory != 'all') {
                  return _buildNoResultsState(theme);
                }

                return _buildEmptyState(theme);
              }

              return Column(
                children: [
                  _buildResultsBar(
                    theme,
                    total: docs.length,
                    visible: filteredDocs.length,
                  ),

                  Expanded(
                    child: RefreshIndicator(
                      color: colorScheme.primary,
                      onRefresh: _refreshVehicles,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final horizontalPadding = constraints.maxWidth >= 1100
                              ? 28.0
                              : 16.0;

                          return ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              4,
                              horizontalPadding,
                              28,
                            ),
                            itemCount: filteredDocs.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];

                              return _ActiveVehicleRow(
                                key: ValueKey(doc.id),
                                data: doc.data(),
                                onDetails: () {
                                  _showVehicleDetails(context, doc.data());
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 800;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Vehicles',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.3,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _accountLocationName != null && _accountLocationName!.isNotEmpty
                              ? 'Vehicles currently parked in $_accountLocationName'
                              : 'Vehicles currently parked in the facility',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  _buildActiveIndicator(theme),
                ],
              ),

              const SizedBox(height: 18),

              if (compact)
                Column(
                  children: [
                    _buildSearchField(theme),
                    const SizedBox(height: 10),
                    _buildCategoryFilters(theme, expanded: true),
                  ],
                )
              else
                Row(
                  children: [
                    SizedBox(width: 360, child: _buildSearchField(theme)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildCategoryFilters(theme, expanded: false),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Widget _buildSearchField(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        textCapitalization: TextCapitalization.characters,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search vehicle number or category...',
          hintStyle: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.45),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: colorScheme.primary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear search',
                  onPressed: _searchController.clear,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                )
              : null,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.65,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.3),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // CATEGORY FILTERS
  // ===========================================================================

  Widget _buildCategoryFilters(ThemeData theme, {required bool expanded}) {
    final categories = [
      ('all', 'All Vehicles', Icons.directions_car_outlined),
      ('self', 'Self', Icons.person_outline_rounded),
      ('bike', 'Bike', Icons.two_wheeler_outlined),
      ('valet', 'Valet', Icons.local_parking_outlined),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: !expanded,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final category = categories[index];

          final selected = _selectedCategory == category.$1;

          return _CategoryFilterButton(
            label: category.$2,
            icon: category.$3,
            selected: selected,
            onPressed: () {
              setState(() {
                _selectedCategory = category.$1;
              });
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // ACTIVE INDICATOR
  // ===========================================================================

  Widget _buildActiveIndicator(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _activeVehiclesQuery.snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;

        return Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.16 : 0.08,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Active',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // RESULTS BAR
  // ===========================================================================

  Widget _buildResultsBar(
    ThemeData theme, {
    required int total,
    required int visible,
  }) {
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.list_alt_rounded,
                size: 17,
                color: colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 7),
              Text(
                visible == total
                    ? '$total vehicles'
                    : '$visible of $total vehicles',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGateFilterChip('all', 'All Facility', colorScheme),
              const SizedBox(width: 6),
              _buildGateFilterChip('mine', 'Entered by Me', colorScheme),
              const SizedBox(width: 6),
              _buildGateFilterChip('others', 'Other Gates', colorScheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGateFilterChip(String value, String label, ColorScheme colorScheme) {
    final selected = _gateFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _gateFilter = value;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected
                ? colorScheme.onPrimary
                : colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  Future<void> _refreshVehicles() async {
    try {
      await _activeVehiclesQuery.get(const GetOptions(source: Source.server));
    } catch (e) {
      debugPrint('Refresh error: $e');
    }
  }

  // ===========================================================================
  // LOADING
  // ===========================================================================

  Widget _buildLoadingState(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      itemCount: 6,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Container(
          height: 82,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // EMPTY
  // ===========================================================================

  Widget _buildEmptyState(ThemeData theme) {
    return _CenteredState(
      theme: theme,
      icon: Icons.local_parking_rounded,
      title: 'No Active Vehicles',
      message: 'There are currently no vehicles parked.',
    );
  }

  // ===========================================================================
  // NO SEARCH RESULTS
  // ===========================================================================

  Widget _buildNoResultsState(ThemeData theme) {
    final category = _selectedCategory == 'all'
        ? ''
        : ' in ${_selectedCategory.toUpperCase()}';

    return _CenteredState(
      theme: theme,
      icon: Icons.search_off_rounded,
      title: 'No Vehicles Found',
      message: _searchQuery.isNotEmpty
          ? 'No active vehicles match "$_searchQuery"$category.'
          : 'No active vehicles found for this category.',
      action: TextButton.icon(
        onPressed: () {
          setState(() {
            _searchController.clear();
            _selectedCategory = 'all';
          });
        },
        icon: const Icon(Icons.clear_all_rounded),
        label: const Text('Clear Filters'),
      ),
    );
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  Widget _buildErrorState(ThemeData theme, {String? error}) {
    String errorMessage = 'Please check your connection and try again.';

    if (error != null) {
      final lower = error.toLowerCase();

      if (lower.contains('index') || lower.contains('failed-precondition')) {
        errorMessage = 'Firestore requires an index for this query.';
      } else if (lower.contains('permission-denied')) {
        errorMessage =
            'Firestore permission denied. Check your security rules.';
      } else if (lower.contains('unauthenticated')) {
        errorMessage = 'You are not authenticated with Firebase.';
      } else if (lower.contains('network')) {
        errorMessage =
            'Network connection failed. Check your internet connection.';
      }
    }

    return _CenteredState(
      theme: theme,
      icon: Icons.error_outline_rounded,
      title: 'Unable to Load Vehicles',
      message: errorMessage,
      action: OutlinedButton.icon(
        onPressed: () {
          if (mounted) {
            setState(() {});
          }
        },
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Try Again'),
      ),
    );
  }

  // ===========================================================================
  // DETAILS
  // ===========================================================================

  void _showVehicleDetails(BuildContext context, Map<String, dynamic> data) {
    final width = MediaQuery.sizeOf(context).width;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: width > 900 ? 100 : 24,
            vertical: 32,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
            child: _VehicleDetailsContent(data: data),
          ),
        );
      },
    );
  }
}

// =============================================================================
// CATEGORY BUTTON
// =============================================================================

class _CategoryFilterButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _CategoryFilterButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  @override
  State<_CategoryFilterButton> createState() => _CategoryFilterButtonState();
}

class _CategoryFilterButtonState extends State<_CategoryFilterButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final background = widget.selected
        ? colorScheme.primary
        : _hovering
        ? colorScheme.surfaceContainerHighest
        : Colors.transparent;

    final foreground = widget.selected
        ? colorScheme.onPrimary
        : colorScheme.onSurface.withValues(alpha: 0.68);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovering = true);
      },
      onExit: (_) {
        setState(() => _hovering = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: widget.selected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 16, color: foreground),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ACTIVE VEHICLE ROW
// =============================================================================

class _ActiveVehicleRow extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDetails;

  const _ActiveVehicleRow({
    super.key,
    required this.data,
    required this.onDetails,
  });

  @override
  State<_ActiveVehicleRow> createState() => _ActiveVehicleRowState();
}

class _ActiveVehicleRowState extends State<_ActiveVehicleRow> {
  Timer? _timer;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatDuration(DateTime? startTime) {
    if (startTime == null) return '--';

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

  String _capitalize(String value) {
    if (value.isEmpty) return '--';

    return value[0].toUpperCase() + value.substring(1);
  }

  bool _isLongStay(DateTime? startTime) {
    if (startTime == null) return false;

    return DateTime.now().difference(startTime).inHours >= 4;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final data = widget.data;

    final startTime = _parseTimestamp(data['startTime']);

    final vehicleNumber = (data['vehicleNumber'] ?? '--')
        .toString()
        .toUpperCase();

    final category = (data['vehicleCategory'] ?? 'self')
        .toString()
        .toLowerCase();

    final categoryLabel = _capitalize(category);

    final location = (data['locationName'] ?? 'Unknown location').toString();

    final duration = _formatDuration(startTime);

    final isLongStay = _isLongStay(startTime);

    final borderColor = isLongStay
        ? colorScheme.primary.withValues(alpha: 0.35)
        : colorScheme.outline.withValues(alpha: 0.14);

    final entryOpId = (data['entryOperatorId'] ?? data['operatorId'] ?? '').toString();
    final entryOpName = (data['entryOperatorName'] ?? '').toString();
    final myOpId = AppDataCache.instance.operatorId ??
        FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMine = entryOpId.isNotEmpty && entryOpId == myOpId;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) {
        setState(() => _hovering = true);
      },
      onExit: (_) {
        setState(() => _hovering = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        constraints: const BoxConstraints(minHeight: 76),
        decoration: BoxDecoration(
          color: _hovering
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.12 : 0.035,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // ------------------------------------------------------------
              // VEHICLE ICON
              // ------------------------------------------------------------
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _categoryIcon(category),
                  size: 22,
                  color: colorScheme.primary,
                ),
              ),

              const SizedBox(width: 12),

              // ------------------------------------------------------------
              // VEHICLE
              // ------------------------------------------------------------
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      vehicleNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .35,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _CategoryBadge(category: categoryLabel),
                        const SizedBox(width: 6),
                        _OperatorBadge(isMine: isMine, operatorName: entryOpName),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.42,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
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

              const SizedBox(width: 20),

              // ------------------------------------------------------------
              // DURATION
              // ------------------------------------------------------------
              Container(
                constraints: const BoxConstraints(minWidth: 105),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isLongStay
                      ? colorScheme.primary.withValues(alpha: 0.10)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PARKED FOR',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .65,
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 2),
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
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // ------------------------------------------------------------
              // DETAILS
              // ------------------------------------------------------------
              SizedBox(
                height: 34,
                child: OutlinedButton(
                  onPressed: widget.onDetails,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CATEGORY BADGE
// =============================================================================

class _CategoryBadge extends StatelessWidget {
  final String category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OperatorBadge extends StatelessWidget {
  final bool isMine;
  final String operatorName;

  const _OperatorBadge({required this.isMine, required this.operatorName});

  @override
  Widget build(BuildContext context) {
    final color = isMine ? const Color(0xFF2E7D32) : const Color(0xFF1565C0);
    final bg = isMine ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMine ? Icons.person_rounded : Icons.door_sliding_outlined,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            isMine ? 'Entered by you' : (operatorName.isNotEmpty ? 'Gate: $operatorName' : 'Other Gate'),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CENTERED STATE
// =============================================================================

class _CenteredState extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _CenteredState({
    required this.theme,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 30, color: colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// VEHICLE DETAILS CONTENT
// =============================================================================

class _VehicleDetailsContent extends StatelessWidget {
  final Map<String, dynamic> data;

  const _VehicleDetailsContent({required this.data});

  DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '--';

    final hour = value.hour;
    final minute = value.minute.toString().padLeft(2, '0');

    final period = hour >= 12 ? 'PM' : 'AM';

    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year} '
        '$displayHour:$minute $period';
  }

  String _formatDuration(DateTime? startTime) {
    if (startTime == null) return '--';

    var difference = DateTime.now().difference(startTime);

    if (difference.isNegative) {
      difference = Duration.zero;
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    }

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes}m';
  }

  String _value(dynamic value) {
    if (value == null) return '--';

    final result = value.toString().trim();

    return result.isEmpty ? '--' : result;
  }

  String _capitalize(String value) {
    if (value.isEmpty) return '--';

    return value[0].toUpperCase() + value.substring(1);
  }

  String _formatCharges(dynamic value) {
    if (value == null) {
      return 'Rs. 0';
    }

    if (value is num) {
      return 'Rs. ${value.toStringAsFixed(0)}';
    }

    final result = value.toString().trim();

    if (result.isEmpty) {
      return 'Rs. 0';
    }

    return 'Rs. $result';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final startTime = _parseTimestamp(data['startTime']);

    final vehicleNumber = (data['vehicleNumber'] ?? '--')
        .toString()
        .toUpperCase();

    final category = _capitalize((data['vehicleCategory'] ?? '').toString());

    final location = _value(data['locationName']);

    final ticketNumber = _value(data['ticketNumber']);

    final driverName = _value(data['driverName']);

    final phoneNumber = _value(data['phoneNumber']);

    final notes = _value(data['notes']);

    final date = _value(data['date']);

    final status = _capitalize((data['status'] ?? '').toString());

    final charges = _formatCharges(data['parkingCharges']);

    return Column(
      children: [
        // HEADER
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 14, 16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.directions_car_rounded,
                  color: colorScheme.primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle Details',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vehicleNumber,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),

        Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.12)),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDurationCard(
                  context,
                  duration: _formatDuration(startTime),
                  startTime: _formatDateTime(startTime),
                ),

                const SizedBox(height: 20),

                _sectionTitle(context, 'Vehicle'),

                _detailsGrid(context, [
                  _detailItem(
                    context,
                    Icons.confirmation_number_outlined,
                    'Vehicle Number',
                    vehicleNumber,
                  ),
                  _detailItem(
                    context,
                    Icons.category_outlined,
                    'Category',
                    category,
                  ),
                  _detailItem(
                    context,
                    Icons.location_on_outlined,
                    'Location',
                    location,
                  ),
                  _detailItem(
                    context,
                    Icons.verified_outlined,
                    'Status',
                    status,
                  ),
                ]),

                const SizedBox(height: 18),

                _sectionTitle(context, 'Parking'),

                _detailsGrid(context, [
                  _detailItem(
                    context,
                    Icons.receipt_long_outlined,
                    'Ticket',
                    ticketNumber,
                  ),
                  _detailItem(
                    context,
                    Icons.payments_outlined,
                    'Parking Charges',
                    charges,
                  ),
                  _detailItem(
                    context,
                    Icons.calendar_today_outlined,
                    'Date',
                    date,
                  ),
                  _detailItem(
                    context,
                    Icons.login_outlined,
                    'Start Time',
                    _formatDateTime(startTime),
                  ),
                ]),

                const SizedBox(height: 18),

                _sectionTitle(context, 'Driver'),

                _detailsGrid(context, [
                  _detailItem(
                    context,
                    Icons.person_outline_rounded,
                    'Driver',
                    driverName,
                  ),
                  _detailItem(
                    context,
                    Icons.phone_outlined,
                    'Phone',
                    phoneNumber,
                  ),
                ]),

                if (notes != '--') ...[
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Notes'),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      notes,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationCard(
    BuildContext context, {
    required String duration,
    required String startTime,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 22, color: colorScheme.primary),
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
                    color: colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  duration,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'STARTED',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .7,
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                startTime,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _detailsGrid(BuildContext context, List<Widget> items) {
    final colorScheme = Theme.of(context).colorScheme;

    final borderColor = colorScheme.outline.withValues(alpha: 0.15);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i += 2)
            _detailsGridRow(context, items, i, borderColor),
        ],
      ),
    );
  }

  Widget _detailsGridRow(
    BuildContext context,
    List<Widget> items,
    int index,
    Color borderColor,
  ) {
    final hasSecond = index + 1 < items.length;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: items[index],
            ),
          ),
          Container(width: 1, color: borderColor),
          Expanded(
            child: hasSecond
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: items[index + 1],
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _detailItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: colorScheme.primary.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
