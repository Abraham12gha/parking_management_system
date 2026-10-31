import 'package:flutter/material.dart';
import 'package:parking_management_system/operator_app/settings_operator.dart';
import '../resources/widget/app_toast.dart';
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
    'Analytics',
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
      OperatorDashboardBody(onCarIn: _openCarIn, onCarOut: _openCarOut),
      const ActiveVehiclesScreen(),
      const OutCarsScreen(),
      const ReportsScreen(),
      const AnalyticsScreen(),
      const SettingScreenOperator(),
    ];
  }

  void _onItemSelected(int index) {
    // These screens load their report snapshots on mount. Recreate them when
    // opened so a checkout performed elsewhere in the session is reflected.
    if (index == 2 || index == 3 || index == 4) _reportVersion++;
    if (index == 2) {
      _pages[index] = OutCarsScreen(key: ValueKey('outcars-$_reportVersion'));
    }
    if (index == 3) {
      _pages[index] = ReportsScreen(key: ValueKey('reports-$_reportVersion'));
    }
    if (index == 4) {
      _pages[index] = AnalyticsScreen(
        key: ValueKey('analytics-$_reportVersion'),
      );
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
          content: const Text('Are you sure you want to logout?'),
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

      // The root auth-state listener returns to login and preserves the shell.
    } catch (e) {
      if (!mounted) return;

      AppToast.error(context, 'Could not log out', '$e');
    }
  }

  void _openCarIn() {
    setState(() {
      _currentPage = CarinScreen(onBack: _backToDashboard);
    });
  }

  void _openCarOut() {
    setState(() {
      _currentPage = CaroutScreen(onBack: _backToDashboard);
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
                    OperatorAppbar(title: _currentTitle),
                    Expanded(
                      child: Container(
                        color: Theme.of(context).colorScheme.surface,
                        child:
                            _currentPage ??
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
