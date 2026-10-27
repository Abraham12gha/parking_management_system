import 'tenant_context.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_data_cache.dart';

class ParkingChargeService {
  static int? _cachedCharge;
  static String? _cachedLocationId;
  static String? _cachedCompanyId;

  static void _ensureTenantCache() {
    final companyId = TenantContext.instance.companyId;
    if (_cachedCompanyId != companyId) {
      _cachedCharge = null;
      _cachedLocationId = null;
      _cachedCompanyId = companyId;
    }
  }

  static int? get cachedCharge {
    _ensureTenantCache();
    if (AppDataCache.instance.isLoaded &&
        AppDataCache.instance.parkingCharges > 0) {
      return AppDataCache.instance.parkingCharges;
    }
    return _cachedCharge;
  }

  static Future<int?> loadCharge({bool forceRefresh = false}) async {
    _ensureTenantCache();
    if (AppDataCache.instance.isLoaded &&
        AppDataCache.instance.parkingCharges > 0 &&
        !forceRefresh) {
      return AppDataCache.instance.parkingCharges;
    }
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
        final userDocument = await TenantContext.instance
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
      final locationDocument = await TenantContext.instance
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
      _cachedCompanyId = TenantContext.instance.companyId;

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
    _cachedCompanyId = null;
  }
}
