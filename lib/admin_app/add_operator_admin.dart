import 'package:flutter/material.dart';

class AddOperator extends StatefulWidget {
  const AddOperator({super.key});

  @override
  State<AddOperator> createState() => _AddOperatorState();
}

class _AddOperatorState extends State<AddOperator> {
  // A Form needs a "key" so we can tell it to validate() or reset()
  // itself later from our code.
  final _formKey = GlobalKey<FormState>();

  // One controller per field.
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _locationController = TextEditingController();

  // Controls whether the password text is hidden (dots) or visible.
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  // Controllers hold on to memory, so always dispose them when this
  // screen is closed/removed.
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // Runs when the "Add Operator" button is tapped.
  // ---------------------------------------------------------------
  void _submitForm() {
    // validate() checks every field's `validator` function below.
    // It only returns true if ALL of them return null (no error).
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      // Something is wrong — the red text under each field already
      // tells the admin what to fix, so we just stop here.
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final location = _locationController.text.trim();
    // Note: never send/print the real password in production code —
    // this is just here so you can see it's captured correctly.
    // final password = _passwordController.text;

    // TODO: Replace this with your real API call, for example:
    // await ApiService.createOperator(name, email, password, location);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Operator "$name" ($email) added — $location'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );

    _clearForm();
  }

  // Empties every field and clears any error messages.
  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _locationController.clear();
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          // Stops the card from becoming too wide on large screens.
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: _cardDecoration(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),

                  _buildLabel('Full Name'),
                  TextFormField(
                    controller: _nameController,
                    decoration: _fieldDecoration(
                      hint: 'e.g. Ahmed Khan',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Please enter the operator's name";
                      }
                      return null; // null = no error
                    },
                  ),
                  const SizedBox(height: 18),

                  _buildLabel('Email Address'),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _fieldDecoration(
                      hint: 'e.g. operator@company.com',
                      icon: Icons.email_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an email address';
                      }
                      // A simple check for the shape "text@text.text".
                      final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      if (!emailPattern.hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  _buildLabel('Password'),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    decoration: _fieldDecoration(
                      hint: 'At least 6 characters',
                      icon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _hidePassword = !_hidePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  _buildLabel('Confirm Password'),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _hideConfirmPassword,
                    decoration: _fieldDecoration(
                      hint: 'Re-enter the password',
                      icon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hideConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _hideConfirmPassword = !_hideConfirmPassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm the password';
                      }
                      // This must be exactly equal to the password above.
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  _buildLabel('Location'),
                  TextFormField(
                    controller: _locationController,
                    decoration: _fieldDecoration(
                      hint: 'e.g. Karachi, Pakistan',
                      icon: Icons.location_on_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a location';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),

                  _buildButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // Everything below is just UI "decoration" — small helpers that
  // keep the build() method above short and easy to scan.
  // ---------------------------------------------------------------

  BoxDecoration _cardDecoration(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: colorScheme.onSurface.withOpacity(0.08)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.person_add_alt_1_rounded, color: colorScheme.primary, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Operator',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 3),
              Text(
                'Fill in the details below to create an operator account',
                style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
    );
  }

  // One shared decoration so every field in this form looks the same.
  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.35)),
      prefixIcon: Icon(icon, size: 20, color: colorScheme.onSurface.withOpacity(0.5)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.onSurface.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _buildButtons() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _clearForm,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear'),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _submitForm,
            icon: const Icon(Icons.check_rounded, size: 19),
            label: const Text('Add Operator'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}