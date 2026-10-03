import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/app_data_cache.dart';

class OperatorDashboardBody extends StatefulWidget {
final VoidCallback onCarIn;
final VoidCallback onCarOut;

const OperatorDashboardBody({
super.key,
required this.onCarIn,
required this.onCarOut,
});

@override
State<OperatorDashboardBody> createState() => _OperatorDashboardBodyState();
}

class _OperatorDashboardBodyState extends State<OperatorDashboardBody> {
String? _locationId;
String? _locationError;

@override
void initState() {
super.initState();
if (AppDataCache.instance.isLoaded && AppDataCache.instance.locationId != null) {
  _locationId = AppDataCache.instance.locationId;
} else {
  _loadOperatorLocation();
}
}

Future<void> _loadOperatorLocation() async {
try {
await AppDataCache.instance.preloadForCurrentUser();

if (!mounted) return;

if (AppDataCache.instance.locationId != null) {
  setState(() {
    _locationId = AppDataCache.instance.locationId;
    _locationError = null;
  });
} else {
  throw Exception('No location is assigned to this operator.');
}
} catch (e) {
if (!mounted) return;

setState(() {
_locationError = e.toString().replaceFirst('Exception: ', '');
});
}
}

@override
Widget build(BuildContext context) {
if (_locationError != null) {
return _LocationError(
message: _locationError!,
onRetry: () {
setState(() {
_locationId = null;
_locationError = null;
});
_loadOperatorLocation();
},
);
}

if (_locationId == null) {
return const Center(child: CircularProgressIndicator());
}

return Container(
color: Theme.of(context).colorScheme.surface,
padding: const EdgeInsets.all(24),
child: LayoutBuilder(
builder: (context, constraints) {
final double width = constraints.maxWidth;

return SingleChildScrollView(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
  _StatCardsRow(
    width: width,
    locationId: _locationId!,
    operatorId: AppDataCache.instance.operatorId ?? '',
  ),

const SizedBox(height: 20),

_ActionButtonsRow(
width: width,
onCarIn: widget.onCarIn,
onCarOut: widget.onCarOut,
),

const SizedBox(height: 20),

  _RecentActivityCard(
    locationId: _locationId!,
    operatorId: AppDataCache.instance.operatorId ?? '',
  ),
],
),
);
},
),
);
}
}

// ============================================================
// FIRESTORE HELPERS
// ============================================================

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

return null;
}

double firestoreDouble(dynamic value) {
if (value == null) {
return 0;
}

if (value is num) {
return value.toDouble();
}

return double.tryParse(value.toString()) ?? 0;
}

/// Keeps dashboard totals in sync with open and checked-out tickets.
Stream<List<Map<String, dynamic>>> _locationTicketDataStream(String locationId) {
  late StreamController<List<Map<String, dynamic>>> controller;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? activeSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? backupSub;
  List<Map<String, dynamic>> active = [];
  List<Map<String, dynamic>> completed = [];
  var activeReady = false;
  var backupReady = false;

  void emit() {
    if (activeReady && backupReady && !controller.isClosed) {
      controller.add([...active, ...completed]);
    }
  }

  controller = StreamController<List<Map<String, dynamic>>>(
    onListen: () {
      final firestore = FirebaseFirestore.instance;
      activeSub = firestore
          .collection('parking_tickets')
          .where('locationId', isEqualTo: locationId)
          .snapshots()
          .listen((snapshot) {
        active = snapshot.docs.map((doc) => doc.data()).toList();
        activeReady = true;
        emit();
      }, onError: controller.addError);
      backupSub = firestore
          .collection('backup')
          .where('locationId', isEqualTo: locationId)
          .snapshots()
          .listen((snapshot) {
        completed = snapshot.docs.map((doc) => doc.data()).toList();
        backupReady = true;
        emit();
      }, onError: (Object error) {
        // Legacy archive reads are denied in some deployments. Keep showing
        // tickets from the primary collection; new checkouts stay there.
        completed = [];
        backupReady = true;
        emit();
      });
    },
    onCancel: () async {
      await activeSub?.cancel();
      await backupSub?.cancel();
    },
  );
  return controller.stream;
}

// ============================================================
// LOCATION ERROR
// ============================================================

class _LocationError extends StatelessWidget {
final String message;
final VoidCallback onRetry;

const _LocationError({
required this.message,
required this.onRetry,
});

@override
Widget build(BuildContext context) {
return Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
const Icon(Icons.location_off, size: 48, color: Colors.red),
const SizedBox(height: 12),
const Text(
'Unable to load operator location',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
textAlign: TextAlign.center,
),
const SizedBox(height: 8),
Text(
message,
textAlign: TextAlign.center,
style: const TextStyle(color: Color(0xFF757575)),
),
const SizedBox(height: 16),
ElevatedButton.icon(
onPressed: onRetry,
icon: const Icon(Icons.refresh),
label: const Text('Retry'),
),
],
),
),
);
}
}

// ============================================================
// STAT CARDS
// ============================================================

class _StatCardsRow extends StatelessWidget {
final double width;
final String locationId;
final String operatorId;

const _StatCardsRow({
required this.width,
required this.locationId,
required this.operatorId,
});

@override
Widget build(BuildContext context) {
int columns;

if (width >= 950) {
columns = 4;
} else if (width >= 650) {
columns = 2;
} else {
columns = 1;
}

const double spacing = 16;

final double cardWidth = (width - (spacing * (columns - 1))) / columns;

return StreamBuilder<List<Map<String, dynamic>>>(
stream: _locationTicketDataStream(locationId),

builder: (context, snapshot) {
// ----------------------------------------------------
// ERROR
// ----------------------------------------------------

if (snapshot.hasError) {
return _StatsError(message: 'Firestore error: ${snapshot.error}');
}

// ----------------------------------------------------
// LOADING
// ----------------------------------------------------

if (snapshot.connectionState == ConnectionState.waiting &&
!snapshot.hasData) {
return Wrap(
spacing: spacing,
runSpacing: spacing,
children: List.generate(4, (index) {
return SizedBox(
width: cardWidth,
child: const _StatCard(
data: _StatData(label: 'LOADING', value: '...'),
),
);
}),
);
}

// ----------------------------------------------------
// NO DATA
// ----------------------------------------------------

if (!snapshot.hasData) {
return const _StatsError(message: 'No parking ticket data found.');
}

final tickets = snapshot.data!;

// ----------------------------------------------------
// DATE RANGE
// ----------------------------------------------------

final now = DateTime.now();

final startOfToday = DateTime(now.year, now.month, now.day);

final endOfToday = startOfToday.add(const Duration(days: 1));

// ----------------------------------------------------
// CALCULATE STATS
// ----------------------------------------------------

int carsInside = 0;
int todayEntries = 0;
int todayExits = 0;
double todayRevenue = 0;

final myOpId = operatorId.isNotEmpty ? operatorId : (AppDataCache.instance.operatorId ?? '');

for (final data in tickets) {
  final status = data['status']?.toString().toLowerCase();
  final startTime = firestoreDate(data['startTime']);
  final endTime = firestoreDate(data['endTime']);

  final entryOp = (data['entryOperatorId'] ?? data['operatorId'] ?? '').toString();
  final exitOp = (data['exitOperatorId'] ?? '').toString();

  // 1. CARS CURRENTLY INSIDE THE FACILITY
  if (status == 'in') {
    carsInside++;
  }

  // 2. TODAY'S ENTRIES: Only cars entered by THIS operator!
  // ("it dont show me that i enter this car, because i did not")
  if (startTime != null &&
      !startTime.isBefore(startOfToday) &&
      startTime.isBefore(endOfToday)) {
    if (myOpId.isEmpty || entryOp == myOpId) {
      todayEntries++;
    }
  }

  // 3. TODAY'S EXITS: Only cars checked out by THIS operator!
  // ("and the revenue will go for who out the cars")
  if (status != 'in' &&
      endTime != null &&
      !endTime.isBefore(startOfToday) &&
      endTime.isBefore(endOfToday)) {
    if (myOpId.isEmpty || exitOp == myOpId) {
      todayExits++;

      final checkoutAmount = firestoreDouble(data['checkoutAmount']);
      final finalCharges = firestoreDouble(data['finalParkingCharges']);
      final charges = firestoreDouble(data['charges']);

      todayRevenue += checkoutAmount > 0
          ? checkoutAmount
          : finalCharges > 0
              ? finalCharges
              : charges;
    }
  }
}

// ----------------------------------------------------
// BUILD CARDS
// ----------------------------------------------------

final stats = [
  _StatData(
    label: 'CARS INSIDE',
    value: carsInside.toString(),
    subtitle: 'Facility total',
  ),
  _StatData(
    label: "TODAY'S ENTRIES",
    value: todayEntries.toString(),
    subtitle: 'Entered by you',
  ),
  _StatData(
    label: "TODAY'S EXITS",
    value: todayExits.toString(),
    subtitle: 'Exited by you',
  ),
  _StatData(
    label: "TODAY'S REVENUE",
    value: 'Rs. ${todayRevenue.toStringAsFixed(0)}',
    subtitle: 'Your shift revenue',
  ),
];

return Wrap(
spacing: spacing,
runSpacing: spacing,
children: stats.map((stat) {
return SizedBox(
width: cardWidth,
child: _StatCard(data: stat),
);
}).toList(),
);
},
);
}
}

class _StatsError extends StatelessWidget {
final String message;

const _StatsError({required this.message});

@override
Widget build(BuildContext context) {
return Container(
width: double.infinity,
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.red.withValues(alpha: 0.05),
borderRadius: BorderRadius.circular(8),
),
child: Text(
message,
style: const TextStyle(color: Colors.red, fontSize: 13),
),
);
}
}

// ============================================================
// STAT DATA
// ============================================================

class _StatData {
  final String label;
  final String value;
  final String? subtitle;

  const _StatData({
    required this.label,
    required this.value,
    this.subtitle,
  });
}

// ============================================================
// STAT CARD
// ============================================================

class _StatCard extends StatelessWidget {
  final _StatData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Color(0xFF757575),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          if (data.subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              data.subtitle!,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9E9E9E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// ACTION BUTTONS
// ============================================================

class _ActionButtonsRow extends StatelessWidget {
final double width;

final VoidCallback onCarIn;
final VoidCallback onCarOut;

const _ActionButtonsRow({
required this.width,
required this.onCarIn,
required this.onCarOut,
});

@override
Widget build(BuildContext context) {
final bool stackVertically = width < 600;

final carIn = _ActionButton(
icon: Icons.directions_car,
label: 'CAR IN',
color: Theme.of(context).colorScheme.primary,
onTap: onCarIn,
);

final carOut = _ActionButton(
icon: Icons.exit_to_app,
label: 'CAR OUT',
color: const Color(0xFF14401A),
onTap: onCarOut,
);

if (stackVertically) {
return Column(children: [carIn, const SizedBox(height: 16), carOut]);
}

return Row(
children: [
Expanded(child: carIn),
const SizedBox(width: 16),
Expanded(child: carOut),
],
);
}
}

// ============================================================
// ACTION BUTTON
// ============================================================

class _ActionButton extends StatelessWidget {
final IconData icon;
final String label;
final Color color;
final VoidCallback onTap;

const _ActionButton({
required this.icon,
required this.label,
required this.color,
required this.onTap,
});

@override
Widget build(BuildContext context) {
return Material(
color: color,
borderRadius: BorderRadius.circular(12),
child: InkWell(
borderRadius: BorderRadius.circular(12),
onTap: onTap,
child: Container(
height: 220,
alignment: Alignment.center,
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(icon, size: 56, color: Colors.white),

const SizedBox(height: 16),

Text(
label,
style: const TextStyle(
color: Colors.white,
fontSize: 20,
fontWeight: FontWeight.bold,
letterSpacing: 0.5,
),
),
],
),
),
),
);
}
}

// ============================================================
// RECENT ACTIVITY
// ============================================================

class _RecentActivityCard extends StatelessWidget {
final String locationId;
final String operatorId;

const _RecentActivityCard({
required this.locationId,
required this.operatorId,
});

@override
Widget build(BuildContext context) {
return Container(
width: double.infinity,
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: Theme.of(context).colorScheme.surface,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: const Color(0xFFE0E0E0)),
boxShadow: const [
BoxShadow(
color: Color(0x0D000000),
blurRadius: 6,
offset: Offset(0, 2),
),
],
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Recent Activity',
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
color: Colors.black,
),
),

const SizedBox(height: 12),

StreamBuilder<List<Map<String, dynamic>>>(
  stream: _locationTicketDataStream(locationId),

builder: (context, snapshot) {
if (snapshot.hasError) {
return Padding(
padding: const EdgeInsets.symmetric(vertical: 20),
child: Text(
'Unable to load activity: '
'${snapshot.error}',
style: const TextStyle(color: Colors.red),
),
);
}

if (!snapshot.hasData) {
return const Padding(
padding: EdgeInsets.symmetric(vertical: 20),
child: Center(child: CircularProgressIndicator()),
);
}

final docs = snapshot.data!.where((data) {
  final isOwnEntry = (data['entryOperatorId'] ?? data['operatorId'] ?? '').toString() == operatorId;
  final isOwnExit = (data['exitOperatorId'] ?? '').toString() == operatorId;
  return isOwnEntry || isOwnExit;
}).toList();

// ------------------------------------------------
// SORT LOCALLY BY updatedAt
//
// This avoids requiring an orderBy query/index.
// ------------------------------------------------

docs.sort((a, b) {
final aDate =
firestoreDate(a['updatedAt']) ??
firestoreDate(a['createdAt']) ??
DateTime(2000);

final bDate =
firestoreDate(b['updatedAt']) ??
firestoreDate(b['createdAt']) ??
DateTime(2000);

return bDate.compareTo(aDate);
});

// Only display latest 10.
final recentDocs = docs.take(10).toList();

if (recentDocs.isEmpty) {
return const Padding(
padding: EdgeInsets.symmetric(vertical: 20),
child: Text(
'No recent activity.',
style: TextStyle(color: Color(0xFF757575)),
),
);
}

return ListView.separated(
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
itemCount: recentDocs.length,

separatorBuilder: (context, index) =>
const Divider(height: 24, color: Color(0xFFEEEEEE)),

itemBuilder: (context, index) {
final data = recentDocs[index];

return _ActivityRow(
  data: _ActivityData.fromFirestore(data, currentOperatorId: operatorId),
);
},
);
},
),
],
),
);
}
}

// ============================================================
// ACTIVITY DATA
// ============================================================

enum ActivityType { entry, exit }

class _ActivityData {
final ActivityType type;

final String plateNumber;
final String subtitle;
final String time;

final String? amount;

const _ActivityData({
required this.type,
required this.plateNumber,
required this.subtitle,
required this.time,
this.amount,
});

factory _ActivityData.fromFirestore(
  Map<String, dynamic> data, {
  String currentOperatorId = '',
}) {
final status = data['status']?.toString().toLowerCase();
final endTime = firestoreDate(data['endTime']);
final startTime = firestoreDate(data['startTime']);

final bool isExit = status != 'in' && endTime != null;
final DateTime? activityTime = isExit ? endTime : startTime;
final vehicleNumber = data['vehicleNumber']?.toString() ?? 'Unknown vehicle';
final ticketNumber = data['ticketNumber']?.toString() ?? '';

final entryOpId = (data['entryOperatorId'] ?? data['operatorId'] ?? '').toString();
final entryOpName = (data['entryOperatorName'] ?? '').toString();
final exitOpId = (data['exitOperatorId'] ?? '').toString();
final exitOpName = (data['exitOperatorName'] ?? '').toString();

String subtitle;
if (isExit) {
  if (currentOperatorId.isNotEmpty && exitOpId == currentOperatorId) {
    if (entryOpId.isNotEmpty && entryOpId != currentOperatorId) {
      subtitle = 'Out by you • Entered by ${entryOpName.isNotEmpty ? entryOpName : 'Gate operator'}';
    } else {
      subtitle = 'Out by you • $ticketNumber';
    }
  } else {
    subtitle = 'Out by ${exitOpName.isNotEmpty ? exitOpName : 'Operator'} • $ticketNumber';
  }
} else {
  if (currentOperatorId.isNotEmpty && entryOpId == currentOperatorId) {
    subtitle = 'In by you • $ticketNumber';
  } else {
    subtitle = 'In by ${entryOpName.isNotEmpty ? entryOpName : 'Gate operator'} • $ticketNumber';
  }
}

final checkoutAmount = firestoreDouble(data['checkoutAmount']);
final finalParkingCharges = firestoreDouble(data['finalParkingCharges']);
final charges = firestoreDouble(data['charges']);

final finalAmount = checkoutAmount > 0
    ? checkoutAmount
    : finalParkingCharges > 0
        ? finalParkingCharges
        : charges;

return _ActivityData(
type: isExit ? ActivityType.exit : ActivityType.entry,
plateNumber: vehicleNumber,
subtitle: subtitle,
time: _formatTimeAgo(activityTime),
amount: isExit
? 'Rs. ${finalAmount.toStringAsFixed(0)}'
    : null,
);
}

static String _formatTimeAgo(DateTime? time) {
if (time == null) {
return '';
}

final difference = DateTime.now().difference(time);

if (difference.isNegative) {
return 'Just now';
}

if (difference.inSeconds < 60) {
return 'Just now';
}

if (difference.inMinutes < 60) {
return '${difference.inMinutes} mins ago';
}

if (difference.inHours < 24) {
return '${difference.inHours} hours ago';
}

if (difference.inDays == 1) {
return 'Yesterday';
}

return '${difference.inDays} days ago';
}
}

// ============================================================
// ACTIVITY ROW
// ============================================================

class _ActivityRow extends StatelessWidget {
final _ActivityData data;

const _ActivityRow({required this.data});

@override
Widget build(BuildContext context) {
final bool isEntry = data.type == ActivityType.entry;

return Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_ActivityChip(isEntry: isEntry),

const SizedBox(width: 12),

Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
data.plateNumber,
style: const TextStyle(
fontSize: 15,
fontWeight: FontWeight.bold,
color: Colors.black,
),
),

const SizedBox(height: 2),

Text(
data.subtitle,
style: const TextStyle(fontSize: 13, color: Color(0xFF757575)),
),
],
),
),

Column(
crossAxisAlignment: CrossAxisAlignment.end,
children: [
if (data.amount != null)
Text(
data.amount!,
style: TextStyle(
fontSize: 14,
fontWeight: FontWeight.bold,
color: Theme.of(context).colorScheme.primary,
),
),

if (data.amount != null) const SizedBox(height: 2),

Text(
data.time,
style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
),
],
),
],
);
}
}

// ============================================================
// ACTIVITY CHIP
// ============================================================

class _ActivityChip extends StatelessWidget {
  final bool isEntry;

  const _ActivityChip({required this.isEntry});

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isEntry
        ? const Color(0xFFE3F5E6)
        : const Color(0xFFFBE4E4);

    final Color textColor = isEntry
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isEntry ? 'IN' : 'OUT',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
