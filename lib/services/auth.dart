import 'tenant_context.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class Auth {
  final FirebaseAuth _authService = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // LOGIN
  // ============================================================

  Future<User?> login(String email, String password) async {
    final userCredential = await _authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return userCredential.user;
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    TenantContext.instance.clear();
    await _authService.signOut();
  }

  // Future<void> logoutOnAppStart() async {
  //   if (_authService.currentUser != null) {
  //     await _authService.signOut();
  //   }
  // }

  // ============================================================
  // CURRENT USER
  // ============================================================

  User? get currentUser {
    return _authService.currentUser;
  }

  // ============================================================
  // GET USER ROLE
  // ============================================================

  Future<String?> getUserRole(String uid) async {
    final platformAdmin = await _firestore
        .collection('platform_admins')
        .doc(uid)
        // Role grants must come from the live database, not a stale local
        // Firestore cache after the platform-admin record is provisioned.
        .get(const GetOptions(source: Source.server));
    final platformAdminEnabled = platformAdmin.data()?['enabled'];
    final platformAdminFields = platformAdmin.data()?.keys.toList() ?? const <String>[];
    if (platformAdminEnabled == true) {
      TenantContext.instance.clear();
      return 'superAdmin';
    }

    // Account creation emits authStateChanges before the signup batch has
    // finished writing its tenant membership. Allow that batch to complete.
    for (var attempt = 0; ; attempt++) {
      try {
        await TenantContext.instance.loadForCurrentUser(force: true);
        break;
      } on StateError catch (error) {
        if (!error.message.toString().contains('not assigned')) rethrow;
        if (attempt >= 10) {
          throw StateError(
            '${error.message} Platform-admin lookup: '
            'project=${_firestore.app.options.projectId}, '
            'document=platform_admins/$uid, '
            'exists=${platformAdmin.exists}, '
            'enabled=$platformAdminEnabled, '
            'fields=$platformAdminFields.',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    switch (TenantContext.instance.companyStatus) {
      case 'pending':
        return 'companyPending';
      case 'suspended':
        return TenantContext.instance.role == 'admin'
            ? 'companySuspendedAdmin'
            : 'companySuspendedOperator';
      case 'expired':
        return TenantContext.instance.role == 'admin'
            ? 'companyExpiredAdmin'
            : 'companyExpiredOperator';
      case 'active':
        break;
      default:
        throw StateError('This company has an invalid status.');
    }
    final document = await TenantContext.instance.userDocument(uid).get();

    if (!document.exists) {
      return null;
    }

    final data = document.data();
    final role = data?['role'] as String?;
    if (role != TenantContext.instance.role ||
        (data?['status'] != null && data?['status'] != 'active') ||
        data?['disabled'] == true) {
      throw StateError(
        'This user account is disabled or has inconsistent company access.',
      );
    }

    return role;
  }

  // ============================================================
  // CREATE OPERATOR
  // ============================================================

  Future<User?> addOperator(
    String name,
    String email,
    String password,
    String locationId,
  ) async {
    FirebaseApp? secondaryApp;
    User? createdOperator;
    var membershipWritten = false;

    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'operatorCreation',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final operatorCred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final operator = operatorCred.user;
      createdOperator = operator;

      if (operator == null) {
        throw Exception('Operator account could not be created.');
      }

      final companyId = TenantContext.instance.companyId;
      if (companyId == null)
        throw StateError('Company membership is unavailable.');
      final batch = _firestore.batch();
      batch.set(TenantContext.instance.userDocument(operator.uid), {
        'companyId': companyId,
        'firstName': name,
        'email': email,
        'location': locationId,
        'role': 'operator',
        'status': 'active',
        'disabled': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(_firestore.collection('tenant_users').doc(operator.uid), {
        'companyId': companyId,
        'role': 'operator',
        'status': 'active',
        'name': name,
        'email': email,
        'location': locationId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      membershipWritten = true;

      await secondaryAuth.signOut();

      await secondaryApp.delete();
      secondaryApp = null;

      return operator;
    } on FirebaseException {
      if (secondaryApp != null) {
        if (createdOperator != null && !membershipWritten) {
          try {
            await FirebaseAuth.instanceFor(app: secondaryApp).currentUser?.delete();
          } catch (_) {}
        }
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }

      rethrow;
    } catch (e) {
      if (secondaryApp != null) {
        if (createdOperator != null && !membershipWritten) {
          try {
            await FirebaseAuth.instanceFor(app: secondaryApp).currentUser?.delete();
          } catch (_) {}
        }
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }

      rethrow;
    }
  }

  Future<User?> registerCompanyAdmin({
    required String companyName,
    required String email,
    required String password,
    required String billingCycle,
  }) async {
    final credential = await _authService.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw StateError('Account could not be created.');
    try {
      await TenantContext.instance.createCompanyForCurrentUser(
        name: companyName,
        billingCycle: billingCycle,
      );
    } catch (_) {
      TenantContext.instance.clear();
      await user.delete();
      rethrow;
    }
    return user;
  }

  Future<void> createCompanyWithFirstAdmin({
    required String companyName,
    required String email,
    required String password,
    required String billingCycle,
  }) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null)
      throw StateError('Sign in as a platform admin first.');
    final platformAdmin = await _firestore
        .collection('platform_admins')
        .doc(currentUser.uid)
        .get();
    if (platformAdmin.data()?['enabled'] != true) {
      throw StateError('This account is not a platform admin.');
    }
    FirebaseApp? secondaryApp;
    User? createdUser;
    var companyWritten = false;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'companyCreation',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      createdUser = (await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      )).user;
      if (createdUser == null)
        throw StateError('Company admin account could not be created.');

      final companyRef = _firestore.collection('companies').doc();
      final memberRef = _firestore
          .collection('tenant_users')
          .doc(createdUser.uid);
      final profileRef = companyRef.collection('users').doc(createdUser.uid);
      final batch = _firestore.batch();
      batch.set(companyRef, {
        'name': companyName.trim(),
        'plan': billingCycle,
        'billingCycle': billingCycle,
        'planPriceUsd': billingCycle == 'yearly' ? 600 : 50,
        'paymentStatus': 'pending',
        'status': 'pending',
        'ownerUid': createdUser.uid,
        'limits': <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(memberRef, {
        'companyId': companyRef.id,
        'role': 'admin',
        'status': 'active',
        'name': '',
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(profileRef, {
        'companyId': companyRef.id,
        'firstName': '',
        'email': email.trim(),
        'role': 'admin',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      companyWritten = true;
      try {
        await secondaryAuth.signOut();
      } catch (_) {}
      try {
        await secondaryApp.delete();
      } catch (_) {}
      secondaryApp = null;
    } catch (error) {
      if (createdUser != null && !companyWritten) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  // ============================================================
  // CHANGE CURRENT USER PASSWORD
  // ============================================================

  Future<void> changeMyPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _authService.currentUser;

    if (user == null) {
      throw Exception('No user is currently signed in.');
    }

    if (user.email == null || user.email!.isEmpty) {
      throw Exception('The current account does not have an email address.');
    }

    if (newPassword.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    // Re-authenticate first.
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);

    // Then change the password.
    await user.updatePassword(newPassword);
  }
}
