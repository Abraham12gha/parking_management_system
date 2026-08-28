import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParkingChargeService {
  static int? _cachedCharge;
  static String? _cachedLocationId;

  static int? get cachedCharge => _cachedCharge;

  static Future<int?> loadCharge({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCharge != null) {
      return _cachedCharge;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _cachedCharge;
    }

    try {
      String? locationId = _cachedLocationId;

      if (locationId == null) {
        final userDocument = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDocument.exists) {
          return _cachedCharge;
        }

        final userData = userDocument.data();

        locationId = userData?['location']?.toString();

        if (locationId == null || locationId.isEmpty) {
          return _cachedCharge;
        }

        _cachedLocationId = locationId;
      }
      final locationDocument = await FirebaseFirestore.instance
          .collection('locations')
          .doc(locationId)
          .get();

      if (!locationDocument.exists) {
        return _cachedCharge;
      }

      final locationData = locationDocument.data();
      final charges = locationData?['parkingCharges'];

      if (charges == null) {
        return _cachedCharge;
      }

      _cachedCharge = (charges as num).toInt();

      return _cachedCharge;
    } catch (e) {
      return _cachedCharge;
    }
  }

  static void updateCharge(int charge) {
    _cachedCharge = charge;
  }

  static void clearCache() {
    _cachedCharge = null;
    _cachedLocationId = null;
  }
}
