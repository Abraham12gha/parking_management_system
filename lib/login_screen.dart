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


  String? emailError;
  String? passwordError;

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
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: const OutlineInputBorder(),
                            errorText: emailError,
                          ),
                          onChanged: (_) {
                            if (emailError != null) {
                              setState(() {
                                emailError = null;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: passwordController,
                          obscureText: hidePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            errorText: passwordError,
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
                          onChanged: (_) {
                            if (passwordError != null) {
                              setState(() {
                                passwordError = null;
                              });
                            }
                          },
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

                              // Clear previous errors
                              setState(() {
                                emailError = null;
                                passwordError = null;
                              });

                              // Validate email
                              if (email.isEmpty) {
                                setState(() {
                                  emailError = 'Email field is empty.';
                                });
                              }

                              // Validate password
                              if (password.isEmpty) {
                                setState(() {
                                  passwordError = 'Password field is empty.';
                                });
                              }

                              // Stop if validation failed
                              if (email.isEmpty || password.isEmpty) {
                                return;
                              }

                              // Show loading
                              setState(() {
                                isLoading = true;
                              });

                              try {
                                final result = await auth.login(
                                  email,
                                  password,
                                );

                                if (!mounted) return;

                                final role = result?['role'];

                                debugPrint('Login successful');
                                debugPrint('Role: $role');

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
                                  await auth.logout();

                                  setState(() {
                                    emailError = 'Invalid user role.';
                                  });
                                }
                              } on FirebaseAuthException catch (e) {
                                if (!mounted) return;

                                setState(() {
                                  switch (e.code) {
                                    case 'user-not-found':
                                      emailError = 'This email does not exist.';
                                      break;

                                    case 'wrong-password':
                                      passwordError = 'Password is wrong.';
                                      break;

                                    case 'invalid-credential':
                                      emailError = 'Email or password is incorrect.';
                                      break;

                                    case 'invalid-email':
                                      emailError = 'Please enter a valid email address.';
                                      break;

                                    case 'user-disabled':
                                      emailError = 'This account has been disabled.';
                                      break;

                                    case 'too-many-requests':
                                      passwordError =
                                      'Too many attempts. Please try again later.';
                                      break;

                                    case 'network-request-failed':
                                      emailError = 'Network error. Please try again.';
                                      break;

                                    default:
                                      emailError = e.message ?? 'Login failed.';
                                  }
                                });
                              } catch (e) {
                                if (!mounted) return;

                                setState(() {
                                  emailError = 'Something went wrong. Please try again.';
                                });

                                debugPrint('Login error: $e');
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