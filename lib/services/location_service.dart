import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  LocationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> addLocation({
    required String locationName,
    required String address,
  }) async {
    await _firestore.collection('locations').add({
      'locationName': locationName,
      'address': address,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<String>> getLocationNames() {
    return _firestore
        .collection('locations')
        .orderBy('locationName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => doc.data()['locationName'] as String)
          .toList(),
    );
  }
}