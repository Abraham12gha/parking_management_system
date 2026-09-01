// // import 'package:cloud_firestore/cloud_firestore.dart';
// //
// // import '../app_model/location_model.dart';
// //
// // class LocationService {
// //   LocationService({FirebaseFirestore? firestore})
// //       : _firestore = firestore ?? FirebaseFirestore.instance;
// //
// //   final FirebaseFirestore _firestore;
// //
// //   Future<void> addLocation({
// //     required String locationName,
// //     required String address,
// //     required int parkingCharges,
// //   }) async {
// //     await _firestore.collection('locations').add({
// //       'locationName': locationName,
// //       'address': address,
// //       'parkingCharges': parkingCharges,
// //       'createdAt': FieldValue.serverTimestamp(),
// //     });
// //   }
// //
// //   Stream<List<LocationModel>> getLocations() {
// //     return _firestore
// //         .collection('locations')
// //         .orderBy('locationName')
// //         .snapshots()
// //         .map(
// //           (snapshot) => snapshot.docs
// //           .map(
// //             (doc) => LocationModel.fromFirestore(
// //           doc.id,
// //           doc.data(),
// //         ),
// //       )
// //           .toList(),
// //     );
// //   }
// // }
// import 'package:cloud_firestore/cloud_firestore.dart';
//
// import '../app_model/location_model.dart';
//
// class LocationService {
//   LocationService({FirebaseFirestore? firestore})
//       : _firestore = firestore ?? FirebaseFirestore.instance;
//
//   final FirebaseFirestore _firestore;
//
//   Future<void> addLocation({
//     required String locationName,
//     required String address,
//     required int parkingCharges,
//   }) async {
//     try {
//       final locationsRef = _firestore.collection('locations');
//       final counterRef = _firestore.collection('counters').doc('locations');
//
//       // Get the current counter
//       final counterSnapshot = await counterRef.get();
//
//       int newLocationId = 1;
//
//       if (counterSnapshot.exists) {
//         final data = counterSnapshot.data();
//         final lastId = data?['lastId'];
//
//         if (lastId is int) {
//           newLocationId = lastId + 1;
//         }
//       }
//
//       // Create location document
//       final locationRef = locationsRef.doc();
//
//       await locationRef.set({
//         'id': newLocationId,
//         'locationName': locationName,
//         'address': address,
//         'parkingCharges': parkingCharges,
//         'createdAt': FieldValue.serverTimestamp(),
//       });
//
//       // Update counter
//       await counterRef.set({
//         'lastId': newLocationId,
//       });
//     } catch (e, stackTrace) {
//       print('====================================');
//       print('ADD LOCATION ERROR: $e');
//       print('STACK TRACE: $stackTrace');
//       print('====================================');
//
//       rethrow;
//     }
//   }
//
//   Stream<List<LocationModel>> getLocations() {
//     return _firestore
//         .collection('locations')
//         .orderBy('locationName')
//         .snapshots()
//         .map(
//           (snapshot) => snapshot.docs
//           .map(
//             (doc) => LocationModel.fromFirestore(
//           doc.id,
//           doc.data(),
//         ),
//       )
//           .toList(),
//     );
//   }
// }



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

    // Grace time stored as total seconds
    required int graceTimeSeconds,
  }) async {
    try {
      final locationsRef = _firestore.collection('locations');
      final counterRef =
      _firestore.collection('counters').doc('locations');

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

        // Example:
        // 3 minutes       -> 180
        // 30 minutes      -> 1800
        // 1 hour          -> 3600
        // 1 hour 25 mins  -> 5100
        'graceTimeSeconds': graceTimeSeconds,

        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update counter
      await counterRef.set({
        'lastId': newLocationId,
      });
    } catch (e, stackTrace) {
      print('====================================');
      print('ADD LOCATION ERROR: $e');
      print('STACK TRACE: $stackTrace');
      print('====================================');

      rethrow;
    }
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