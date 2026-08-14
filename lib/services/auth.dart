import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Auth {
  final _authService = FirebaseAuth.instance;

  Future<Map<String, dynamic>?> login(
      String email,
      String password,
      ) async {
    try {
      final userCred = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCred.user;

      if (user == null) {
        return null;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        throw Exception(
          'User profile not found in Firestore for UID: ${user.uid}',
        );
      }

      final data = doc.data();

      if (data == null) {
        throw Exception('User profile data is empty.');
      }

      final role = data['role'];


      if (role != 'admin' && role != 'operator') {
        throw Exception(
          'Invalid role in Firestore: "$role"',
        );
      }

      return {
        'user': user,
        'role': role,
      };
    } on FirebaseAuthException {
      rethrow;
    }
  }

//   logout
  Future<void> logout() async {
    try {
      await _authService.signOut();
    } catch (e) {
      rethrow;
    }
  }


//   Password reset  button

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(
        email: email,
      );
    } on FirebaseAuthException {
      rethrow;
    }
  }




}

