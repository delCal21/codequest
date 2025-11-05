import 'package:flutter/material.dart';
import 'package:codequest/scripts/create_admin.dart';
import 'package:codequest/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirstAdminPage extends StatefulWidget {
  const FirstAdminPage({super.key});

  @override
  State<FirstAdminPage> createState() => _FirstAdminPageState();
}

class _FirstAdminPageState extends State<FirstAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isFirstUser = false;

  @override
  void initState() {
    super.initState();
    _checkIfFirstUser();
  }

  Future<void> _checkIfFirstUser() async {
    final usersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();
    setState(() {
      _isFirstUser = usersSnapshot.docs.isEmpty;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createFirstAdmin() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        if (!_isFirstUser) {
          throw Exception(
              'This page is only for creating the first admin account');
        }

        await createFirstAdmin(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('First admin account created successfully!')),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
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

    if (!_isFirstUser) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
        ),
        body: const Center(
          child: Text(
            'This page is only for creating the first admin account.',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create First Admin'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create First Admin Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'This will create the first administrator account for the system.',
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
                obscureText: true,
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
              ElevatedButton(
                onPressed: _isLoading ? null : _createFirstAdmin,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Create First Admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
