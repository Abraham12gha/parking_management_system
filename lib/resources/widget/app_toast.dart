import 'dart:math' as math;

import 'package:flutter/material.dart';

enum AppToastKind { success, error, warning, information }

/// Application wide toast presentation. Existing operation callbacks can use
/// this without changing their data or service behavior.
class AppToast {
  AppToast._();

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    AppToastKind kind = AppToastKind.information,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: _ToastContent(title: title, message: message, kind: kind),
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        width: math.min(
          460.0,
          math.max(1.0, MediaQuery.sizeOf(context).width - 32),
        ),
      ),
    );
  }

  static void success(BuildContext context, String title, String message) =>
      show(context, title: title, message: message, kind: AppToastKind.success);

  static void error(BuildContext context, String title, String message) => show(
    context,
    title: title,
    message: message,
    kind: AppToastKind.error,
    duration: const Duration(seconds: 6),
  );

  static void warning(BuildContext context, String title, String message) =>
      show(context, title: title, message: message, kind: AppToastKind.warning);

  static void information(BuildContext context, String title, String message) =>
      show(
        context,
        title: title,
        message: message,
        kind: AppToastKind.information,
      );
}

class _ToastContent extends StatelessWidget {
  const _ToastContent({
    required this.title,
    required this.message,
    required this.kind,
  });

  final String title;
  final String message;
  final AppToastKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (color, icon) = switch (kind) {
      AppToastKind.success => (
        colors.tertiary,
        Icons.check_circle_outline_rounded,
      ),
      AppToastKind.error => (colors.error, Icons.error_outline_rounded),
      AppToastKind.warning => (
        const Color(0xFFAA7A2A),
        Icons.warning_amber_rounded,
      ),
      AppToastKind.information => (
        colors.secondary,
        Icons.info_outline_rounded,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 4, color: color),
                const SizedBox(width: 14),
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: colors.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss notification',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  onPressed: () =>
                      ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
