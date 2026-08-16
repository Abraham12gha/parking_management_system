import 'package:flutter/material.dart';
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
  int _selectedIndex = 0;

  static const double _desktopBreakpoint = 1000;

  static const List<String> _titles = [
    'Dashboard',
    'Operator',
    'Products',
    'Orders',
    'Analytics',
    'Settings',
  ];

  final List<Widget> _pages = [
    DashboardScreen(),
    DashboardScreen(),
    DashboardScreen(),
    DashboardScreen(),
    DashboardScreen(),
    DashboardScreen(),
    DashboardScreen(),
  ];

  void _onItemSelected(int index) {
    setState(() => _selectedIndex = index);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
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