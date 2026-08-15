import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class AdminTitleBar extends StatefulWidget {
  const AdminTitleBar({super.key});

  @override
  State<AdminTitleBar> createState() => _AdminTitleBarState();
}

class _AdminTitleBarState extends State<AdminTitleBar> {
  bool isMaximized = false;

  @override
  void initState() {
    super.initState();

    _checkMaximized();
  }

  Future<void> _checkMaximized() async {
    final maximized = await windowManager.isMaximized();

    if (mounted) {
      setState(() {
        isMaximized = maximized;
      });
    }
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();

      setState(() {
        isMaximized = false;
      });
    } else {
      await windowManager.maximize();

      setState(() {
        isMaximized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          // =========================================================
          // APP BRAND
          // =========================================================

          Container(
            width: 250,
            height: 50,
            color: const Color(0xFF111827),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(
                    Icons.local_parking_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),

                const SizedBox(width: 10),

                const Text(
                  'PARKING MANAGEMENT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // =========================================================
          // DRAGGABLE AREA
          // =========================================================

          Expanded(
            child: DragToMoveArea(
              child: Container(
                height: 50,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Row(
                  children: [
                    Text(
                      'Admin Panel',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // =========================================================
          // MINIMIZE
          // =========================================================

          _WindowButton(
            icon: Icons.remove,
            onPressed: () {
              windowManager.minimize();
            },
          ),

          // =========================================================
          // MAXIMIZE
          // =========================================================

          _WindowButton(
            icon: isMaximized
                ? Icons.filter_none_rounded
                : Icons.crop_square_rounded,
            onPressed: _toggleMaximize,
          ),

          // =========================================================
          // CLOSE
          // =========================================================

          _WindowButton(
            icon: Icons.close,
            isClose: true,
            onPressed: () {
              windowManager.close();
            },
          ),
        ],
      ),
    );
  }
}


// =============================================================
// WINDOW BUTTON
// =============================================================

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,

      onEnter: (_) {
        setState(() {
          hovering = true;
        });
      },

      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },

      child: GestureDetector(
        onTap: widget.onPressed,

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),

          width: 46,
          height: 50,

          color: hovering
              ? widget.isClose
              ? const Color(0xFFDC2626)
              : const Color(0xFFE5E7EB)
              : Colors.transparent,

          child: Icon(
            widget.icon,
            size: 17,

            color: hovering && widget.isClose
                ? Colors.white
                : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}