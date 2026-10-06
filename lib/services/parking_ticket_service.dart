import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'app_data_cache.dart';

class ParkingTicketService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ParkingTicketService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Creates a new vehicle entry / parking ticket.
  /// Optimized for high-throughput heavy-traffic parking facilities:
  /// - Uses in-memory duplicate check and cached location settings when available
  /// - Reflects admin grace-time updates in real time
  /// - Executes atomic serial transaction and document creation
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

    // Vehicle number must strictly follow ABC-123 or ABC-1234
    final cleanPlate = vehicleNumber.trim().toUpperCase();
    final plateRegex = RegExp(r'^[A-Z]{3}-\d{3,4}$');
    if (!plateRegex.hasMatch(cleanPlate)) {
      throw Exception(
        'Vehicle number must follow the format ABC-123 or ABC-1234 (e.g. ABC-123 or ABC-1234).',
      );
    }

    final cache = AppDataCache.instance;
    final bool useCache = cache.isLoaded &&
        cache.operatorId == operatorId &&
        cache.locationId != null &&
        cache.locationNumericId > 0;

    final String locationId;
    final int locationNumericId;
    final String locationName;
    final int graceTimeSeconds;
    final double parkingCharges;
    final String entryOperatorName;

    if (useCache) {
      // 1. High-speed in-memory duplicate check (0ms latency)
      if (cache.isVehicleAlreadyIn(cleanPlate)) {
        throw Exception('This vehicle is already inside this parking location.');
      }

      locationId = cache.locationId!;
      locationNumericId = cache.locationNumericId;
      locationName = cache.locationName ?? '';
      graceTimeSeconds = cache.graceTimeSeconds;
      parkingCharges = cache.parkingCharges.toDouble();
      entryOperatorName = cache.operatorName ?? '';
    } else {
      // Fallback path when cache is warming up
      final userDoc = await _firestore.collection('users').doc(operatorId).get();
      if (!userDoc.exists) {
        throw Exception('Operator profile was not found.');
      }

      final userData = userDoc.data();
      if (userData == null) {
        throw Exception('Operator profile data is empty.');
      }

      final locId = userData['location']?.toString();
      if (locId == null || locId.isEmpty) {
        throw Exception('Operator location is not configured.');
      }

      locationId = locId;
      entryOperatorName = (userData['firstName'] ?? userData['name'] ?? '').toString();

      // Check duplicates from server
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

      final locationDoc = await _firestore.collection('locations').doc(locationId).get();
      if (!locationDoc.exists) {
        throw Exception('Operator location was not found.');
      }

      final locationData = locationDoc.data() ?? {};
      final dynamic numId = locationData['id'];
      locationNumericId = numId is int ? numId : int.tryParse(numId?.toString() ?? '') ?? 0;
      if (locationNumericId == 0) {
        throw Exception('Location numeric ID is missing.');
      }

      locationName = locationData['locationName']?.toString() ?? '';
      graceTimeSeconds = _toInt(locationData['graceTimeSeconds']);
      parkingCharges = _toDouble(locationData['parkingCharges']);
    }

    // ------------------------------------------------------------
    // 2. Generate date information
    // ------------------------------------------------------------
    final now = DateTime.now();
    final counterDate = DateFormat('yyyy-MM-dd').format(now);
    final ticketDate = '${now.day}${now.month}';
    final locationCode = locationNumericId.toString().padLeft(2, '0');

    // ------------------------------------------------------------
    // 3. Generate daily serial atomically
    // ------------------------------------------------------------
    final counterRef = _firestore
        .collection('counters')
        .doc('${locationCode}_$counterDate');

    final int serial = await _firestore.runTransaction<int>(
      (transaction) async {
        final counterSnapshot = await transaction.get(counterRef);

        int nextSerial = 1;

        if (counterSnapshot.exists) {
          final data = counterSnapshot.data();
          final lastSerial = data?['lastSerial'];

          if (lastSerial is int) {
            nextSerial = lastSerial + 1;
          } else if (lastSerial != null) {
            nextSerial = int.tryParse(lastSerial.toString()) ?? 1;
            nextSerial += 1;
          }
        }

        transaction.set(
          counterRef,
          {
            'lastSerial': nextSerial,
            'date': counterDate,
            'locationCode': locationCode,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        return nextSerial;
      },
    );

    final serialString = serial.toString().padLeft(4, '0');
    final ticketNumber = 'PVS#$locationCode$ticketDate$serialString';

    // ------------------------------------------------------------
    // 4. Create parking ticket document
    // ------------------------------------------------------------
    final ticketRef = _firestore.collection('parking_tickets').doc();

    await ticketRef.set({
      'ticketNumber': ticketNumber,
      'vehicleCategory': vehicleCategory,
      'vehicleNumber': cleanPlate,
      'driverName': driverName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'notes': notes.trim().isEmpty ? 'clear' : notes.trim(),
      'locationId': locationId,
      'locationNumericId': locationNumericId,
      'locationName': locationName,
      'operatorId': operatorId,
      'entryOperatorId': operatorId,
      'entryOperatorName': entryOperatorName,
      'exitOperatorId': '',
      'exitOperatorName': '',
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null,
      'graceTimeSeconds': graceTimeSeconds,
      'parkingCharges': parkingCharges,
      'charges': 0.0,
      'status': 'in',
      'date': counterDate,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ticketRef.id;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
