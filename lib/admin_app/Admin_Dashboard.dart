import 'package:flutter/material.dart';
import 'package:parking_management_system/admin_app/add_operator_admin.dart';
import 'package:parking_management_system/admin_app/settings_admin.dart';
import '../login_screen.dart';
import '../services/auth.dart';
import 'admin_appbar.dart';
import 'admin_sideBar.dart';
import 'dashboard_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Auth _auth = Auth();


  int _selectedIndex = 0;

  static const double _desktopBreakpoint = 1000;

  static const List<String> _titles = [
    'Dashboard',
    'Operator',
    'Locations',
    'Payment',
    'Analytics',
    'Request',
    'Settings',
  ];

  final List<Widget> _pages = [
    DashboardScreen(),
    AddOperator(),
    DashboardScreen(),
    DashboardScreen(),
    DashboardScreen(),
    DashboardScreen(),
    SettingsScreen()
  ];

  void _onItemSelected(int index) {
    setState(() => _selectedIndex = index);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    try {
      await _auth.logout();

      if (!mounted) return;

      // Go back to the login screen.
      // Replace LoginScreen() with your actual login screen widget.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not logout: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;

        return Scaffold(
          key: _scaffoldKey,
          drawer: isDesktop
              ? null
              : Drawer(
            child: AdminSidebar(
              selectedIndex: _selectedIndex,
              onItemSelected: _onItemSelected,
              width: double.infinity,
            ),
          ),
          body: Row(
            children: [
              if (isDesktop)
                AdminSidebar(
                  selectedIndex: _selectedIndex,
                  onItemSelected: _onItemSelected,
                  onLogout: _handleLogout,
                ),
              Expanded(
                child: Column(
                  children: [
                    AdminAppBar(
                      title: _titles[_selectedIndex],
                      onMenuTap: isDesktop ? null : () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    Expanded(
                      child: Container(
                        color: Theme.of(context).colorScheme.surface,
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: _pages,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 42, color: colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            '$label content goes here',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}