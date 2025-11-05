import 'package:flutter/material.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_event.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    try {
      // Check Firestore for user with this email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (userQuery.docs.isEmpty) {
        // Show generic message to prevent user enumeration
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'If an account with that email exists, a reset link has been sent.'),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }
      final userData = userQuery.docs.first.data();
      final role = userData['role'] ?? 'student';
      String customMsg;
      if (role == 'admin' || role == 'teacher') {
        customMsg =
            'If you are an admin or teacher, check your email for a reset link.';
      } else {
        customMsg = 'If you are a student, check your email for a reset link.';
      }
      // Dispatch event to send reset email
      context.read<AuthBloc>().add(
            ResetPasswordRequested(email: email),
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(customMsg)),
      );
      // Optionally, pop after a short delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Forgot your password?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              BlocConsumer<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is AuthError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.message)),
                    );
                  }
                },
                builder: (context, state) {
                  return ElevatedButton(
                    onPressed: (_isLoading || state is AuthLoading)
                        ? null
                        : _handleResetPassword,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: (_isLoading || state is AuthLoading)
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Send Reset Link',
                            style: TextStyle(fontSize: 16),
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
