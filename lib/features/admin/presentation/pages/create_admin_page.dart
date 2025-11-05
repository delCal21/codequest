import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_event.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_state.dart';
import 'package:codequest/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:codequest/features/auth/domain/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CreateAdminPage extends StatefulWidget {
  const CreateAdminPage({super.key});

  @override
  State<CreateAdminPage> createState() => _CreateAdminPageState();
}

class _CreateAdminPageState extends State<CreateAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkIfAdmin();
  }

  Future<void> _checkIfAdmin() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!userDoc.exists) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final userData = UserModel.fromFirestore(userDoc);
    if (userData.role != UserRole.admin) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() {
      _isAdmin = true;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleCreateAdmin() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            SignUpRequested(
              _emailController.text.trim(),
              _passwordController.text,
              _nameController.text.trim(),
              UserRole.admin,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Scaffold(
        body: Center(
          child: Text('This page is only available on web.'),
        ),
      );
    }

    if (!_isAdmin) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Admin Account'),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is Authenticated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Admin account created successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Create Admin Account',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Register a new administrator account',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    AuthTextField(
                      controller: _nameController,
                      labelText: 'Full Name',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _emailController,
                      labelText: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _passwordController,
                      labelText: 'Password',
                      obscureText: !_isPasswordVisible,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
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
                    const SizedBox(height: 24),
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        return ElevatedButton(
                          onPressed:
                              state is AuthLoading ? null : _handleCreateAdmin,
                          child: state is AuthLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Create Admin Account'),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Back to Dashboard'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
