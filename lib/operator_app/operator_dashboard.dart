import 'package:flutter/material.dart';

import '../services/auth.dart';

class OperatorDashboard extends StatelessWidget {
  const OperatorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
     Auth _auth = Auth();
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            const Text(
              'OPERATOR DASHBOARD',
              style: TextStyle(fontSize: 30),
            ),
            ElevatedButton(
                onPressed: (){
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