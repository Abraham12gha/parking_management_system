import 'package:flutter/material.dart';
import 'package:parking_management_system/admin_app/add_operator_admin.dart';
import 'package:parking_management_system/admin_app/settings_admin.dart';
import 'package:parking_management_system/operator_app/settings_operator.dart';
import '../login_screen.dart';
import '../services/auth.dart';
import 'carin_screen.dart';
import 'oDashboard_screen.dart';
import 'operator_appbar.dart';
import 'operator_sidebar.dart';

class OperatorDashboard extends StatefulWidget {
  const OperatorDashboard({super.key});
  @override
  State<OperatorDashboard> createState() => _OperatorDashboardState();
}

class _OperatorDashboardState extends State<OperatorDashboard> {
  String get _currentTitle {
    if (_currentPage is CarinScreen) {
      return 'Car In';
    }

    return _titles[_selectedIndex];
  }
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Auth _auth = Auth();
  Widget? _currentPage;

  int _selectedIndex = 0;

  static const double _desktopBreakpoint = 1000;

  static const List<String> _titles = [
    'Dashboard',
    'Active Vehicles',
    'Reports',
    'Payment',
    'Analytics',
    'Backup',
    'Settings',
  ];

  void _onItemSelected(int index) {
    setState(() {
      _selectedIndex = index;

      switch (index) {
        case 0:
          _currentPage = null; // Dashboard
          break;

        case 1:
          _currentPage = const _PlaceholderPage(
            icon: Icons.directions_car,
            label: 'Active Vehicles',
          );
          break;

        case 2:
          _currentPage = const _PlaceholderPage(
            icon: Icons.assessment,
            label: 'Reports',
          );
          break;

        case 3:
          _currentPage = const _PlaceholderPage(
            icon: Icons.payment,
            label: 'Payment',
          );
          break;

        case 4:
          _currentPage = const _PlaceholderPage(
            icon: Icons.analytics,
            label: 'Analytics',
          );
          break;

        case 5:
          _currentPage = const _PlaceholderPage(
            icon: Icons.backup,
            label: 'Backup',
          );
          break;

        case 6:
          _currentPage = const SettingScreenOperator();
          break;
      }
    });

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

  void _openCarIn() {
    setState(() {
      _currentPage = CarinScreen(
        onBack: _backToDashboard,
      );
    });
  }
  void _backToDashboard() {
    setState(() {
      _currentPage = null;
    });
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
            child: OperatorSidebar(
              selectedIndex: _selectedIndex,
              onItemSelected: _onItemSelected,
              width: double.infinity,
            ),
          ),
          body: Row(
            children: [
              if (isDesktop)
                OperatorSidebar(
                  selectedIndex: _selectedIndex,
                  onItemSelected: _onItemSelected,
                  onLogout: _handleLogout,
                ),
              Expanded(
                child: Column(
                  children: [
                    OperatorAppbar(
                      title: _currentTitle,
                    ),
                    Expanded(
                      child: Container(
                        color: Theme.of(context).colorScheme.surface,
                        child: _currentPage ?? OperatorDashboardBody(
                          onCarIn: _openCarIn,
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