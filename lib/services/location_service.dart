import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_model/location_model.dart';

class LocationService {
  LocationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> addLocation({
    required String locationName,
    required String address,
    required int parkingCharges,
  }) async {
    await _firestore.collection('locations').add({
      'locationName': locationName,
      'address': address,
      'parkingCharges': parkingCharges,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<LocationModel>> getLocations() {
    return _firestore
        .collection('locations')
        .orderBy('locationName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(
            (doc) => LocationModel.fromFirestore(
          doc.id,
          doc.data(),
        ),
      )
          .toList(),
    );
  }
}