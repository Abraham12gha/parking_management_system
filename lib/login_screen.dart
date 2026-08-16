import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:parking_management_system/services/auth.dart';
import 'package:parking_management_system/services/company_settings_service.dart';
import 'admin_app/Admin_Dashboard.dart';
import 'company-data/company_info.dart';
import 'operator_app/operator_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final Auth _auth = Auth();

  String _companyName = 'Pakistan Valet Solution';
  String? _logoUrl;

  bool _isLoading = false;
  bool hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  String appVersion = '';
  String buildNumber = '';


  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    loadAppVersion();
    _loadCompanySettings();
  }
  Future<void> _loadCompanySettings() async {
    try {
      final settings =
      await CompanySettingsService.instance.getSettings();

      if (!mounted) return;

      setState(() {
        _companyName = settings.appName.isNotEmpty
            ? settings.appName
            : 'Pakistan Valet Solution';

        _logoUrl = settings.logoUrl;
      });
    } catch (e) {
      debugPrint('Could not load company settings: $e');

      // Keep default values.
      if (!mounted) return;

      setState(() {
        _companyName = 'Pakistan Valet Solution';
        _logoUrl = null;
      });
    }
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

                        _logoUrl != null && _logoUrl!.isNotEmpty
                            ? Image.network(
                          _logoUrl!,
                          height: 70,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Could not load company logo: $error');

                            return Image.asset(
                              'assets/images/PVS_LOGO.png',
                              height: 70,
                            );
                          },
                        )
                            : Image.asset(
                          'assets/images/PVS_LOGO.png',
                          height: 70,
                        ),

                        const SizedBox(height: 16),

                        Text(
                          _companyName,
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
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,

                          decoration: InputDecoration(
                            labelText: 'Email',

                            // Keep label visible
                            floatingLabelBehavior: FloatingLabelBehavior.auto,

                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface.withValues(alpha: 0.7),
                            ),

                            floatingLabelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),

                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: colors.onSurface.withValues(alpha: 0.7),
                            ),

                            errorText: _emailError,

                            errorStyle: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: colors.primary,
                                width: 2,
                              ),
                            ),

                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 1.5,
                              ),
                            ),

                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                          ),

                          onChanged: (_) {
                            if (_emailError != null) {
                              setState(() {
                                _emailError = null;
                              });
                            }
                          },
                        ),


                        const SizedBox(height: 16),

                        TextField(
                          controller: _passwordController,
                          obscureText: hidePassword,

                          decoration: InputDecoration(
                            labelText: 'Password',

                            floatingLabelBehavior: FloatingLabelBehavior.auto,

                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface.withValues(alpha: 0.7),
                            ),

                            floatingLabelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),

                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: colors.onSurface.withValues(alpha: 0.7),
                            ),

                            errorText: _passwordError,

                            errorStyle: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),

                            suffixIcon: IconButton(
                              tooltip: hidePassword
                                  ? 'Show password'
                                  : 'Hide password',

                              icon: Icon(
                                hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: colors.onSurface.withValues(alpha: 0.7),
                              ),

                              onPressed: () {
                                setState(() {
                                  hidePassword = !hidePassword;
                                });
                              },
                            ),

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: colors.primary,
                                width: 2,
                              ),
                            ),

                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 1.5,
                              ),
                            ),

                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                          ),

                          onChanged: (_) {
                            if (_passwordError != null) {
                              setState(() {
                                _passwordError = null;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                              setState(() {
                                _emailError = null;
                                _passwordError = null;
                              });

                              bool hasError = false;

                              if (_emailController.text.trim().isEmpty) {
                                _emailError = 'Email is required';
                                hasError = true;
                              }

                              if (_passwordController.text.isEmpty) {
                                _passwordError = 'Password is required';
                                hasError = true;
                              }

                              setState(() {});

                              if (hasError) return;

                              try {
                                setState(() {
                                  _isLoading = true;
                                });

                                await _auth.login(
                                  _emailController.text.trim(),
                                  _passwordController.text,
                                );

                              } on FirebaseAuthException catch (e) {

                                debugPrint('Firebase Error: ${e.code}');
                                debugPrint('Firebase Message: ${e.message}');

                                if (!mounted) return;

                                setState(() {
                                  switch (e.code) {
                                    case 'user-not-found':
                                      _emailError =
                                      'No account found with this email.';
                                      break;

                                    case 'wrong-password':
                                      _passwordError =
                                      'Incorrect password.';
                                      break;

                                    case 'invalid-email':
                                      _emailError =
                                      'Please enter a valid email address.';
                                      break;

                                    case 'invalid-credential':
                                      _passwordError =
                                      'Invalid email or password.';
                                      break;

                                    case 'user-disabled':
                                      _emailError =
                                      'This account has been disabled.';
                                      break;

                                    case 'too-many-requests':
                                      _passwordError =
                                      'Too many login attempts. Please try again later.';
                                      break;

                                    case 'network-request-failed':
                                      _passwordError =
                                      'Network error. Check your internet connection.';
                                      break;

                                    default:
                                      _passwordError =
                                      'Login failed. Please try again.';
                                  }
                                });

                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isLoading = false;
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
                            child: _isLoading
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