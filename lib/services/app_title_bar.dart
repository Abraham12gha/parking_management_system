import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../app_settings.dart';
import '../resources/widget/company_logo.dart';
import 'company_settings_service.dart';

class AdminTitleBar extends StatefulWidget {
  const AdminTitleBar({super.key});

  @override
  State<AdminTitleBar> createState() => _AdminTitleBarState();
}

class _AdminTitleBarState extends State<AdminTitleBar> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _readWindowState();
  }

  Future<void> _readWindowState() async {
    final maximized = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = maximized);
  }

  Future<void> _toggleMaximize() async {
    final maximized = await windowManager.isMaximized();
    if (maximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    if (mounted) setState(() => _isMaximized = !maximized);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surface,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 258,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CompanyLogo(
                        size: 28,
                        fallbackColor: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: StreamBuilder<AppSettings>(
                        stream: CompanySettingsService.instance.watchSettings(),
                        builder: (context, snapshot) {
                          final configuredName = snapshot.data?.appName.trim();
                          final title =
                              configuredName == null ||
                                  configuredName.isEmpty ||
                                  configuredName == 'My Admin App'
                              ? 'Parking Management'
                              : configuredName;
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              Text(
                                'PARKING OPERATIONS',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 9,
                                  letterSpacing: 1.05,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: DragToMoveArea(
                child: Container(
                  height: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        'Workspace',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _WindowButton(
              label: 'Minimize',
              icon: Icons.remove_rounded,
              onPressed: windowManager.minimize,
            ),
            _WindowButton(
              label: _isMaximized ? 'Restore' : 'Maximize',
              icon: _isMaximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              onPressed: _toggleMaximize,
            ),
            _WindowButton(
              label: 'Close',
              icon: Icons.close_rounded,
              isClose: true,
              onPressed: windowManager.close,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hoverColor = widget.isClose
        ? const Color(0xFFE5484D)
        : colors.surfaceContainerHighest;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Semantics(
        button: true,
        label: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: 46,
            height: 53,
            color: _hovering ? hoverColor : Colors.transparent,
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: 17,
              color: _hovering && widget.isClose
                  ? Colors.white
                  : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
