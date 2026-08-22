import 'package:flutter/material.dart';

import 'carin_screen.dart';

// ============================================================
// OperatorDashboardBody
// ------------------------------------------------------------
// This is ONLY the inside content of the Operator Dashboard
// screen (stat cards + Car In/Out buttons + Recent Activity).
//
// It does NOT include the Sidebar or the AppBar — just drop
// this widget inside the "body" of your existing Scaffold,
// next to your sidebar.
//
// Example usage:
//
// Scaffold(
//   appBar: MyAppBar(),
//   body: Row(
//     children: [
//       MySidebar(),
//       Expanded(child: OperatorDashboardBody()),
//     ],
//   ),
// )
// ============================================================
class OperatorDashboardBody extends StatelessWidget {
  final VoidCallback onCarIn;

  const OperatorDashboardBody({
    super.key,
    required this.onCarIn,
  });

  @override
  Widget build(BuildContext context) {
    // Background stays white, matching AppTheme.scaffoldBackgroundColor.
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // We use the available width to decide how many stat
          // cards fit per row, and whether the two big action
          // buttons should sit side-by-side or stack.
          final double width = constraints.maxWidth;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatCardsRow(width: width),
                const SizedBox(height: 20),
                _ActionButtonsRow(
                  width: width,
                  onCarIn: onCarIn,
                ),
                const SizedBox(height: 20),
                const _RecentActivityCard(),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// Row of 4 stat cards: Cars Inside, Today's Entries,
// Today's Exits, Today's Revenue.
// ============================================================
class _StatCardsRow extends StatelessWidget {
  final double width;

  const _StatCardsRow({required this.width});

  @override
  Widget build(BuildContext context) {
    // TODO: Replace these hardcoded values with real data
    // (e.g. from Firestore) once backend is wired up.
    final stats = const [
      _StatData(label: 'CARS INSIDE', value: '142'),
      _StatData(label: "TODAY'S ENTRIES", value: '85'),
      _StatData(label: "TODAY'S EXITS", value: '72'),
      _StatData(label: "TODAY'S REVENUE", value: 'Rs. 18,400'),
    ];

    // Decide how many cards fit per row based on window width.
    // Desktop windows can be resized, so we keep this flexible
    // instead of hardcoding a fixed number of columns.
    int columns;
    if (width >= 950) {
      columns = 4;
    } else if (width >= 650) {
      columns = 2;
    } else {
      columns = 1;
    }

    const double spacing = 16;
    final double cardWidth =
        (width - (spacing * (columns - 1))) / columns;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: stats
          .map((stat) => SizedBox(
        width: cardWidth,
        child: _StatCard(data: stat),
      ))
          .toList(),
    );
  }
}

class _StatData {
  final String label;
  final String value;

  const _StatData({required this.label, required this.value});
}

class _StatCard extends StatelessWidget {
  final _StatData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Small grey uppercase label, e.g. "CARS INSIDE"
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Color(0xFF757575),
            ),
          ),
          const SizedBox(height: 10),
          // Big bold number/value in the theme's primary green.
          Text(
            data.value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtonsRow extends StatelessWidget {
  final double width;
  final VoidCallback onCarIn;

  const _ActionButtonsRow({
    required this.width,
    required this.onCarIn,
  });

  @override
  Widget build(BuildContext context) {
    // On very narrow windows, stack the buttons instead of
    // squeezing them side by side.
    final bool stackVertically = width < 600;

    final carIn = _ActionButton(
      icon: Icons.directions_car,
      label: 'CAR IN',
      color: Theme.of(context).colorScheme.primary,
      onTap: onCarIn,
    );

    final carOut = _ActionButton(
      icon: Icons.exit_to_app,
      label: 'CAR OUT',
      // Slightly darker shade so the two buttons read as distinct,
      // matching the screenshot (Car Out is a touch darker).
      color: const Color(0xFF14401A),
      onTap: () {
        // TODO: Hook this up to your Car Out exit flow.
      },
    );

    if (stackVertically) {
      return Column(
        children: [
          carIn,
          const SizedBox(height: 16),
          carOut,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: carIn),
        const SizedBox(width: 16),
        Expanded(child: carOut),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 220,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 56, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Recent Activity card with a list of IN/OUT entries.
// ============================================================
class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with a real-time Firestore stream of the
    // latest vehicle entry/exit logs.
    final activities = const [
      _ActivityData(
        type: ActivityType.entry,
        plateNumber: 'MH 12 AB 1234',
        subtitle: 'Gate 1 - Valet: Mike',
        time: '2 mins ago',
      ),
      _ActivityData(
        type: ActivityType.exit,
        plateNumber: 'DL 01 CD 5678',
        subtitle: 'Gate 2 - Valet: Sarah',
        time: '15 mins ago',
        amount: 'Rs. 400',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          // Divider between each activity row, using a ListView
          // separator so it's easy to grow this list later.
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (context, index) => const Divider(
              height: 24,
              color: Color(0xFFEEEEEE),
            ),
            itemBuilder: (context, index) {
              return _ActivityRow(data: activities[index]);
            },
          ),
        ],
      ),
    );
  }
}

enum ActivityType { entry, exit }

class _ActivityData {
  final ActivityType type;
  final String plateNumber;
  final String subtitle;
  final String time;
  final String? amount; // Only set for exits that have a fee.

  const _ActivityData({
    required this.type,
    required this.plateNumber,
    required this.subtitle,
    required this.time,
    this.amount,
  });
}

class _ActivityRow extends StatelessWidget {
  final _ActivityData data;

  const _ActivityRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final bool isEntry = data.type == ActivityType.entry;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // IN / OUT chip
        _ActivityChip(isEntry: isEntry),
        const SizedBox(width: 12),
        // Plate number + gate/valet subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.plateNumber,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF757575),
                ),
              ),
            ],
          ),
        ),
        // Time (and amount, for exits) on the right.
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (data.amount != null)
              Text(
                data.amount!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            if (data.amount != null) const SizedBox(height: 2),
            Text(
              data.time,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9E9E9E),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActivityChip extends StatelessWidget {
  final bool isEntry;

  const _ActivityChip({required this.isEntry});

  @override
  Widget build(BuildContext context) {
    // Green chip for IN, red chip for OUT.
    final Color bgColor =
    isEntry ? const Color(0xFFE3F5E6) : const Color(0xFFFBE4E4);
    final Color textColor =
    isEntry ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isEntry ? 'IN' : 'OUT',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}