import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../resources/widget/app_toast.dart';
import 'add_operator_admin.dart';

class OperatorList extends StatefulWidget {
  const OperatorList({super.key, required this.onAddOperator});

  final VoidCallback onAddOperator;

  @override
  State<OperatorList> createState() => _OperatorListState();
}

class _OperatorListState extends State<OperatorList> {
  static const String _operatorRole = 'operator';

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  final Map<String, Map<String, dynamic>?> _locationCache = {};

  final Map<String, Future<Map<String, dynamic>?>> _locationRequests = {};

  Widget _buildLocationLoadingCard(
      BuildContext context, {
        required String operatorName,
        required bool disabled,
      }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          operatorName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: disabled
                ? colors.onSurfaceVariant
                : colors.onSurface,
          ),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),

            const SizedBox(width: 8),

            Text(
              'Loading location...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }



  Future<Map<String, dynamic>?> _getLocation(String locationId) {
    // Already cached
    if (_locationCache.containsKey(locationId)) {
      return Future.value(_locationCache[locationId]);
    }

    // Already being requested
    final existingRequest = _locationRequests[locationId];

    if (existingRequest != null) {
      return existingRequest;
    }

    // Fetch from Firestore
    final request = FirebaseFirestore.instance
        .collection('locations')
        .doc(locationId)
        .get()
        .then((snapshot) {
      final data = snapshot.exists ? snapshot.data() : null;

      // Save in cache
      _locationCache[locationId] = data;

      // Remove completed request
      _locationRequests.remove(locationId);

      return data;
    })
        .catchError((error) {
      // Remove failed request so it can be retried later
      _locationRequests.remove(locationId);

      throw error;
    });

    _locationRequests[locationId] = request;

    return request;
  }

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),

              const SizedBox(height: 24),

              _buildSearchBar(context),

              const SizedBox(height: 20),

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: _operatorRole)
                      .snapshots(),

                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState(context);
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState(context);
                    }

                    final documents = snapshot.data?.docs ?? [];

                    final filteredDocuments = documents.where((document) {
                      final data = document.data();

                      final firstName = (data['firstName'] ?? '')
                          .toString()
                          .toLowerCase();

                      final lastName = (data['lastName'] ?? '')
                          .toString()
                          .toLowerCase();

                      final email = (data['email'] ?? '')
                          .toString()
                          .toLowerCase();

                      final location = (data['location'] ?? '')
                          .toString()
                          .toLowerCase();

                      final fullName = '$firstName $lastName';

                      return fullName.contains(_searchQuery) ||
                          firstName.contains(_searchQuery) ||
                          lastName.contains(_searchQuery) ||
                          email.contains(_searchQuery) ||
                          location.contains(_searchQuery);
                    }).toList();

                    if (documents.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    if (filteredDocuments.isEmpty) {
                      return _buildNoSearchResults(context);
                    }

                    return _buildOperatorContent(
                      context,
                      documents: filteredDocuments,
                      totalOperators: documents.length,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // HEADER
  // ================================================================

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.manage_accounts_rounded,
                      color: colors.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Operators',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                'Manage the people who operate your parking locations.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        FilledButton.icon(
          onPressed: widget.onAddOperator,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Add Operator'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ],
    );
  }

  // ================================================================
  // SEARCH
  // ================================================================

  Widget _buildSearchBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by operator, email, or location...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded),
                onPressed: _searchController.clear,
              )
            : null,
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
    );
  }

  // ================================================================
  // OPERATOR CONTENT
  // ================================================================

  Widget _buildOperatorContent(
    BuildContext context, {
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
    required int totalOperators,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Operator Accounts',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(width: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$totalOperators',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Expanded(
          child: ListView.separated(
            itemCount: documents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildOperatorCard(context, documents[index]);
            },
          ),
        ),
      ],
    );
  }

  // ================================================================
  // OPERATOR CARD
  //
  // IMPORTANT:
  // The card now shows:
  //
  //   Emmar Reef
  //   Rs. 500
  //   Active
  //
  // It does NOT show:
  //   - operator name
  //   - email
  //   - address
  //   - location ID
  //   - grace time
  //   - created date
  //
  // Those are available under "View information".
  // ================================================================

  Widget _buildOperatorCard(
      BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final data = document.data();

    final firstName = (data['firstName'] ?? '').toString().trim();
    final lastName = (data['lastName'] ?? '').toString().trim();

    final operatorName = [
      firstName,
      lastName,
    ].where((name) => name.isNotEmpty).join(' ');

    final displayOperatorName = operatorName.isEmpty
        ? 'Unknown Operator'
        : operatorName;

    final locationId = (data['location'] ?? '').toString().trim();

    final isDisabled = data['disabled'] == true;

    final initials = _getInitials(
      firstName: firstName,
      lastName: lastName,
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colors.outlineVariant.withOpacity(0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // --------------------------------------------------------
            // OPERATOR AVATAR
            // --------------------------------------------------------
            CircleAvatar(
              radius: 28,
              backgroundColor: isDisabled
                  ? colors.surfaceContainerHighest
                  : colors.primaryContainer,
              child: Text(
                initials,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isDisabled
                      ? colors.onSurfaceVariant
                      : colors.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            const SizedBox(width: 16),

            // --------------------------------------------------------
            // OPERATOR INFORMATION
            //
            // Main title = Operator Name
            // Secondary information = Location + Parking
            // --------------------------------------------------------
            Expanded(
              child: locationId.isEmpty
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayOperatorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDisabled
                          ? colors.onSurfaceVariant
                          : colors.onSurface,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Row(
                    children: [
                      Icon(
                        Icons.location_off_outlined,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'No location assigned',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              )
                  : FutureBuilder<Map<String, dynamic>?>(
                future: _getLocation(locationId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLocationLoadingCard(
              context,
              operatorName: displayOperatorName,
              disabled: isDisabled,
            );
          }

          return _LocationCardInformation(
            locationData: snapshot.data,
            operatorName: displayOperatorName,
            disabled: isDisabled,
          );
        },
      ),
            ),

            const SizedBox(width: 16),

            // --------------------------------------------------------
            // ACTIONS
            // --------------------------------------------------------
            _buildActionsButton(
              context,
              document: document,
              displayName: displayOperatorName,
              disabled: isDisabled,
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // ACTION MENU
  // ================================================================

  Widget _buildActionsButton(
    BuildContext context, {
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
    required String displayName,
    required bool disabled,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Operator actions',
      position: PopupMenuPosition.under,
      icon: const Icon(Icons.more_horiz_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        switch (value) {
          case 'view':
            _viewOperator(context, document);
            break;

          case 'edit':
            _editOperator(context, document);
            break;

          case 'password':
            _changePassword(context, document);
            break;



          case 'delete':
            _deleteOperator(context, document, displayName);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view',
          child: _ActionMenuItem(
            icon: Icons.visibility_outlined,
            title: 'View information',
          ),
        ),

        const PopupMenuItem(
          value: 'edit',
          child: _ActionMenuItem(
            icon: Icons.edit_outlined,
            title: 'Edit operator',
          ),
        ),

        const PopupMenuItem(
          value: 'password',
          child: _ActionMenuItem(
            icon: Icons.lock_reset_outlined,
            title: 'Change password',
          ),
        ),

        const PopupMenuDivider(),

        const PopupMenuItem(
          value: 'delete',
          child: _ActionMenuItem(
            icon: Icons.delete_outline_rounded,
            title: 'Delete operator',
            isDestructive: true,
          ),
        ),
      ],
    );
  }

  // ================================================================
  // VIEW OPERATOR INFORMATION
  //
  // This is where ALL the detailed information lives.
  // ================================================================

  Future<void> _viewOperator(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();

    final firstName = (data['firstName'] ?? '').toString().trim();

    final lastName = (data['lastName'] ?? '').toString().trim();

    final operatorName = [
      firstName,
      lastName,
    ].where((name) => name.isNotEmpty).join(' ');

    final email = (data['email'] ?? 'No email').toString();

    final locationId = (data['location'] ?? '').toString().trim();

    Map<String, dynamic>? locationData;

    if (locationId.isNotEmpty) {
      locationData = await _getLocation(locationId);
    }

    if (!context.mounted) return;

    final locationExists = locationData != null;

    final locationName =
        locationData?['locationName']?.toString() ?? 'No location';

    final address =
        locationData?['address']?.toString() ?? 'No address available';

    final parkingCharges = _formatParkingCharges(
      locationData?['parkingCharges'],
    );

    final graceTime = _formatGraceTime(locationData?['graceTimeSeconds']);

    final createdAt = _formatCreatedAt(locationData?['createdAt']);

    final isDisabled = data['disabled'] == true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colors = theme.colorScheme;

        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),

          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),

          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),

          // ----------------------------------------------------------
          // HEADER
          // ----------------------------------------------------------
          title: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  _getInitials(firstName: firstName, lastName: lastName),
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operatorName.isEmpty ? 'Operator' : operatorName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Operator account',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ----------------------------------------------------------
          // DETAIL INFORMATION
          // ----------------------------------------------------------
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // ACCOUNT
                  // ==================================================
                  _InformationSectionTitle(
                    icon: Icons.person_outline_rounded,
                    title: 'Account',
                  ),

                  const SizedBox(height: 10),

                  _InformationCard(
                    children: [
                      _InformationRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Name',
                        value: operatorName.isEmpty ? 'Unknown' : operatorName,
                      ),

                      _InformationRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: email,
                      ),

                      _InformationRow(
                        icon: isDisabled
                            ? Icons.block_outlined
                            : Icons.check_circle_outline_rounded,
                        label: 'Status',
                        value: isDisabled ? 'Disabled' : 'Active',
                        valueColor: isDisabled ? colors.error : colors.primary,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // LOCATION
                  // ==================================================
                  _InformationSectionTitle(
                    icon: Icons.location_on_outlined,
                    title: 'Assigned Location',
                  ),

                  const SizedBox(height: 10),

                  if (!locationExists)
                    _InformationCard(
                      children: [
                        _InformationRow(
                          icon: Icons.location_off_outlined,
                          label: 'Location',
                          value: 'Location information unavailable',
                          valueColor: colors.error,
                          showDivider: false,
                        ),
                      ],
                    )
                  else
                    _InformationCard(
                      children: [
                        _InformationRow(
                          icon: Icons.business_outlined,
                          label: 'Location',
                          value: locationName,
                        ),

                        _InformationRow(
                          icon: Icons.map_outlined,
                          label: 'Address',
                          value: address,
                        ),

                        _InformationRow(
                          icon: Icons.local_parking_outlined,
                          label: 'Parking',
                          value: parkingCharges,
                        ),

                        _InformationRow(
                          icon: Icons.timer_outlined,
                          label: 'Grace time',
                          value: graceTime,
                        ),

                        _InformationRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Created',
                          value: createdAt,
                          showDivider: false,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  // ================================================================
  // LOADING
  // ================================================================

  Widget _buildLoadingState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(),
          ),

          const SizedBox(height: 16),

          Text(
            'Loading operators...',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // ERROR
  // ================================================================

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: colors.errorContainer.withOpacity(0.45),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: colors.error),

            const SizedBox(height: 16),

            Text(
              'Couldn’t load operators',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // EMPTY STATE
  // ================================================================

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_alt_outlined,
                size: 42,
                color: colors.onPrimaryContainer,
              ),
            ),

            const SizedBox(height: 22),

            Text(
              'No operators yet',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Operators are people who can manage and operate your parking system. '
              'Add your first operator to get started.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: widget.onAddOperator,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add Your First Operator'),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // NO SEARCH RESULTS
  // ================================================================

  Widget _buildNoSearchResults(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 52,
            color: colors.onSurfaceVariant,
          ),

          const SizedBox(height: 14),

          Text(
            'No operators found',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Try searching with a different name, email, or location.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials({required String firstName, required String lastName}) {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }

    if (firstName.isNotEmpty) {
      return firstName[0].toUpperCase();
    }

    if (lastName.isNotEmpty) {
      return lastName[0].toUpperCase();
    }

    return '?';
  }

  // ================================================================
  // PARKING CHARGES
  // ================================================================

  String _formatParkingCharges(dynamic value) {
    if (value == null) {
      return 'Not specified';
    }

    final number = num.tryParse(value.toString());

    if (number == null) {
      return value.toString();
    }

    return 'Rs. ${number.toStringAsFixed(0)}';
  }

  // ================================================================
  // GRACE TIME
  //
  // Example:
  // 5700 seconds
  // = 1 hour 35 minutes
  // ================================================================

  String _formatGraceTime(dynamic value) {
    if (value == null) {
      return 'Not specified';
    }

    final seconds = int.tryParse(value.toString());

    if (seconds == null || seconds < 0) {
      return 'Not specified';
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

    if (minutes > 0) {
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }

    return '0 minutes';
  }

  // ================================================================
  // CREATED DATE
  // ================================================================

  String _formatCreatedAt(dynamic value) {
    if (value == null) {
      return 'Unknown';
    }

    DateTime? dateTime;

    if (value is Timestamp) {
      dateTime = value.toDate();
    } else if (value is DateTime) {
      dateTime = value;
    }

    if (dateTime == null) {
      return 'Unknown';
    }

    final localDateTime = dateTime.toLocal();

    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final month = monthNames[localDateTime.month - 1];

    final hour = localDateTime.hour % 12 == 0 ? 12 : localDateTime.hour % 12;

    final minute = localDateTime.minute.toString().padLeft(2, '0');

    final period = localDateTime.hour >= 12 ? 'PM' : 'AM';

    return '$month ${localDateTime.day}, '
        '${localDateTime.year} at '
        '$hour:$minute $period';
  }

  // ================================================================
  // EDIT
  // ================================================================

  void _editOperator(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    AppToast.information(context, 'Edit operator', 'This action is not available yet.');
  }

  // ================================================================
  // CHANGE PASSWORD
  // ================================================================

  void _changePassword(
      BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    final firstName = (data['firstName'] ?? '').toString().trim();
    final lastName = (data['lastName'] ?? '').toString().trim();

    final operatorName = [
      firstName,
      lastName,
    ].where((name) => name.isNotEmpty).join(' ');

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colors = theme.colorScheme;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.lock_reset_rounded,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Change Password'),
              ),
            ],
          ),
          content: Text(
            '${operatorName.isEmpty ? 'This operator' : operatorName} '
                'must change their password from their own account.\n\n'
                'For security, an administrator cannot directly change another '
                'Firebase Authentication user’s password without a secure backend.',
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: colors.onSurfaceVariant,
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  // ================================================================
  // ENABLE / DISABLE
  // ================================================================

  Future<void> _toggleOperator(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    String displayName,
    bool currentlyDisabled,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            currentlyDisabled
                ? 'Enable this operator?'
                : 'Disable this operator?',
          ),

          content: Text(
            currentlyDisabled
                ? '$displayName will be able to use their account again.'
                : '$displayName will no longer be able to use their account.',
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(currentlyDisabled ? 'Enable' : 'Disable'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await document.reference.update({'disabled': !currentlyDisabled});

      if (!context.mounted) {
        return;
      }

      AppToast.success(
        context,
        currentlyDisabled ? 'Operator enabled' : 'Operator disabled',
        currentlyDisabled ? '$displayName can sign in again.' : '$displayName can no longer sign in.',
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      AppToast.error(context, 'Could not update account', 'Unable to update the account.');
    }
  }

  // ================================================================
  // DELETE
  // ================================================================

  Future<void> _deleteOperator(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    String displayName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;

        return AlertDialog(
          title: const Text('Delete operator?'),

          content: Text(
            'Are you sure you want to delete $displayName? '
            'This action cannot be undone.',
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await document.reference.delete();

      if (!context.mounted) {
        return;
      }

      AppToast.success(context, 'Operator deleted', '$displayName has been removed.');
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      AppToast.error(context, 'Could not delete operator', 'Unable to delete the operator.');
    }
  }
}

// ====================================================================
// LOCATION INFORMATION ON CARD
//
// Gets the location document using:
//
// users.location
//       ↓
// locations/{locationId}
//       ↓
// locationName
// parkingCharges
//
// ====================================================================

class _LocationCardInformation extends StatelessWidget {
  const _LocationCardInformation({
    required this.locationData,
    required this.operatorName,
    required this.disabled,
  });

  final Map<String, dynamic>? locationData;
  final String operatorName;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // --------------------------------------------------------------
    // LOCATION NOT FOUND
    // --------------------------------------------------------------
    if (locationData == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            operatorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: disabled
                  ? colors.onSurfaceVariant
                  : colors.onSurface,
            ),
          ),

          const SizedBox(height: 7),

          Row(
            children: [
              Icon(
                Icons.location_off_outlined,
                size: 16,
                color: colors.error,
              ),

              const SizedBox(width: 7),

              Text(
                'Location unavailable',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      );
    }

    final locationName =
    (locationData!['locationName'] ?? 'Unknown location').toString();

    final parkingCharges =
    _formatParkingCharges(locationData!['parkingCharges']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ------------------------------------------------------------
        // OPERATOR NAME
        // ------------------------------------------------------------
        Text(
          operatorName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: disabled
                ? colors.onSurfaceVariant
                : colors.onSurface,
          ),
        ),

        const SizedBox(height: 7),

        // ------------------------------------------------------------
        // LOCATION + PARKING + STATUS
        // ------------------------------------------------------------
        Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 16,
              color: disabled
                  ? colors.onSurfaceVariant
                  : colors.primary,
            ),

            const SizedBox(width: 6),

            Flexible(
              child: Text(
                locationName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(width: 12),

            Icon(
              Icons.local_parking_outlined,
              size: 16,
              color: colors.onSurfaceVariant,
            ),

            const SizedBox(width: 5),

            Text(
              parkingCharges,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(width: 10),

            _buildStatusBadge(
              context,
              disabled: disabled,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(
      BuildContext context, {
        required bool disabled,
      }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final backgroundColor = disabled
        ? colors.errorContainer
        : colors.primaryContainer;

    final foregroundColor = disabled
        ? colors.onErrorContainer
        : colors.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            disabled
                ? Icons.block_rounded
                : Icons.check_circle_rounded,
            size: 12,
            color: foregroundColor,
          ),

          const SizedBox(width: 4),

          Text(
            disabled ? 'Disabled' : 'Active',
            style: theme.textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatParkingCharges(dynamic value) {
    if (value == null) {
      return 'N/A';
    }

    final number = num.tryParse(value.toString());

    if (number == null) {
      return value.toString();
    }

    return 'Rs. ${number.toStringAsFixed(0)}';
  }
}
  Widget _buildStatusBadge(BuildContext context, {required bool disabled}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final backgroundColor = disabled
        ? colors.errorContainer
        : colors.primaryContainer;

    final foregroundColor = disabled
        ? colors.onErrorContainer
        : colors.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            disabled ? Icons.block_rounded : Icons.check_circle_rounded,
            size: 12,
            color: foregroundColor,
          ),

          const SizedBox(width: 4),

          Text(
            disabled ? 'Disabled' : 'Active',
            style: theme.textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatParkingCharges(dynamic value) {
    if (value == null) {
      return 'Parking charge not specified';
    }

    final number = num.tryParse(value.toString());

    if (number == null) {
      return value.toString();
    }

    return 'Rs. ${number.toStringAsFixed(0)}';
  }

// ====================================================================
// ACTION MENU ITEM
// ====================================================================

class _ActionMenuItem extends StatelessWidget {
  const _ActionMenuItem({
    required this.icon,
    required this.title,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDestructive ? colors.error : colors.onSurfaceVariant,
        ),

        const SizedBox(width: 12),

        Text(
          title,
          style: TextStyle(color: isDestructive ? colors.error : null),
        ),
      ],
    );
  }
}

// ====================================================================
// INFORMATION SECTION TITLE
// ====================================================================

class _InformationSectionTitle extends StatelessWidget {
  const _InformationSectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 19, color: colors.primary),

        const SizedBox(width: 8),

        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// INFORMATION CARD
// ====================================================================

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(children: children),
    );
  }
}

// ====================================================================
// INFORMATION ROW
// ====================================================================

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: colors.onSurfaceVariant),

              const SizedBox(width: 11),

              SizedBox(
                width: 82,
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (showDivider)
          Divider(
            height: 1,
            indent: 44,
            endIndent: 15,
            color: colors.outlineVariant.withOpacity(0.45),
          ),
      ],
    );
  }
}
