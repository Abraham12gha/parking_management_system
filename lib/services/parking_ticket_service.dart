import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ParkingTicketService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ParkingTicketService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Creates a new vehicle entry / parking ticket.
  ///
  /// This will:
  /// 1. Get the currently logged-in operator.
  /// 2. Get the operator's location from users/{uid}.
  /// 3. Get location settings from locations/{locationId}.
  /// 4. Generate the next daily ticket serial atomically.
  /// 5. Save the ticket in parking_tickets.
  Future<String> createVehicleEntry({
    required String vehicleCategory,
    required String vehicleNumber,
    String driverName = '',
    String phoneNumber = '',
    String notes = 'clear',
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No operator is currently logged in.');
    }

    final operatorId = user.uid;

    // ------------------------------------------------------------
    // 1. Get operator's user document
    // ------------------------------------------------------------

    final userDoc = await _firestore
        .collection('users')
        .doc(operatorId)
        .get();

    if (!userDoc.exists) {
      throw Exception('Operator profile was not found.');
    }

    final userData = userDoc.data();

    if (userData == null) {
      throw Exception('Operator profile data is empty.');
    }

    final locationId = userData['location']?.toString();

    if (locationId == null || locationId.isEmpty) {
      throw Exception('Operator location is not configured.');
    }

    // Vehicle number must strictly follow ABC-123 or ABC-1234
    final cleanPlate = vehicleNumber.trim().toUpperCase();
    final plateRegex = RegExp(r'^[A-Z]{3}-\d{3,4}$');
    if (!plateRegex.hasMatch(cleanPlate)) {
      throw Exception(
        'Vehicle number must follow the format ABC-123 or ABC-1234 (e.g. ABC-123 or ABC-1234).',
      );
    }

    final normalizedVehicleNumber = cleanPlate.replaceAll(RegExp(r'\s+'), '');
    final activeTickets = await _firestore
        .collection('parking_tickets')
        .where('locationId', isEqualTo: locationId)
        .where('status', isEqualTo: 'in')
        .get();
    final duplicate = activeTickets.docs.any((doc) {
      final existing = (doc.data()['vehicleNumber'] ?? '')
          .toString()
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'\s+'), '');
      return existing == normalizedVehicleNumber;
    });
    if (duplicate) {
      throw Exception('This vehicle is already inside this parking location.');
    }

    // ------------------------------------------------------------
    // 2. Get location document
    // ------------------------------------------------------------

    final locationDoc = await _firestore
        .collection('locations')
        .doc(locationId)
        .get();

    if (!locationDoc.exists) {
      throw Exception('Operator location was not found.');
    }

    final locationData = locationDoc.data();

    if (locationData == null) {
      throw Exception('Location data is empty.');
    }

    final dynamic locationNumericIdValue = locationData['id'];

    final int locationNumericId =
    locationNumericIdValue is int
        ? locationNumericIdValue
        : int.tryParse(
      locationNumericIdValue?.toString() ?? '',
    ) ??
        0;

    if (locationNumericId == 0) {
      throw Exception('Location numeric ID is missing.');
    }

    final locationName =
        locationData['locationName']?.toString() ?? '';

    final int graceTimeSeconds =
    _toInt(locationData['graceTimeSeconds']);

    final double parkingCharges =
    _toDouble(locationData['parkingCharges']);

    // ------------------------------------------------------------
    // 3. Generate date information
    // ------------------------------------------------------------

    final now = DateTime.now();

    // Used for the daily counter document.
    // Example: 2026-09-10
    final counterDate = DateFormat('yyyy-MM-dd').format(now);

    // User's requested ticket date format:
    // September 10 -> 109
    final ticketDate = '${now.day}${now.month}';

    // Location numeric ID:
    // 1 -> 01
    final locationCode =
    locationNumericId.toString().padLeft(2, '0');

    // ------------------------------------------------------------
    // 4. Generate daily serial atomically
    // ------------------------------------------------------------

    final counterRef = _firestore
        .collection('counters')
        .doc('${locationCode}_$counterDate');

    final int serial = await _firestore.runTransaction<int>(
          (transaction) async {
        final counterSnapshot = await transaction.get(counterRef);

        int nextSerial = 1;

        if (counterSnapshot.exists) {
          final counterData = counterSnapshot.data();

          final int lastSerial =
          _toInt(counterData?['lastSerial']);

          nextSerial = lastSerial + 1;
        }

        transaction.set(
          counterRef,
          {
            'locationId': locationId,
            'locationNumericId': locationNumericId,
            'date': counterDate,
            'lastSerial': nextSerial,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        return nextSerial;
      },
    );

    final serialString =
    serial.toString().padLeft(4, '0');

    // ------------------------------------------------------------
    // Ticket number
    // ------------------------------------------------------------
    //
    // Current structure:
    // PVS + location + date + serial
    //
    // Example:
    // PVS#011090001
    //
    // We can change this formatting once we finalize the exact
    // ticket-number format.
    //

    final ticketNumber =
        'PVS#$locationCode$ticketDate$serialString';

    // ------------------------------------------------------------
    // 5. Create parking ticket document
    // ------------------------------------------------------------

    final ticketRef =
    _firestore.collection('parking_tickets').doc();

    await ticketRef.set({
      'ticketNumber': ticketNumber,

      'vehicleCategory': vehicleCategory,
      'vehicleNumber': vehicleNumber.trim().toUpperCase(),

      'driverName': driverName.trim(),
      'phoneNumber': phoneNumber.trim(),

      'notes': notes.trim().isEmpty
          ? 'clear'
          : notes.trim(),

      // Location information
      'locationId': locationId,
      'locationNumericId': locationNumericId,
      'locationName': locationName,

      // Operator
      'operatorId': operatorId,
      'entryOperatorId': operatorId,
      'entryOperatorName': (userData['firstName'] ?? userData['name'] ?? '').toString(),
      'exitOperatorId': '',
      'exitOperatorName': '',

      // Parking timing
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null,

      // Snapshot the pricing at car-in time.
      // This is important because location pricing may change later.
      'graceTimeSeconds': graceTimeSeconds,
      'parkingCharges': parkingCharges,

      // No charge while the vehicle is still inside.
      'charges': 0.0,

      // Current parking status
      'status': 'in',

      // Date information
      'date': counterDate,

      // Document timestamps
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ticketRef.id;
  }

  // --------------------------------------------------------------
  // Helper methods
  // --------------------------------------------------------------

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
