import 'package:flutter/material.dart';

/// Model for a single sidebar navigation item.
class SidebarItem {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const SidebarItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}

class OperatorSidebar extends StatelessWidget {
  const OperatorSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.width = 260,
    this.onLogout,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final double width;
  final VoidCallback? onLogout;

  static const List<SidebarItem> items = [
    SidebarItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: 'Dashboard'),
    SidebarItem(icon: Icons.directions_car, selectedIcon: Icons.directions_car, label: 'Active Vehicles'),
    SidebarItem(icon: Icons.analytics_outlined, selectedIcon: Icons.analytics_outlined, label: 'Reports'),
    SidebarItem(icon: Icons.payments, selectedIcon: Icons.payments, label: 'Payment Methods'),
    SidebarItem(icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart_rounded, label: 'Analytics'),
    SidebarItem(icon: Icons.backup_outlined, selectedIcon: Icons.backup_outlined, label: 'Backup'),
    SidebarItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      color: colorScheme.primary,
      child: SafeArea(
        child: Column(
          children: [
            _Brand(colorScheme: colorScheme),
            Divider(color: colorScheme.onPrimary.withOpacity(0.12), height: 1),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = index == selectedIndex;
                  return _SidebarTile(
                    item: item,
                    selected: selected,
                    colorScheme: colorScheme,
                    onTap: () => onItemSelected(index),
                  );
                },
              ),
            ),
            Divider(color: colorScheme.onPrimary.withOpacity(0.12), height: 1),
            _LogoutTile(colorScheme: colorScheme, onTap: onLogout),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.eco_rounded, color: colorScheme.onPrimary, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            'Operator panel',
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.colorScheme,
    required this.onTap,
  });

  final SidebarItem item;
  final bool selected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? colorScheme.onPrimary.withOpacity(0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: selected ? colorScheme.onPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected ? (item.selectedIcon ?? item.icon) : item.icon,
                  color: colorScheme.onPrimary.withOpacity(selected ? 1 : 0.75),
                  size: 21,
                ),
                const SizedBox(width: 14),
                Text(
                  item.label,
                  style: TextStyle(
                    color: colorScheme.onPrimary.withOpacity(selected ? 1 : 0.85),
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({required this.colorScheme, this.onTap});

  final ColorScheme colorScheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.logout_rounded, color: colorScheme.onPrimary.withOpacity(0.85), size: 20),
                const SizedBox(width: 14),
                Text(
                  'Logout',
                  style: TextStyle(
                    color: colorScheme.onPrimary.withOpacity(0.85),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}