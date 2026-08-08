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

      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        return {
          'user': user,
          'role': doc.data()?['role'] ?? 'user',
        };
      }

      return null;
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
