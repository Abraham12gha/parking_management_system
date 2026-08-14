import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parking_management_system/services/auth.dart';


import '../admin_app/Admin_Dashboard.dart';
import '../operator_app/operator_dashboard.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),

      builder: (context, snapshot) {
        // Firebase is checking authentication
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is NOT logged in
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // User IS logged in
        return RoleBasedScreen(
          user: snapshot.data!,
        );
      },
    );
  }
}




class RoleBasedScreen extends StatelessWidget {
  final User user;

  const RoleBasedScreen({
    super.key,
    required this.user,
  });

  static final Auth _auth = Auth();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _auth.getUserRole(user.uid),

      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Unable to load user role.',
              ),
            ),
          );
        }

        final role = snapshot.data;

        switch (role) {
          case 'admin':
            return const AdminDashboard();

          case 'operator':
            return const OperatorDashboard();

          default:
            return const Scaffold(
              body: Center(
                child: Text(
                  'No valid role assigned to this account.',
                ),
              ),
            );
        }
      },
    );
  }
}