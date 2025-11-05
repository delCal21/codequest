import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_event.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_state.dart';
import 'package:codequest/config/routes.dart';
import 'package:codequest/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:codequest/features/auth/domain/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:codequest/services/teacher_email_validation_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isPasswordVisible = false;
  UserRole? _selectedRole;
  bool _isAdmin = false;
  bool _checkedAdmin = false;

  // Password validation states (match teacher registration)
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumbers = false;
  bool _hasSpecialChars = false;

  // Privacy acceptance checkbox
  bool _privacyAccepted = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _selectedRole = UserRole.teacher;
      _checkIfAdmin();
    } else {
      _selectedRole = UserRole.student;
      _checkedAdmin = true; // No admin check needed on mobile
    }
  }

  Future<void> _checkIfAdmin() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _isAdmin = false;
        _checkedAdmin = true;
      });
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!userDoc.exists) {
      setState(() {
        _isAdmin = false;
        _checkedAdmin = true;
      });
      return;
    }

    final userData = UserModel.fromFirestore(userDoc);
    if (userData.role == UserRole.admin) {
      setState(() {
        _isAdmin = true;
        _checkedAdmin = true;
      });
    } else {
      setState(() {
        _isAdmin = false;
        _checkedAdmin = true;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _validatePassword(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumbers = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChars = password.contains(RegExp(r'[!@#\$%\^&*(),.?":{}|<>]'));
    });
  }

  Widget _buildRequirementRow(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isMet ? Colors.green[700] : Colors.grey[600],
              fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _handleRegister() {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_privacyAccepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Please accept the privacy policy and terms of service to continue'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedRole != null) {
        context.read<AuthBloc>().add(
              SignUpRequested(
                _emailController.text.trim(),
                _passwordController.text,
                _nameController.text.trim(),
                _selectedRole!,
              ),
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prevent admin registration via this page on web
    if (kIsWeb && _checkedAdmin && _isAdmin) {
      return const Scaffold(
        body: Center(
          child: Text('Admins cannot register via this page.'),
        ),
      );
    }
    // Wait for admin check to complete on web
    if (kIsWeb && !_checkedAdmin) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[200], // Light gray background
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registration successful!')),
            );
            if (kIsWeb) {
              Navigator.pushReplacementNamed(context, AppRouter.login);
            } else {
              Navigator.pushReplacementNamed(
                  context, AppRouter.studentDashboard);
            }
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Create New Account',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 24),
                            AuthTextField(
                              controller: _nameController,
                              labelText: 'Full Name',
                              hintText: 'Enter your full name',
                              prefixIcon: Icons.person_outline,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your full name';
                                }
                                return null;
                              },
                              hasError: state is AuthError,
                              showUnderline: true,
                            ),
                            const SizedBox(height: 16),
                            AuthTextField(
                              controller: _emailController,
                              labelText: 'Email',
                              hintText:
                                  'Use the following format: example@site.com',
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: Icons.email_outlined,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                    .hasMatch(value)) {
                                  return 'Please enter a valid email address';
                                }
                                // Validate teacher email if registering as teacher
                                if (_selectedRole == UserRole.teacher) {
                                  final validationError =
                                      TeacherEmailValidationService
                                          .validateTeacherEmailSync(value);
                                  if (validationError != null) {
                                    return validationError;
                                  }
                                }
                                return null;
                              },
                              hasError: state is AuthError,
                              showUnderline: true,
                            ),
                            const SizedBox(height: 16),
                            AuthTextField(
                              controller: _passwordController,
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              obscureText: !_isPasswordVisible,
                              prefixIcon: Icons.lock_outline,
                              onChanged: _validatePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter password';
                                }
                                if (value.length < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                  return 'Password must contain at least one uppercase letter';
                                }
                                if (!RegExp(r'[a-z]').hasMatch(value)) {
                                  return 'Password must contain at least one lowercase letter';
                                }
                                if (!RegExp(r'[0-9]').hasMatch(value)) {
                                  return 'Password must contain at least one number';
                                }
                                if (!RegExp(r'[!@#\$%\^&*(),.?":{}|<>]')
                                    .hasMatch(value)) {
                                  return 'Password must contain at least one special character';
                                }
                                return null;
                              },
                              hasError: state is AuthError,
                              showUnderline: true,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Password Requirements:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildRequirementRow(
                                      'At least 8 characters', _hasMinLength),
                                  _buildRequirementRow(
                                      'Uppercase letter (A-Z)', _hasUppercase),
                                  _buildRequirementRow(
                                      'Lowercase letter (a-z)', _hasLowercase),
                                  _buildRequirementRow(
                                      'Number (0-9)', _hasNumbers),
                                  _buildRequirementRow(
                                      'Special character (!@#\$%\^&*(),.?":{}|<>)',
                                      _hasSpecialChars),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Privacy acceptance checkbox
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: _privacyAccepted,
                                  onChanged: (value) {
                                    setState(() {
                                      _privacyAccepted = value ?? false;
                                    });
                                  },
                                  activeColor: Colors.green[600],
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _privacyAccepted = !_privacyAccepted;
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                            height: 1.4,
                                          ),
                                          children: [
                                            const TextSpan(
                                              text: 'I agree to the ',
                                            ),
                                            WidgetSpan(
                                              child: GestureDetector(
                                                onTap: () {
                                                  Navigator.pushNamed(
                                                    context,
                                                    AppRouter.privacyPolicy,
                                                  );
                                                },
                                                child: Text(
                                                  'Privacy Policy',
                                                  style: TextStyle(
                                                    color: Colors.green[600],
                                                    fontWeight: FontWeight.w600,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const TextSpan(
                                              text: ' and ',
                                            ),
                                            WidgetSpan(
                                              child: GestureDetector(
                                                onTap: () {
                                                  Navigator.pushNamed(
                                                    context,
                                                    AppRouter.termsOfService,
                                                  );
                                                },
                                                child: Text(
                                                  'Terms of Service',
                                                  style: TextStyle(
                                                    color: Colors.green[600],
                                                    fontWeight: FontWeight.w600,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const TextSpan(
                                              text:
                                                  '. I understand that my personal information will be used in accordance with these policies.',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!_privacyAccepted)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 48, top: 4),
                                child: Text(
                                  'Please accept the privacy policy and terms of service to continue',
                                  style: TextStyle(
                                    color: Colors.red[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: isLoading ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text(
                                      'REGISTER',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      Navigator.pushReplacementNamed(
                                          context, AppRouter.login);
                                    },
                              child: Text(
                                'Already have an account? Login',
                                style: TextStyle(
                                    color: Theme.of(context).primaryColor),
                              ),
                            ),
                            const SizedBox(height: 48),
                            // Code Quest Logo and Tagline
                            Center(
                              child: Column(
                                children: [
                                  Image.asset(
                                    'assets/images/CIS SEAL2.png',
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Code Quest',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Craft Your Code, Shape Your Future',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
