import 'package:flutter/material.dart';

/// A polished top bar for the admin panel.
///
/// Pass [onMenuTap] to show a hamburger icon (used on mobile to open the
/// sidebar drawer). Leave it null on wide/desktop layouts where the
/// sidebar is already permanently visible.
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
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = theme.appBarTheme.foregroundColor ?? colorScheme.onPrimary;
    final background = theme.appBarTheme.backgroundColor ?? colorScheme.primary;

    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
            style: TextStyle(color: foreground, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (showSearch)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}