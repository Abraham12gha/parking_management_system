import 'package:flutter/material.dart';
import 'admin_dashboard_screen.dart';

class DashboardScreen extends StatelessWidget {
  final void Function(int index)? onNavigate;

  const DashboardScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return AdminDashboardScreen(onNavigate: onNavigate);
  }
}
