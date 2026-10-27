import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Resolves the signed-in user's tenant from the free-tier membership index.
/// Business data is always accessed below companies/{companyId}.
class TenantContext {
  TenantContext._();

  static final TenantContext instance = TenantContext._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _companyId;
  String? _role;
  String? _uid;
  String? _companyStatus;

  String? get companyId => _companyId;
  String? get role => _role;
  String? get uid => _uid;
  String? get companyStatus => _companyStatus;
  bool get isReady => _companyId != null && _uid != null;

  CollectionReference<Map<String, dynamic>> get _tenantIndex =>
      _firestore.collection('tenant_users');

  DocumentReference<Map<String, dynamic>> membershipDocument(String uid) =>
      _tenantIndex.doc(uid);

  Future<void> loadForCurrentUser({bool force = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      clear();
      throw StateError('Sign in before loading tenant data.');
    }
    if (!force && _uid == user.uid && isReady) return;

    clear();
    final member = await membershipDocument(user.uid).get();
    final data = member.data();
    if (!member.exists || data == null) {
      throw StateError('This account is not assigned to a company.');
    }

    final companyId = data['companyId']?.toString();
    final role = data['role']?.toString();
    final status = data['status']?.toString() ?? 'active';
    if (companyId == null ||
        companyId.isEmpty ||
        !const {'admin', 'operator'}.contains(role)) {
      throw StateError('This account has no valid company membership.');
    }

    final company = await _firestore
        .collection('companies')
        .doc(companyId)
        .get();
    final companyStatus = company.data()?['status']?.toString();
    if (!company.exists ||
        !const {'pending', 'active', 'suspended', 'expired'}.contains(companyStatus)) {
      throw StateError('This company has an invalid status.');
    }
    if (status != 'active') {
      throw StateError('This user account has been disabled.');
    }

    _uid = user.uid;
    _companyId = companyId;
    _role = role;
    _companyStatus = companyStatus;
  }

  CollectionReference<Map<String, dynamic>> collection(
    String name, {
    FirebaseFirestore? firestore,
  }) {
    final companyId = _companyId;
    if (companyId == null) {
      throw StateError('Tenant context is not ready.');
    }
    return (firestore ?? _firestore)
        .collection('companies')
        .doc(companyId)
        .collection(name);
  }

  DocumentReference<Map<String, dynamic>> companyDocument({
    FirebaseFirestore? firestore,
  }) {
    final companyId = _companyId;
    if (companyId == null) throw StateError('Tenant context is not ready.');
    return (firestore ?? _firestore).collection('companies').doc(companyId);
  }

  DocumentReference<Map<String, dynamic>> userDocument(
    String uid, {
    FirebaseFirestore? firestore,
  }) => collection('users', firestore: firestore).doc(uid);

  void clear() {
    _uid = null;
    _companyId = null;
    _role = null;
    _companyStatus = null;
  }

  /// Starts a company account and its first admin membership atomically.
  Future<void> createCompanyForCurrentUser({
    required String name,
    required String billingCycle,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in before creating a company.');
    if (!const {'monthly', 'yearly'}.contains(billingCycle)) {
      throw ArgumentError.value(billingCycle, 'billingCycle');
    }

    final companyRef = _firestore.collection('companies').doc();
    final memberRef = _tenantIndex.doc(user.uid);
    final profileRef = companyRef.collection('users').doc(user.uid);
    final batch = _firestore.batch();
    batch.set(companyRef, {
      'name': name.trim(),
      'plan': billingCycle,
      'billingCycle': billingCycle,
      'planPriceUsd': billingCycle == 'yearly' ? 600 : 50,
      'paymentStatus': 'pending',
      'status': 'pending',
      'limits': <String, dynamic>{},
      'ownerUid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(memberRef, {
      'companyId': companyRef.id,
      'role': 'admin',
      'status': 'active',
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(profileRef, {
      'companyId': companyRef.id,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'role': 'admin',
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    _uid = user.uid;
    _companyId = companyRef.id;
    _role = 'admin';
    _companyStatus = 'pending';
  }
}
