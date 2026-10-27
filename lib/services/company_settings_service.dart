import 'tenant_context.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_settings.dart';

class CompanySettingsService {
  CompanySettingsService._();

  static final CompanySettingsService instance = CompanySettingsService._();

  static const String _collection = 'app_settings';
  static const String _document = 'general';

  DocumentReference<Map<String, dynamic>> get _documentReference {
    return TenantContext.instance.collection(_collection).doc(_document);
  }

  Future<AppSettings> _withCompanyName(Map<String, dynamic>? data) async {
    final company = await TenantContext.instance.companyDocument().get();
    final name = company.data()?['name']?.toString().trim();
    final tenantName = name?.isNotEmpty == true ? name! : 'Parking Management';
    if (data == null) return AppSettings(appName: tenantName);
    final settings = AppSettings.fromMap(data);
    // Replace the legacy generic default for tenants that predate branding setup.
    final configuredName = data['appName']?.toString().trim();
    if (configuredName == null || configuredName.isEmpty || configuredName == 'My Admin App') {
      return AppSettings(
        appName: tenantName,
        logoUrl: settings.logoUrl,
        email: settings.email,
        phone: settings.phone,
      );
    }
    return settings;
  }

  Future<AppSettings> getSettings() async {
    final snapshot = await _documentReference.get();

    if (!snapshot.exists || snapshot.data() == null) {
      // Older tenant records may not have been initialized with a branding
      // document. Use the company name instead of showing the app-wide default.
      return _withCompanyName(null);
    }

    return _withCompanyName(snapshot.data());
  }

  Stream<AppSettings> watchSettings() {
    return _documentReference.snapshots().asyncMap((snapshot) async {
      final data = snapshot.data();
      return _withCompanyName(data);
    });
  }

  Future<void> updateSettings({
    String? appName,
    String? logoUrl,
    String? email,
    String? phone,
  }) async {
    final Map<String, dynamic> data = {
      if (appName != null) 'appName': appName,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _documentReference.set(data, SetOptions(merge: true));
  }

  Future<void> updateAppName(String appName) async {
    await updateSettings(appName: appName);
  }

  Future<void> updateLogoUrl(String logoUrl) async {
    await updateSettings(logoUrl: logoUrl);
  }

  Future<void> updateContactInfo({String? email, String? phone}) async {
    await updateSettings(email: email, phone: phone);
  }
}
