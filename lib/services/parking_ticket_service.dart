import 'tenant_context.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'app_data_cache.dart';
import 'offline_ticket_store.dart';

class ParkingTicketService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ParkingTicketService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Creates a new vehicle entry / parking ticket.
  /// Optimized for high-throughput heavy-traffic parking facilities:
  /// - Uses in-memory duplicate check and cached location settings when available
  /// - Reflects admin grace-time updates in real time
  /// - Executes atomic serial transaction and document creation
  Future<String> createVehicleEntry({
    required String vehicleCategory,
    required String vehicleNumber,
    bool isManualPlate = false,
    String driverName = '',
    String phoneNumber = '',
    String notes = 'clear',
    String? membershipId,
    String? membershipName,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No operator is currently logged in.');
    }

    final operatorId = user.uid;
    final isMembership = vehicleCategory.toLowerCase() == 'membership';
    if (isMembership && (membershipId == null || membershipId.isEmpty)) {
      throw ArgumentError(
        'A valid parking membership is required for this entry.',
      );
    }

    // Enforce the basic safe character and length rules. Format expectations
    // are handled as a soft confirmation in the operator check-in screen.
    final cleanPlate = vehicleNumber.toUpperCase().replaceAll(
      RegExp(r'\s+'),
      '',
    );
    if (cleanPlate.length < 3 ||
        cleanPlate.length > 12 ||
        !RegExp(r'^[A-Z0-9-]+$').hasMatch(cleanPlate)) {
      throw Exception(
        'Vehicle number must be 3–12 characters using capital letters, numbers, and dashes.',
      );
    }

    final cache = AppDataCache.instance;
    final bool useCache =
        cache.isLoaded &&
        cache.operatorId == operatorId &&
        cache.locationId != null &&
        cache.locationNumericId > 0;

    final String locationId;
    final int locationNumericId;
    final String locationName;
    final int graceTimeSeconds;
    final int extraGraceTimeMinutes;
    final double parkingCharges;
    final String entryOperatorName;

    if (useCache) {
      // 1. High-speed in-memory duplicate check (0ms latency)
      if (cache.isVehicleAlreadyIn(cleanPlate)) {
        throw Exception(
          'This vehicle is already inside this parking location.',
        );
      }

      locationId = cache.locationId!;
      locationNumericId = cache.locationNumericId;
      locationName = cache.locationName ?? '';
      graceTimeSeconds = cache.graceTimeSeconds;
      extraGraceTimeMinutes = cache.extraGraceTimeMinutes;
      parkingCharges = isMembership ? 0 : cache.parkingCharges.toDouble();
      entryOperatorName = cache.operatorName ?? '';
    } else {
      // Fallback path when cache is warming up
      final userDoc = await TenantContext.instance
          .userDocument(operatorId, firestore: _firestore)
          .get();
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
      entryOperatorName = (userData['firstName'] ?? userData['name'] ?? '')
          .toString();

      // Check duplicates from server
      final normalizedVehicleNumber = cleanPlate.replaceAll(RegExp(r'\s+'), '');
      final activeTickets = await TenantContext.instance
          .collection('parking_tickets', firestore: _firestore)
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
        throw Exception(
          'This vehicle is already inside this parking location.',
        );
      }

      final locationDoc = await TenantContext.instance
          .collection('locations', firestore: _firestore)
          .doc(locationId)
          .get();
      if (!locationDoc.exists) {
        throw Exception('Operator location was not found.');
      }

      final locationData = locationDoc.data() ?? {};
      final dynamic numId = locationData['id'];
      locationNumericId = numId is int
          ? numId
          : int.tryParse(numId?.toString() ?? '') ?? 0;
      if (locationNumericId == 0) {
        throw Exception('Location numeric ID is missing.');
      }

      locationName = locationData['locationName']?.toString() ?? '';
      graceTimeSeconds = _toInt(locationData['graceTimeSeconds']);
      extraGraceTimeMinutes = _toInt(locationData['extraGraceTimeMinutes']);
      parkingCharges = isMembership
          ? 0
          : _toDouble(locationData['parkingCharges']);
    }

    // A local duplicate guard protects the operator even if Firestore's
    // listener has not yet received an earlier offline entry.
    if (!kIsWeb &&
        await OfflineTicketStore.instance.isPlateActive(
          locationId,
          cleanPlate,
        )) {
      throw Exception('This vehicle is already inside this parking location.');
    }
    if (kIsWeb) {
      final active = await TenantContext.instance
          .collection('parking_tickets', firestore: _firestore)
          .where('locationId', isEqualTo: locationId)
          .where('status', isEqualTo: 'in')
          .get();
      if (active.docs.any(
        (doc) =>
            (doc.data()['vehicleNumber'] ?? '').toString().toUpperCase() ==
            cleanPlate,
      )) {
        throw Exception(
          'This vehicle is already inside this parking location.',
        );
      }
    }

    if (kIsWeb) {
      return _createRemoteVehicleEntry(
        vehicleCategory: vehicleCategory,
        vehicleNumber: cleanPlate,
        isManualPlate: isManualPlate,
        driverName: driverName,
        phoneNumber: phoneNumber,
        notes: notes,
        operatorId: operatorId,
        locationId: locationId,
        locationNumericId: locationNumericId,
        locationName: locationName,
        graceTimeSeconds: graceTimeSeconds,
        extraGraceTimeMinutes: extraGraceTimeMinutes,
        parkingCharges: parkingCharges,
        entryOperatorName: entryOperatorName,
        membershipId: membershipId,
        membershipName: membershipName,
      );
    }

    // Save locally before acknowledging the operator. Firebase writes and
    // ticket serial allocation happen in the background retry queue.
    final now = DateTime.now();
    final id = OfflineTicketStore.instance.newId();
    await OfflineTicketStore.instance.save(
      {
        'ticketNumber': 'PENDING-${now.millisecondsSinceEpoch}',
        'vehicleCategory': vehicleCategory,
        'vehicleNumber': cleanPlate,
        if (isMembership) 'membershipId': membershipId,
        if (isMembership) 'membershipName': membershipName,
        if (isMembership) 'membershipVisit': true,
        'plateReviewStatus': isManualPlate ? 'manual' : 'standard',
        'driverName': driverName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'notes': notes.trim().isEmpty ? 'clear' : notes.trim(),
        'locationId': locationId,
        'locationNumericId': locationNumericId,
        'locationName': locationName,
        'operatorId': operatorId,
        '_tenantCompanyId': TenantContext.instance.companyId,
        'entryOperatorId': operatorId,
        'entryOperatorName': entryOperatorName,
        'exitOperatorId': '',
        'exitOperatorName': '',
        'startTime': now.toIso8601String(),
        'endTime': null,
        'graceTimeSeconds': graceTimeSeconds,
        'extraGraceTimeMinutes': extraGraceTimeMinutes,
        'parkingCharges': parkingCharges,
        'charges': 0.0,
        'status': 'in',
        'date': DateFormat('yyyy-MM-dd').format(now),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        '_startIso': now.toIso8601String(),
      },
      id: id,
      locationId: locationId,
    );
    OfflineTicketStore.instance.syncPending();
    return id;
  }

  Future<String> _createRemoteVehicleEntry({
    required String vehicleCategory,
    required String vehicleNumber,
    required bool isManualPlate,
    required String driverName,
    required String phoneNumber,
    required String notes,
    required String operatorId,
    required String locationId,
    required int locationNumericId,
    required String locationName,
    required int graceTimeSeconds,
    required int extraGraceTimeMinutes,
    required double parkingCharges,
    required String entryOperatorName,
    String? membershipId,
    String? membershipName,
  }) async {
    final now = DateTime.now();
    final date = DateFormat('yyyy-MM-dd').format(now);
    final code = locationNumericId.toString().padLeft(2, '0');
    final counter = TenantContext.instance
        .collection('counters', firestore: _firestore)
        .doc('${code}_$date');
    final serial = await _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counter);
      final previous = snapshot.data()?['lastSerial'];
      final next =
          (previous is num
              ? previous.toInt()
              : int.tryParse('$previous') ?? 0) +
          1;
      transaction.set(counter, {
        'lastSerial': next,
        'date': date,
        'locationCode': code,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return next;
    });
    final id = TenantContext.instance
        .collection('parking_tickets', firestore: _firestore)
        .doc()
        .id;
    await TenantContext.instance
        .collection('parking_tickets', firestore: _firestore)
        .doc(id)
        .set({
          'ticketNumber':
              'PVS#$code${DateFormat('dM').format(now)}${serial.toString().padLeft(4, '0')}',
          'vehicleCategory': vehicleCategory,
          'vehicleNumber': vehicleNumber,
          if (membershipId != null) 'membershipId': membershipId,
          if (membershipName != null) 'membershipName': membershipName,
          if (membershipId != null) 'membershipVisit': true,
          'plateReviewStatus': isManualPlate ? 'manual' : 'standard',
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
          'startTime': Timestamp.fromDate(now),
          'endTime': null,
          'graceTimeSeconds': graceTimeSeconds,
          'extraGraceTimeMinutes': extraGraceTimeMinutes,
          'parkingCharges': parkingCharges,
          'charges': 0.0,
          'status': 'in',
          'date': date,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
    return id;
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
