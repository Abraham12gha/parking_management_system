import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Search presentation shared by both role workspaces. Results are read from
/// the existing ticket, archive, operator and location collections.
class AppGlobalSearch extends StatefulWidget {
  const AppGlobalSearch({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  State<AppGlobalSearch> createState() => _AppGlobalSearchState();
}

class _AppGlobalSearchState extends State<AppGlobalSearch> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _SearchResultsDialog(query: query, isAdmin: widget.isAdmin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: TextField(
        controller: _controller,
        onSubmitted: (_) => _search(),
        textInputAction: TextInputAction.search,
        style: TextStyle(color: colors.onSurface, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.isAdmin
              ? 'Search tickets, operators, locations'
              : 'Search vehicles or tickets',
          prefixIcon: Icon(
            Icons.search_rounded,
            color: colors.onSurfaceVariant,
            size: 19,
          ),
          suffixIcon: IconButton(
            tooltip: 'Search',
            onPressed: _search,
            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _SearchResultsDialog extends StatefulWidget {
  const _SearchResultsDialog({required this.query, required this.isAdmin});
  final String query;
  final bool isAdmin;

  @override
  State<_SearchResultsDialog> createState() => _SearchResultsDialogState();
}

class _SearchResultsDialogState extends State<_SearchResultsDialog> {
  late final Future<List<_SearchResult>> _results = _load();

  Future<List<_SearchResult>> _load() async {
    final db = FirebaseFirestore.instance;
    final q = widget.query.toLowerCase();
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[
      db.collection('parking_tickets').get(),
      db.collection('backup').get(),
    ];
    if (widget.isAdmin) {
      futures.add(db.collection('users').get());
      futures.add(db.collection('locations').get());
    }
    final snapshots = await Future.wait(futures);
    final results = <_SearchResult>[];
    final seenTickets = <String>{};
    for (final snapshot in snapshots.take(2)) {
      for (final doc in snapshot.docs) {
        final d = doc.data();
        final plate = '${d['vehicleNumber'] ?? ''}';
        final ticket = '${d['ticketNumber'] ?? ''}';
        // Completed tickets are mirrored in the archive while their original
        // document remains in parking_tickets. Present each ticket only once.
        final uniqueKey = ticket.isNotEmpty ? ticket : doc.id;
        if (!seenTickets.add(uniqueKey)) continue;
        if (plate.toLowerCase().contains(q) ||
            ticket.toLowerCase().contains(q)) {
          final start = _asDate(d['startTime']);
          final end = _asDate(d['endTime']);
          final category = '${d['vehicleCategory'] ?? 'Vehicle'}';
          final location = '${d['locationName'] ?? ''}';
          results.add(
            _SearchResult(
              title: plate.isEmpty ? ticket : plate,
              subtitle:
                  '$ticket  ·  $category${location.isEmpty ? '' : '  ·  $location'}',
              detail:
                  'Entry: ${_format(start)}   •   Exit: ${end == null ? 'Still parked' : _format(end)}',
              time: start ?? end,
              group: 'Vehicle tickets',
            ),
          );
        }
      }
    }
    if (widget.isAdmin && snapshots.length > 2) {
      for (final doc in snapshots[2].docs) {
        final d = doc.data();
        final role = '${d['role'] ?? ''}'.toLowerCase();
        if (role != 'operator') continue;
        final name = '${d['firstName'] ?? d['name'] ?? ''}';
        final email = '${d['email'] ?? ''}';
        if (name.toLowerCase().contains(q) || email.toLowerCase().contains(q)) {
          results.add(
            _SearchResult(
              title: name.isEmpty ? email : name,
              subtitle: email,
              detail: 'Operator',
              time: _asDate(d['createdAt']),
              group: 'Operators',
            ),
          );
        }
      }
      if (snapshots.length > 3) {
        for (final doc in snapshots[3].docs) {
          final d = doc.data();
          final name = '${d['locationName'] ?? ''}';
          if (name.toLowerCase().contains(q)) {
            results.add(
              _SearchResult(
                title: name,
                subtitle: 'Parking location',
                detail: '',
                time: _asDate(d['createdAt']),
                group: 'Locations',
              ),
            );
          }
        }
      }
    }
    results.sort(
      (a, b) => (b.time ?? DateTime(2000)).compareTo(a.time ?? DateTime(2000)),
    );
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      child: SizedBox(
        width: 720,
        height: 620,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search results',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '“${widget.query}”',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            Expanded(
              child: FutureBuilder<List<_SearchResult>>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Search could not be completed. ${snapshot.error}',
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final records = snapshot.data!;
                  if (records.isEmpty) {
                    return const Center(
                      child: Text('No matching records found.'),
                    );
                  }
                  final buckets = <String, List<_SearchResult>>{};
                  for (final r in records) {
                    final group = r.group == 'Vehicle tickets'
                        ? _ageLabel(r.time)
                        : r.group;
                    buckets.putIfAbsent(group, () => []).add(r);
                  }
                  const order = [
                    'Recent',
                    '1 day ago',
                    '7 days ago',
                    '1 month ago',
                    '5 months ago',
                    '10 months ago',
                    '1 year ago',
                    'Operators',
                    'Locations',
                  ];
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                    children: [
                      for (final section in order.where(
                        buckets.containsKey,
                      )) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 6),
                          child: Text(
                            section,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: colors.primary),
                          ),
                        ),
                        for (final r in buckets[section]!)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              r.group == 'Vehicle tickets'
                                  ? Icons.directions_car_outlined
                                  : r.group == 'Operators'
                                  ? Icons.badge_outlined
                                  : Icons.location_on_outlined,
                              color: colors.onSurfaceVariant,
                            ),
                            title: Text(
                              r.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.subtitle),
                                if (r.detail.isNotEmpty) Text(r.detail),
                              ],
                            ),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResult {
  const _SearchResult({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.time,
    required this.group,
  });
  final String title, subtitle, detail, group;
  final DateTime? time;
}

DateTime? _asDate(dynamic value) => value is Timestamp
    ? value.toDate()
    : value is DateTime
    ? value
    : null;
String _format(DateTime? value) => value == null
    ? 'Unknown'
    : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _ageLabel(DateTime? value) {
  if (value == null) return '1 year ago';
  final days = DateTime.now().difference(value).inDays;
  if (days < 1) return 'Recent';
  if (days < 2) return '1 day ago';
  if (days < 8) return '7 days ago';
  if (days < 45) return '1 month ago';
  if (days < 210) return '5 months ago';
  if (days < 400) return '10 months ago';
  return '1 year ago';
}
