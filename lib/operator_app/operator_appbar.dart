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
              child: _SearchField(foreground: foreground),
            ),
          const SizedBox(width: 12),
          _IconBadge(icon: Icons.notifications_none_rounded, color: foreground, onTap: () {}),
          const SizedBox(width: 8),
          _ProfileMenu(
            userName: userName,
            userEmail: userEmail,
            foreground: foreground,
            onProfileTap: onProfileTap,
            onLogout: onLogout,
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.foreground});

  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: foreground.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        style: TextStyle(color: foreground, fontSize: 14),
        cursorColor: foreground,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search...',
          hintStyle: TextStyle(color: foreground.withOpacity(0.6), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: foreground.withOpacity(0.75), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color, this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 23),
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Color(0xFFEF5350), shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({
    required this.userName,
    required this.userEmail,
    required this.foreground,
    this.onProfileTap,
    this.onLogout,
  });

  final String userName;
  final String userEmail;
  final Color foreground;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'profile') onProfileTap?.call();
        if (value == 'logout') onLogout?.call();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(userEmail, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'profile', child: Text('My Profile')),
        const PopupMenuItem(value: 'logout', child: Text('Logout')),
      ],
      child: CircleAvatar(
        radius: 18,
        backgroundColor: foreground.withOpacity(0.15),
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
          style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}