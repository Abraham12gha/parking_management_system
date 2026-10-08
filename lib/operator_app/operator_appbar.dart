import 'package:flutter/material.dart';
import '../resources/widget/app_global_search.dart';

class OperatorAppbar extends StatelessWidget implements PreferredSizeWidget {
  const OperatorAppbar({
    super.key,
    required this.title,
    this.onMenuTap,
    this.userName = ' Operator',
    this.userEmail = 'admin@example.com',
    this.onProfileTap,
    this.onLogout,
    this.showSearch = true,
  });

  final String title;
  final VoidCallback? onMenuTap;
  final String userName;
  final String userEmail;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogout;
  final bool showSearch;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground =
        theme.appBarTheme.foregroundColor ?? colorScheme.onSurface;
    final background = theme.appBarTheme.backgroundColor ?? colorScheme.surface;

    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (onMenuTap != null) ...[
            IconButton(
              onPressed: onMenuTap,
              icon: Icon(Icons.menu_rounded, color: foreground),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          const Spacer(),
          if (showSearch)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360, minWidth: 160),
              child: const AppGlobalSearch(isAdmin: false),
            ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Notifications',
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.notifications_none_rounded,
                color: foreground,
                size: 23,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
