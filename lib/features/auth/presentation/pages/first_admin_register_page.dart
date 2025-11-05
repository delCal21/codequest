import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/config/routes.dart';
import 'package:flutter/foundation.dart';
import 'package:codequest/features/auth/presentation/widgets/auth_text_field.dart';

class FirstAdminRegisterPage extends StatefulWidget {
  const FirstAdminRegisterPage({Key? key}) : super(key: key);

  @override
  State<FirstAdminRegisterPage> createState() => _FirstAdminRegisterPageState();
}

class _FirstAdminRegisterPageState extends State<FirstAdminRegisterPage> {
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (!_isFirstUser) {
        throw Exception(
            'This page is only for creating the first admin account');
      }

      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'id': userCredential.user!.uid,
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'enrolledCourses': [],
        'preferences': {},
        'recentActivities': [],
        'lastLogin': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First admin account created!')),
      );
      Navigator.pushReplacementNamed(context, AppRouter.login);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
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
      backgroundColor: Colors.grey[200],
      body: Center(
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
                          'Create First Admin Account',
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
                            return null;
                          },
                          showUnderline: true,
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _passwordController,
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          obscureText: true,
                          prefixIcon: Icons.lock_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters long';
                            }
                            return null;
                          },
                          showUnderline: true,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _createFirstAdmin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'CREATE ADMIN',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 48),
                        const Text(
                          'Code Quest',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Learn. Code. Conquer.',
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
