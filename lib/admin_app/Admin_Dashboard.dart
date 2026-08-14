import 'package:flutter/material.dart';
import 'package:parking_management_system/services/auth.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    final Auth _auth = Auth();
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            const Text(
              'ADMIN DASHBOARD',
              style: TextStyle(fontSize: 30),
            ),
            ElevatedButton(
                onPressed: () {
                  _auth.logout();
                },
                child: const Text("logout")
            )
          ],
        ),
      ),
    );
  }
}