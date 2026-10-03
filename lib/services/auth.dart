import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class Auth {
  final FirebaseAuth _authService = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, String> _roleCache = {};

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
    _roleCache.clear();
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

  String? getCachedRole(String uid) => _roleCache[uid];

  Future<String?> getUserRole(String uid) async {
    if (_roleCache.containsKey(uid)) {
      return _roleCache[uid];
    }

    final document = await _firestore.collection('users').doc(uid).get();

    if (!document.exists) {
      return null;
    }

    final data = document.data();
    final role = data?['role'] as String?;

    if (role != null) {
      _roleCache[uid] = role;
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

      if (operator == null) {
        throw Exception('Operator account could not be created.');
      }

      await _firestore.collection('users').doc(operator.uid).set({
        'firstName': name,
        'email': email,
        'location': locationId,
        'role': 'operator',
        'disabled': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await secondaryAuth.signOut();

      await secondaryApp.delete();
      secondaryApp = null;

      return operator;
    } on FirebaseException {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }

      rethrow;
    } catch (e) {
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
