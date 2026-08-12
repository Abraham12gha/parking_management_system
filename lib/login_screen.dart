import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:parking_management_system/services/auth.dart';
import 'admin_app/Admin_Dashboard.dart';
import 'company-data/company_info.dart';
import 'operator_app/operator_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final Auth auth = Auth();
  bool isLoading = false;

  bool hidePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }


  String appVersion = '';
  String buildNumber = '';

  @override
  void initState() {
    super.initState();
    loadAppVersion();
  }

  Future<void> loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();

    setState(() {
      appVersion = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              color: colors.primary,
              child: Image.asset(
                'assets/images/Login_backgrund.jpg',
                fit: BoxFit.cover,
                height: double.infinity,
                width: double.infinity,
              ),
            ),
          ),

          Expanded(
            flex: 1,
            child: Container(
              color: colors.surface,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [

                        Image.asset(
                          company.logo,
                          height: 70,
                        ),
                        const SizedBox(height: 16),

                        Text(
                          company.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 32),

                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please login to your account',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 32),


                        TextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: passwordController,
                          obscureText: hidePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  hidePassword = !hidePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () async {
                              final email = emailController.text.trim();
                              final password = passwordController.text;

                              // Validate fields
                              if (email.isEmpty || password.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter email and password'),
                                  ),
                                );
                                return;
                              }

                              // Show loading
                              setState(() {
                                isLoading = true;
                              });

                              try {
                                // Login with Firebase
                                final result = await auth.login(
                                  email,
                                  password,
                                );

                                if (!mounted) return;

                                // Get role from Firestore
                                final role = result?['role'];

                                debugPrint('Login successful');
                                debugPrint('Role: $role');

                                // Navigate based on role
                                if (role == 'admin') {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AdminDashboard(),
                                    ),
                                  );
                                } else if (role == 'operator') {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const OperatorDashboard(),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invalid user role'),
                                    ),
                                  );

                                  // Logout if role is invalid
                                  await auth.logout();
                                }
                              } on FirebaseAuthException catch (e) {
                                if (!mounted) return;

                                String message;

                                switch (e.code) {
                                  case 'invalid-credential':
                                    message = 'Invalid email or password.';
                                    break;

                                  case 'user-not-found':
                                    message = 'No account found with this email.';
                                    break;

                                  case 'wrong-password':
                                    message = 'Incorrect password.';
                                    break;

                                  case 'invalid-email':
                                    message = 'Please enter a valid email address.';
                                    break;

                                  case 'user-disabled':
                                    message = 'This account has been disabled.';
                                    break;

                                  case 'too-many-requests':
                                    message = 'Too many attempts. Please try again later.';
                                    break;

                                  default:
                                    message = e.message ?? 'Login failed.';
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(message),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Something went wrong: $e'),
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    isLoading = false;
                                  });
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: colors.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: isLoading
                                ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: colors.onPrimary,
                              ),
                            )
                                : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'v$appVersion [build: $buildNumber]',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurface.withValues(alpha: 0.5),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}