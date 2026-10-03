import 'package:flutter/material.dart';
import 'package:parking_management_system/admin_app/add_operator_admin.dart';
import 'package:parking_management_system/admin_app/settings_admin.dart';
import 'package:parking_management_system/operator_app/settings_operator.dart';
import '../auth_wrapper.dart';
import '../login_screen.dart';
import '../services/app_data_cache.dart';
import '../services/auth.dart';
import 'Active_Vehicles_screen.dart';
import 'analytics_screen.dart';
import 'carin_screen.dart';
import 'carout_screen.dart';
import 'oDashboard_screen.dart';
import 'operator_appbar.dart';
import 'operator_sidebar.dart';
import 'out_cars_screen.dart';
import 'reports_screen.dart';

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
    if (_currentPage is CaroutScreen) {
      return 'Car Out';
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
    'Out Cars',
    'Reports',
    'Payment',
    'Analytics',
    'Backup',
    'Settings',
  ];

  late final List<Widget> _pages;
  int _reportVersion = 0;

  @override
  void initState() {
    super.initState();
    // Preload location and active tickets in memory for fast switching
    AppDataCache.instance.preloadForCurrentUser();

    _pages = [
      OperatorDashboardBody(
        onCarIn: _openCarIn,
        onCarOut: _openCarOut,
      ),
      const ActiveVehiclesScreen(),
      const OutCarsScreen(),
      const ReportsScreen(),
      const _PlaceholderPage(
        icon: Icons.payment,
        label: 'Payment',
      ),
      const AnalyticsScreen(),
      const _PlaceholderPage(
        icon: Icons.backup,
        label: 'Backup',
      ),
      const SettingScreenOperator(),
    ];
  }

  void _onItemSelected(int index) {
    // These screens load their report snapshots on mount. Recreate them when
    // opened so a checkout performed elsewhere in the session is reflected.
    if (index == 2 || index == 3 || index == 5) _reportVersion++;
    if (index == 2) {
      _pages[index] = OutCarsScreen(key: ValueKey('outcars-$_reportVersion'));
    }
    if (index == 3) {
      _pages[index] = ReportsScreen(key: ValueKey('reports-$_reportVersion'));
    }
    if (index == 5) {
      _pages[index] = AnalyticsScreen(key: ValueKey('analytics-$_reportVersion'));
    }
    setState(() {
      _selectedIndex = index;
      _currentPage = null;
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
      AppDataCache.instance.clear();
      await _auth.logout();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const AuthWrapper(),
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
  void _openCarOut() {
    setState(() {
      _currentPage = CaroutScreen(
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
                        child: _currentPage ??
                            IndexedStack(
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
