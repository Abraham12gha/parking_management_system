import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_settings.dart';

class CompanySettingsService {
  CompanySettingsService._();

  static final CompanySettingsService instance =
  CompanySettingsService._();

  static const String _collection = 'app_settings';
  static const String _document = 'general';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _documentReference {
    return _firestore.collection(_collection).doc(_document);
  }

  Future<AppSettings> getSettings() async {
    final snapshot = await _documentReference.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return const AppSettings();
    }

    return AppSettings.fromMap(snapshot.data()!);
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

    await _documentReference.set(
      data,
      SetOptions(merge: true),
    );
  }

  Future<void> updateAppName(String appName) async {
    await updateSettings(
      appName: appName,
    );
  }

  Future<void> updateLogoUrl(String logoUrl) async {
    await updateSettings(
      logoUrl: logoUrl,
    );
  }

  Future<void> updateContactInfo({
    String? email,
    String? phone,
  }) async {
    await updateSettings(
      email: email,
      phone: phone,
    );
  }
}