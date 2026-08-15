// import 'package:flutter/material.dart';
// import 'package:parking_management_system/services/auth.dart';
//
// class AdminDashboard extends StatefulWidget {
//   const AdminDashboard({super.key});
//
//   @override
//   State<AdminDashboard> createState() => _AdminDashboardState();
// }
//
// class _AdminDashboardState extends State<AdminDashboard> {
//   @override
//   Widget build(BuildContext context) {
//     final Auth _auth = Auth();
//     return Scaffold(
//       body: Center(
//         child: Column(
//           children: [
//             const Text(
//               'ADMIN DASHBOARD',
//               style: TextStyle(fontSize: 30),
//             ),
//             ElevatedButton(
//                 onPressed: () {
//                   _auth.logout();
//                 },
//                 child: const Text("logout")
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }



import 'package:flutter/material.dart';
import 'package:parking_management_system/services/auth.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final Auth _auth = Auth();

  int selectedIndex = 0;

  final List<String> menuItems = [
    'Dashboard',
    'Users',
    'Parking',
    'Reports',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // =========================
          // SIDEBAR
          // =========================
          Container(
            width: 250,
            color: Colors.blueGrey.shade900,
            child: Column(
              children: [
                // Logo / App name
                Container(
                  height: 80,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: const Text(
                    'PARKING ADMIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const Divider(
                  color: Colors.white24,
                ),

                // Menu
                Expanded(
                  child: ListView.builder(
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final isSelected = selectedIndex == index;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: Icon(
                            _getMenuIcon(index),
                            color: Colors.white,
                          ),
                          title: Text(
                            menuItems[index],
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              selectedIndex = index;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Logout
                const Divider(
                  color: Colors.white24,
                ),

                ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  onTap: () {
                    _auth.logout();
                  },
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),

          // =========================
          // MAIN CONTENT
          // =========================
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Container(
            height: 70,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 30),
            color: Colors.white,
            alignment: Alignment.centerLeft,
            child: Text(
              menuItems[selectedIndex],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Page content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: _getPageContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getPageContent() {
    switch (selectedIndex) {
      case 0:
        return const Center(
          child: Text(
            'Welcome to Admin Dashboard',
            style: TextStyle(fontSize: 30),
          ),
        );

      case 1:
        return const Center(
          child: Text(
            'Users',
            style: TextStyle(fontSize: 30),
          ),
        );

      case 2:
        return const Center(
          child: Text(
            'Parking',
            style: TextStyle(fontSize: 30),
          ),
        );

      case 3:
        return const Center(
          child: Text(
            'Reports',
            style: TextStyle(fontSize: 30),
          ),
        );

      case 4:
        return const Center(
          child: Text(
            'Settings',
            style: TextStyle(fontSize: 30),
          ),
        );

      default:
        return const SizedBox();
    }
  }

  IconData _getMenuIcon(int index) {
    switch (index) {
      case 0:
        return Icons.dashboard;
      case 1:
        return Icons.people;
      case 2:
        return Icons.local_parking;
      case 3:
        return Icons.bar_chart;
      case 4:
        return Icons.settings;
      default:
        return Icons.circle;
    }
  }
}