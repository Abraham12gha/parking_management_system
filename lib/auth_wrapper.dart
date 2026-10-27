import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:parking_management_system/services/auth.dart';

import '../admin_app/Admin_Dashboard.dart';
import '../admin_app/super_admin_dashboard.dart';
import '../operator_app/operator_dashboard.dart' hide AdminDashboard;
import '../services/app_data_cache.dart';
import '../services/tenant_context.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),

      builder: (context, snapshot) {
        // Firebase is checking authentication
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is NOT logged in — clear any stale cache data
        if (!snapshot.hasData) {
          AppDataCache.instance.clear();
          TenantContext.instance.clear();
          return const LoginScreen();
        }

        // User IS logged in
        return RoleBasedScreen(user: snapshot.data!);
      },
    );
  }
}

class RoleBasedScreen extends StatelessWidget {
  final User user;

  const RoleBasedScreen({super.key, required this.user});

  static final Auth _auth = Auth();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _auth.getUserRole(user.uid),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          final missingTenant = error.contains('not assigned to a company');
          final diagnostic = error.replaceFirst('Bad state: ', '');
          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        missingTenant
                            ? 'This account is not linked to a company. $diagnostic Signed-in account: ${user.email ?? 'unknown'} (UID ${user.uid}).'
                            : 'Unable to load company access: $error',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => Auth().logout(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final role = snapshot.data;

        switch (role) {
          case 'superAdmin':
            return const SuperAdminDashboard();
          case 'companyPending':
            return const _TenantStatusScreen(
              title: 'Company pending',
              message: 'Your company account is waiting for payment confirmation and activation. Sign in again after the platform admin activates it.',
            );
          case 'companySuspendedAdmin':
            return const _SuspendedCompanyAdminScreen();
          case 'companySuspendedOperator':
            return const _TenantStatusScreen(
              title: 'Company suspended',
              message: 'Your company workspace is temporarily paused. Ask your company admin to send an access review request to the platform owner.',
            );
          case 'companyExpired':
            return const _TenantStatusScreen(
              title: 'Company expired',
              message: 'This company account has expired. Contact the platform admin to renew it.',
            );
          case 'companyExpiredAdmin':
            return const _ExpiredCompanyAdminScreen();
          case 'companyExpiredOperator':
            return const _TenantStatusScreen(
              title: 'Company plan expired',
              message: 'Your company plan has expired. Please contact your company admin so they can request renewal.',
            );
          case 'admin':
            return const AdminDashboard();
          case 'operator':
            return const OperatorDashboard();

          default:
            return const Scaffold(
              body: Center(
                child: Text('No valid role assigned to this account.'),
              ),
            );
        }
      },
    );
  }
}

class _ExpiredCompanyAdminScreen extends StatefulWidget {
  const _ExpiredCompanyAdminScreen();

  @override
  State<_ExpiredCompanyAdminScreen> createState() => _ExpiredCompanyAdminScreenState();
}

class _ExpiredCompanyAdminScreenState extends State<_ExpiredCompanyAdminScreen> {
  String _cycle = 'monthly';
  bool _sending = false;
  bool _sent = false;
  String _companyName = 'Your company';

  @override
  void initState() {
    super.initState();
    TenantContext.instance.companyDocument().get().then((snapshot) {
      if (!mounted) return;
      final name = snapshot.data()?['name']?.toString().trim();
      setState(() => _companyName = name?.isNotEmpty == true ? name! : 'Your company');
    }).catchError((_) {});
  }

  Future<void> _requestRenewal() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await TenantContext.instance.collection('billing_requests').add({
        'companyId': TenantContext.instance.companyId,
        'companyName': _companyName,
        'requestedBy': uid,
        'billingCycle': _cycle,
        'amountUsd': _cycle == 'yearly' ? 600 : 50,
        'currency': 'USD',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) {
        final message = error is FirebaseException &&
                error.code == 'permission-denied'
            ? 'Firebase rejected the renewal request. Deploy the current firestore.rules to project parking-management-syste-cf110, then try again.'
            : 'Could not send renewal request: $error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = _cycle == 'yearly' ? '\$600 / year' : '\$50 / month';
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.event_busy_outlined, size: 42),
                const SizedBox(height: 12),
                Text('Renew $_companyName', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                const Text('Your plan is expired. Choose a plan and send a renewal request. There is no online payment yet; the platform owner will confirm your offline payment and restore access.', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'monthly', label: Text('Monthly • \$50')),
                    ButtonSegment(value: 'yearly', label: Text('Yearly • \$600')),
                  ],
                  selected: {_cycle},
                  onSelectionChanged: _sent ? null : (values) => setState(() => _cycle = values.first),
                ),
                const SizedBox(height: 16),
                if (_sent)
                  const Text('Renewal request sent. You can sign in again after the platform owner confirms payment.')
                else
                  FilledButton.icon(
                    onPressed: _sending ? null : _requestRenewal,
                    icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_outlined),
                    label: Text(_sending ? 'Sending…' : 'Request renewal — $price'),
                  ),
                const SizedBox(height: 12),
                TextButton.icon(onPressed: () => Auth().logout(), icon: const Icon(Icons.logout), label: const Text('Sign out')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuspendedCompanyAdminScreen extends StatefulWidget {
  const _SuspendedCompanyAdminScreen();

  @override
  State<_SuspendedCompanyAdminScreen> createState() =>
      _SuspendedCompanyAdminScreenState();
}

class _SuspendedCompanyAdminScreenState
    extends State<_SuspendedCompanyAdminScreen> {
  bool _sending = false;
  bool _sent = false;
  String _companyName = 'Your company';

  @override
  void initState() {
    super.initState();
    TenantContext.instance.companyDocument().get().then((snapshot) {
      if (!mounted) return;
      final name = snapshot.data()?['name']?.toString().trim();
      setState(() => _companyName =
          name?.isNotEmpty == true ? name! : 'Your company');
    }).catchError((_) {});
  }

  Future<void> _requestReview() async {
    if (_sending || _sent) return;
    setState(() => _sending = true);
    try {
      await TenantContext.instance.collection('billing_requests').add({
        'requestType': 'suspension_review',
        'companyId': TenantContext.instance.companyId,
        'requestedBy': FirebaseAuth.instance.currentUser!.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) {
        final message = error is FirebaseException &&
                error.code == 'permission-denied'
            ? 'Firebase rejected the access request. Deploy the updated firestore.rules to the same Firebase project used by this app, then try again.'
            : 'Could not send access review request: $error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pause_circle_outline, size: 44),
                    const SizedBox(height: 12),
                    Text('Company access paused',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Text(
                      '$_companyName is suspended. Send an access review request directly to the platform owner. They will see it in the platform administration notifications and can restore access.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (_sent)
                      const ListTile(
                        leading: Icon(Icons.check_circle_outline),
                        title: Text('Request sent'),
                        subtitle: Text('The platform owner has been notified. You can sign out while waiting for a response.'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _sending ? null : _requestReview,
                        icon: _sending
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.support_agent_outlined),
                        label: Text(_sending
                            ? 'Sending request…'
                            : 'Request access review'),
                      ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => Auth().logout(),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _TenantStatusScreen extends StatelessWidget {
  const _TenantStatusScreen({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Auth().logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
