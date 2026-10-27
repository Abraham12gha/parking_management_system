import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  bool _creating = false;
  final TextEditingController _companySearchController = TextEditingController();
  String _statusFilter = 'all';
  bool _loadingRenewals = true;
  String? _renewalError;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _companiesStream;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _renewalSubscriptions = {};
  final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _pendingByCompany = {};
  final Map<String, String> _companyNames = {};

  List<_PendingRenewal> get _pendingRenewals => [
    for (final entry in _pendingByCompany.entries)
      for (final request in entry.value)
        _PendingRenewal(
          companyId: entry.key,
          companyName: _companyNames[entry.key] ?? 'Company ${entry.key}',
          document: request,
        ),
  ]..sort((a, b) {
      final aTime = a.document.data()['createdAt'];
      final bTime = b.document.data()['createdAt'];
      final aDate = aTime is Timestamp ? aTime.toDate() : DateTime(2000);
      final bDate = bTime is Timestamp ? bTime.toDate() : DateTime(2000);
      return bDate.compareTo(aDate);
    });

  @override
  void initState() {
    super.initState();
    _companiesStream = FirebaseFirestore.instance
        .collection('companies')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void _watchCompanyRenewalRequests(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> companies,
  ) {
    final companyIds = companies.map((doc) => doc.id).toSet();
    for (final removedId in _renewalSubscriptions.keys
        .where((id) => !companyIds.contains(id))
        .toList()) {
      unawaited(_renewalSubscriptions.remove(removedId)?.cancel());
      _pendingByCompany.remove(removedId);
      _companyNames.remove(removedId);
    }

    for (final company in companies) {
      _companyNames[company.id] =
          company.data()['name']?.toString() ?? 'Company ${company.id}';
      if (_renewalSubscriptions.containsKey(company.id)) continue;
      _renewalSubscriptions[company.id] = company.reference
          .collection('billing_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen(
            (requests) {
              if (!mounted) return;
              setState(() {
                _pendingByCompany[company.id] = requests.docs;
                _renewalError = null;
                _loadingRenewals = false;
              });
            },
            onError: (Object error) {
              if (!mounted) return;
              setState(() {
                _renewalError = error.toString();
                _loadingRenewals = false;
              });
            },
          );
    }
    if (companies.isEmpty && mounted && _loadingRenewals) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _loadingRenewals) {
          setState(() => _loadingRenewals = false);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final subscription in _renewalSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _companySearchController.dispose();
    super.dispose();
  }

  Future<void> _showRenewalInbox() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Company requests'),
        content: SizedBox(
          width: 560,
          height: 420,
          child: _loadingRenewals
              ? const Center(child: CircularProgressIndicator())
              : _renewalError != null
                  ? Text('Could not load renewal requests: $_renewalError')
                  : _pendingRenewals.isEmpty
                      ? const Center(child: Text('There are no pending renewal requests.'))
                      : ListView.separated(
                          itemCount: _pendingRenewals.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _pendingRenewals[index];
                            final request = item.document.data();
                            final isSuspensionReview =
                                request['requestType'] == 'suspension_review';
                            final cycle = request['billingCycle'] == 'yearly' ? 'yearly' : 'monthly';
                            final amount = request['amountUsd'] ?? (cycle == 'yearly' ? 600 : 50);
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              title: Text(item.companyName),
                              subtitle: Text(isSuspensionReview
                                  ? 'The company admin requested an access review. Approving restores company access.'
                                  : '${cycle == 'yearly' ? 'Yearly' : 'Monthly'} plan • \$$amount USD\nConfirm the offline payment before approving.'),
                              isThreeLine: true,
                              trailing: FilledButton.tonal(
                                onPressed: () async {
                                  final approved = await _approveRenewal(
                                    item.companyId,
                                    item.document.id,
                                    request,
                                  );
                                  if (approved && dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                },
                                child: Text(isSuspensionReview ? 'Restore access' : 'Approve'),
                              ),
                            );
                          },
                        ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _setCompanyStatus(
    String companyId,
    String status,
    String paymentStatus,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('companies').doc(companyId).update({
        'status': status,
        'paymentStatus': paymentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update company: $error')),
        );
      }
    }
  }

  Future<bool> _approveRenewal(
    String companyId,
    String requestId,
    Map<String, dynamic> request,
  ) async {
    final isSuspensionReview = request['requestType'] == 'suspension_review';
    final cycle = request['billingCycle'] == 'yearly' ? 'yearly' : 'monthly';
    final now = DateTime.now();
    final end = cycle == 'yearly'
        ? DateTime(now.year + 1, now.month, now.day)
        : DateTime(now.year, now.month + 1, now.day);
    final db = FirebaseFirestore.instance;
    try {
      final batch = db.batch();
      batch.update(db.collection('companies').doc(companyId), isSuspensionReview
          ? {'status': 'active', 'updatedAt': FieldValue.serverTimestamp()}
          : {
              'status': 'active',
              'paymentStatus': 'paid',
              'plan': cycle,
              'billingCycle': cycle,
              'planPriceUsd': cycle == 'yearly' ? 600 : 50,
              'subscriptionEndsAt': Timestamp.fromDate(end),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      batch.update(
        db.collection('companies').doc(companyId)
            .collection('billing_requests').doc(requestId),
        {
          'status': 'approved',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
        },
      );
      await batch.commit();
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not approve renewal: $error')),
        );
      }
      return false;
    }
  }

  Future<void> _createCompany() async {
    final formKey = GlobalKey<FormState>();
    final companyName = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    var cycle = 'monthly';
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Create company'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: companyName,
                    decoration: const InputDecoration(
                      labelText: 'Company name',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a company name'
                        : null,
                  ),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'First admin email',
                    ),
                    validator: (value) => value == null || !value.contains('@')
                        ? 'Enter a valid email'
                        : null,
                  ),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Temporary password',
                    ),
                    validator: (value) => value == null || value.length < 6
                        ? 'Use at least 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: cycle,
                    decoration: const InputDecoration(
                      labelText: 'Selected billing cycle',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text('Monthly — \$50 / month'),
                      ),
                      DropdownMenuItem(
                        value: 'yearly',
                        child: Text('Yearly — \$600 / year'),
                      ),
                    ],
                    onChanged: saving
                        ? null
                        : (value) =>
                              setDialogState(() => cycle = value ?? 'monthly'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The payment status starts as pending. This free-tier app does not process or verify payments.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => saving = true);
                      setState(() => _creating = true);
                      try {
                        await Auth().createCompanyWithFirstAdmin(
                          companyName: companyName.text,
                          email: email.text,
                          password: password.text,
                          billingCycle: cycle,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Company and first admin created.'),
                          ),
                        );
                      } catch (error) {
                        if (dialogContext.mounted)
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text('Could not create company: $error'),
                            ),
                          );
                      } finally {
                        if (mounted) setState(() => _creating = false);
                        if (dialogContext.mounted)
                          setDialogState(() => saving = false);
                      }
                    },
              child: Text(saving ? 'Creating…' : 'Create company'),
            ),
          ],
        ),
      ),
    );
    companyName.dispose();
    email.dispose();
    password.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pendingRequests = _pendingRenewals;
    final pendingCount = pendingRequests.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform administration'),
        actions: [
          IconButton(
            tooltip: _renewalError != null
                ? 'Company requests unavailable'
                : pendingCount == 0
                    ? 'Company requests'
                    : '$pendingCount pending company ${pendingCount == 1 ? 'request' : 'requests'}',
            onPressed: _showRenewalInbox,
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text(pendingCount > 99 ? '99+' : '$pendingCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => Auth().logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _companiesStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Could not load companies: ${snapshot.error}'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final companies = snapshot.data!.docs;
            _watchCompanyRenewalRequests(snapshot.data!.docs);
            final activeCount = companies.where((doc) => doc.data()['status'] == 'active').length;
            final awaitingActivationCount = companies.where((doc) => doc.data()['status'] == 'pending').length;
            final attentionCount = companies.where((doc) {
              final status = (doc.data()['status'] ?? 'pending').toString();
              return status != 'active' ||
                  (_pendingByCompany[doc.id]?.isNotEmpty ?? false);
            }).length;
            final query = _companySearchController.text.trim().toLowerCase();
            final filteredCompanies = companies.where((doc) {
              final data = doc.data();
              final status = (data['status'] ?? 'pending').toString();
              final name = (data['name'] ?? '').toString().toLowerCase();
              final matchesQuery = query.isEmpty ||
                  name.contains(query) ||
                  doc.id.toLowerCase().contains(query);
              final matchesStatus = _statusFilter == 'all' || status == _statusFilter;
              return matchesQuery && matchesStatus;
            }).toList()
              ..sort((a, b) {
                int priority(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                  if (_pendingByCompany[doc.id]?.isNotEmpty ?? false) return 0;
                  final status = doc.data()['status']?.toString();
                  if (status == 'pending') return 1;
                  if (status == 'expired' || status == 'suspended') return 2;
                  return 3;
                }
                final priorityDifference = priority(a).compareTo(priority(b));
                if (priorityDifference != 0) return priorityDifference;
                return (a.data()['name'] ?? '').toString().toLowerCase().compareTo(
                      (b.data()['name'] ?? '').toString().toLowerCase(),
                    );
              });

            return LayoutBuilder(
              builder: (context, constraints) {
                final statsWidth = constraints.maxWidth >= 1000
                    ? (constraints.maxWidth - 36) / 4
                    : constraints.maxWidth >= 520
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 20,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Company portfolio', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Manage tenant access, plans, and renewals from one place.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: _creating ? null : _createCompany,
                          icon: const Icon(Icons.add_business_outlined),
                          label: Text(_creating ? 'Creating…' : 'Create company'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(width: statsWidth, child: _summaryCard(context, 'Total companies', companies.length, Icons.apartment_outlined, colors.primary)),
                        SizedBox(width: statsWidth, child: _summaryCard(context, 'Active', activeCount, Icons.check_circle_outline, Colors.green)),
                        SizedBox(width: statsWidth, child: _summaryCard(context, 'Awaiting activation', awaitingActivationCount, Icons.hourglass_top_rounded, Colors.orange)),
                        SizedBox(width: statsWidth, child: _summaryCard(context, 'Needs attention', attentionCount, Icons.priority_high_rounded, Colors.deepOrange)),
                      ],
                    ),
                    if (_renewalError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: MaterialBanner(
                          leading: const Icon(Icons.error_outline),
                          content: Text('Company requests could not load: $_renewalError'),
                          actions: [TextButton(onPressed: () => setState(() {}), child: const Text('Retry'))],
                        ),
                      )
                    else if (pendingCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: MaterialBanner(
                          leading: const Icon(Icons.notifications_active_outlined),
                          content: Text('$pendingCount company ${pendingCount == 1 ? 'request needs' : 'requests need'} your review.'),
                          actions: [TextButton(onPressed: _showRenewalInbox, child: const Text('Review requests'))],
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _companySearchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search by company name or ID',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: colors.surfaceContainerLow,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: constraints.maxWidth < 620 ? 150 : 190,
                          child: DropdownButtonFormField<String>(
                            value: _statusFilter,
                            decoration: InputDecoration(
                              labelText: 'Status',
                              filled: true,
                              fillColor: colors.surfaceContainerLow,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All statuses')),
                              DropdownMenuItem(value: 'active', child: Text('Active')),
                              DropdownMenuItem(value: 'pending', child: Text('Pending')),
                              DropdownMenuItem(value: 'expired', child: Text('Expired')),
                              DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                            ],
                            onChanged: (value) => setState(() => _statusFilter = value ?? 'all'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('Companies', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Text('${filteredCompanies.length} of ${companies.length}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: companies.isEmpty
                          ? _emptyState(context, 'No companies yet', 'Create your first company to get started.')
                          : filteredCompanies.isEmpty
                              ? _emptyState(context, 'No matching companies', 'Try a different search or status filter.')
                              : GridView.builder(
                                  itemCount: filteredCompanies.length,
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 560,
                                    mainAxisExtent: 246,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                  ),
                                  itemBuilder: (context, index) {
                                    final companyDoc = filteredCompanies[index];
                                    return _companyCard(context, companyDoc);
                                  },
                                ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _summaryCard(
    BuildContext context,
    String label,
    int value,
    IconData icon,
    Color tint,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, String title, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.apartment_outlined, size: 38, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _companyCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> companyDoc,
  ) {
    final colors = Theme.of(context).colorScheme;
    final company = companyDoc.data();
    final status = (company['status'] ?? 'pending').toString();
    final paymentStatus = (company['paymentStatus'] ?? 'pending').toString();
    final cycle = company['billingCycle'] == 'yearly' ? 'yearly' : 'monthly';
    final price = cycle == 'yearly' ? 600 : 50;
    final companyRequests = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
      _pendingByCompany[companyDoc.id] ?? const [],
    )..sort((a, b) {
        final aTime = a.data()['createdAt'];
        final bTime = b.data()['createdAt'];
        final aDate = aTime is Timestamp ? aTime.toDate() : DateTime(2000);
        final bDate = bTime is Timestamp ? bTime.toDate() : DateTime(2000);
        return bDate.compareTo(aDate);
      });
    final latestRequest = companyRequests.isEmpty ? null : companyRequests.first;
    final renewalCycle = latestRequest?.data()['billingCycle'] == 'yearly'
        ? 'Yearly'
        : 'Monthly';
    final renewalPrice = latestRequest?.data()['amountUsd'] ??
        (renewalCycle == 'Yearly' ? 600 : 50);
    final statusColor = switch (status) {
      'active' => Colors.green,
      'pending' => Colors.orange,
      'expired' => Colors.deepOrange,
      'suspended' => colors.error,
      _ => colors.outline,
    };

    return Card(
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(Icons.business_outlined, color: colors.onPrimaryContainer, size: 21),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((company['name'] ?? 'Company').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text('ID ${companyDoc.id}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(label: status, color: statusColor),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(icon: Icons.payments_outlined, text: '\$$price / ${cycle == 'yearly' ? 'year' : 'month'}'),
                _InfoPill(icon: Icons.event_repeat_outlined, text: cycle == 'yearly' ? 'Yearly plan' : 'Monthly plan'),
                _InfoPill(icon: paymentStatus == 'paid' ? Icons.verified_outlined : Icons.pending_outlined, text: paymentStatus),
              ],
            ),
            const Spacer(),
            if (latestRequest != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, color: Colors.deepOrange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                    '${latestRequest.data()['requestType'] == 'suspension_review' ? 'Access review requested' : '$renewalCycle renewal • \$$renewalPrice USD'}${companyRequests.length > 1 ? ' • +${companyRequests.length - 1} more' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                company['subscriptionEndsAt'] is Timestamp
                    ? 'Plan ends ${_formatDate((company['subscriptionEndsAt'] as Timestamp).toDate())}'
                    : 'No renewal request pending',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: latestRequest != null
                        ? _showRenewalInbox
                        : status == 'active'
                            ? () => _setCompanyStatus(companyDoc.id, 'expired', paymentStatus)
                            : () => _setCompanyStatus(companyDoc.id, 'active', 'paid'),
                    icon: Icon(latestRequest != null
                        ? Icons.fact_check_outlined
                        : status == 'active'
                            ? Icons.pause_circle_outline
                            : Icons.check_circle_outline),
                    label: Text(latestRequest != null
                        ? (latestRequest.data()['requestType'] == 'suspension_review'
                            ? 'Review access request'
                            : 'Review renewal')
                        : status == 'active'
                            ? 'Mark expired'
                            : 'Activate company'),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'More company actions',
                  onSelected: (value) {
                    if (value == 'activate') {
                      _setCompanyStatus(companyDoc.id, 'active', 'paid');
                    } else if (value == 'suspend') {
                      _setCompanyStatus(companyDoc.id, 'suspended', paymentStatus);
                    } else if (value == 'expire') {
                      _setCompanyStatus(companyDoc.id, 'expired', paymentStatus);
                    }
                  },
                  itemBuilder: (_) => [
                    if (status != 'active')
                      const PopupMenuItem(value: 'activate', child: Text('Activate company')),
                    if (status == 'active')
                      const PopupMenuItem(value: 'suspend', child: Text('Suspend company')),
                    if (status == 'active')
                      const PopupMenuItem(value: 'expire', child: Text('Mark plan expired')),
                  ],
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.more_horiz),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _PendingRenewal {
  const _PendingRenewal({
    required this.companyId,
    required this.companyName,
    required this.document,
  });

  final String companyId;
  final String companyName;
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
}
