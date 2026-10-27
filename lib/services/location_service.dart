import 'tenant_context.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../app_model/location_model.dart';

class LocationService {
  LocationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> addLocation({
    required String locationName,
    required String address,
    required int parkingCharges,
    required int graceTimeSeconds,
  }) async {
    try {
      final locationsRef = TenantContext.instance.collection(
        'locations',
        firestore: _firestore,
      );
      final counterRef = TenantContext.instance
          .collection('counters', firestore: _firestore)
          .doc('locations');

      // Get the current counter
      final counterSnapshot = await counterRef.get();

      int newLocationId = 1;

      if (counterSnapshot.exists) {
        final data = counterSnapshot.data();
        final lastId = data?['lastId'];

        if (lastId is int) {
          newLocationId = lastId + 1;
        }
      }

      // Create location document
      final locationRef = locationsRef.doc();

      await locationRef.set({
        'id': newLocationId,
        'locationName': locationName,
        'address': address,
        'parkingCharges': parkingCharges,
        'graceTimeSeconds': graceTimeSeconds,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update counter
      await counterRef.set({'lastId': newLocationId});
    } catch (e, stackTrace) {
      debugPrint('ADD LOCATION ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');
      rethrow;
    }
  }

  /// Updates the grace period of a specific parking location.
  /// This automatically propagates in real time to all connected operators.
  Future<void> updateGraceTime({
    required String locationId,
    required int graceTimeSeconds,
  }) async {
    try {
      await TenantContext.instance
          .collection('locations', firestore: _firestore)
          .doc(locationId)
          .update({
            'graceTimeSeconds': graceTimeSeconds,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      debugPrint(
        'Updated grace time for location $locationId to $graceTimeSeconds seconds',
      );
    } catch (e) {
      debugPrint('Error updating grace time for location $locationId: $e');
      rethrow;
    }
  }

  /// Updates full location configuration.
  Future<void> updateLocation({
    required String locationId,
    required String locationName,
    required String address,
    required int parkingCharges,
    required int graceTimeSeconds,
  }) async {
    try {
      await TenantContext.instance
          .collection('locations', firestore: _firestore)
          .doc(locationId)
          .update({
            'locationName': locationName,
            'address': address,
            'parkingCharges': parkingCharges,
            'graceTimeSeconds': graceTimeSeconds,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error updating location $locationId: $e');
      rethrow;
    }
  }

  /// Delete a location
  Future<void> deleteLocation(String locationId) async {
    try {
      await TenantContext.instance
          .collection('locations', firestore: _firestore)
          .doc(locationId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting location $locationId: $e');
      rethrow;
    }
  }

  /// Single location fetch
  Future<LocationModel?> getLocationById(String locationId) async {
    try {
      final doc = await TenantContext.instance
          .collection('locations', firestore: _firestore)
          .doc(locationId)
          .get();
      if (!doc.exists) return null;
      return LocationModel.fromFirestore(doc.id, doc.data() ?? {});
    } catch (e) {
      debugPrint('Error getting location $locationId: $e');
      return null;
    }
  }

  /// Real-time stream of all parking locations
  Stream<List<LocationModel>> getLocations() {
    return TenantContext.instance
        .collection('locations', firestore: _firestore)
        .orderBy('locationName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LocationModel.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }
}
