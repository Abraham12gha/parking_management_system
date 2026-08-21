import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class Auth {
  final FirebaseAuth _authService = FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // =========================
  // LOGIN
  // =========================

  Future<User?> login(
      String email,
      String password,
      ) async {
    final userCredential =
    await _authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return userCredential.user;
  }

  // =========================
  // LOGOUT
  // =========================

  Future<void> logout() async {
    await _authService.signOut();
  }

  // =========================
  // GET CURRENT USER
  // =========================

  User? get currentUser {
    return _authService.currentUser;
  }

  // =========================
  // GET USER ROLE
  // =========================

  Future<String?> getUserRole(String uid) async {
    final document = await _firestore
        .collection('users')
        .doc(uid)
        .get();

    if (!document.exists) {
      return null;
    }

    final data = document.data();

    return data?['role'] as String?;
  }



  //-------------
  // ADD OPERATOR
  //-------------

  Future<User?> addOperator(
      String name,
      String email,
      String password,
      String location,
      ) async {
    FirebaseApp? secondaryApp;

    try {
      // Create a second Firebase app.
      secondaryApp = await Firebase.initializeApp(
        name: 'operatorCreation',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Use Firebase Auth from the SECOND app.
      final secondaryAuth = FirebaseAuth.instanceFor(
        app: secondaryApp,
      );

      // Create the operator.
      final operatorCred =
      await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final operator = operatorCred.user;

      if (operator == null) {
        throw Exception('Operator account could not be created.');
      }

      // IMPORTANT:
      // Use the MAIN Firestore instance.
      // The admin remains logged into the main Firebase app.
      await _firestore
          .collection('users')
          .doc(operator.uid)
          .set({
        'firstName': name,
        'email': email,
        'location': location,
        'role': 'operator',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sign out from the SECONDARY Firebase Auth.
      await secondaryAuth.signOut();

      // Delete the secondary Firebase app.
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

}