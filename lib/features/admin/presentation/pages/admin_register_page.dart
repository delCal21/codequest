import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:codequest/features/courses/domain/models/collaborator_model.dart';
import 'package:codequest/features/courses/data/collaborator_repository.dart';
import 'package:codequest/features/courses/data/course_repository.dart';
import 'package:codequest/services/teacher_email_validation_service.dart';
import 'package:codequest/services/real_email_service.dart';
import 'package:codequest/config/routes.dart';

class TeacherRegisterPage extends StatefulWidget {
  const TeacherRegisterPage({super.key});

  @override
  State<TeacherRegisterPage> createState() => _TeacherRegisterPageState();
}

class _TeacherRegisterPageState extends State<TeacherRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // For course selection
  String? _selectedCourseId;
  List<Map<String, String>> _courses = [];

  // Privacy acceptance checkbox
  bool _privacyAccepted = false;

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    final repo = CourseRepository(FirebaseFirestore.instance);
    final allCourses = await repo.getAllCourses();
    setState(() {
      _courses = allCourses.map((c) => {'id': c.id, 'title': c.title}).toList();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _registerTeacher() async {
    if (!_formKey.currentState!.validate()) return;
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
    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a course to assign.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Create user with Firebase Auth (this will trigger the email notification function)
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Add user info to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'id': userCredential.user!.uid,
        'email': _emailController.text.trim(),
        'name': _fullNameController.text.trim(),
        'role': 'teacher',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'profileImage': null,
      });

      // Add as collaborator to selected course
      final collaboratorRepo =
          CollaboratorRepository(FirebaseFirestore.instance);
      final currentUser = FirebaseAuth.instance.currentUser;
      final collaborator = CollaboratorModel(
        id: '',
        userId: userCredential.user!.uid,
        userName: _fullNameController.text.trim(),
        userEmail: _emailController.text.trim(),
        role: CollaboratorRole.coTeacher,
        addedAt: DateTime.now(),
        addedBy: currentUser?.uid ?? 'admin',
        permissions: CollaboratorModel(
          id: '',
          userId: userCredential.user!.uid,
          userName: _fullNameController.text.trim(),
          userEmail: _emailController.text.trim(),
          role: CollaboratorRole.coTeacher,
          addedAt: DateTime.now(),
          addedBy: currentUser?.uid ?? 'admin',
        ).defaultPermissions,
      );
      await collaboratorRepo.addCollaborator(_selectedCourseId!, collaborator);

      // Create teacher notification for the newly registered teacher
      await FirebaseFirestore.instance.collection('teacher_notifications').add({
        'teacherId': userCredential.user!.uid,
        'type': 'account_created',
        'title': 'Welcome to CodeQuest!',
        'message':
            'Your teacher account has been created by the administrator and you have been assigned to a course. Please check your email for login instructions.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'actionRequired': false,
      });

      // Send welcome email directly to teacher
      final emailSent = await RealEmailService.sendWelcomeEmail(
        teacherName: _fullNameController.text.trim(),
        teacherEmail: _emailController.text.trim(),
        teacherPassword: _passwordController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            emailSent
                ? 'Teacher account created, assigned to course, and welcome email sent!'
                : 'Teacher account created and assigned to course! (Email sending in progress)',
          ),
          backgroundColor: Colors.green[600],
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      String errorMsg = 'Error: \\${e.toString()}';
      if (e is FirebaseAuthException && e.code == 'email-already-in-use') {
        errorMsg = 'This email is already registered.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
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
          child: Text('Admin registration is only available on web.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Teacher Account'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create New Teacher Account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    helperText:
                        'Use an educational institution email or approved domain',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    // Validate teacher email
                    final validationError =
                        TeacherEmailValidationService.validateTeacherEmailSync(
                            value);
                    if (validationError != null) {
                      return validationError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    if (!RegExp(r'[!@#\$%\^&]').hasMatch(value)) {
                      return 'Password must contain at least one special character (!@#\$%^&)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: _selectedCourseId,
                  items: _courses
                      .map((course) => DropdownMenuItem(
                            value: course['id'],
                            child: Text(course['title'] ?? ''),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedCourseId = value),
                  decoration: const InputDecoration(
                    labelText: 'Assign to Course',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null ? 'Please select a course' : null,
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
                                  text:
                                      'I confirm that the teacher has agreed to the ',
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
                                        decoration: TextDecoration.underline,
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
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                const TextSpan(
                                  text: '.',
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
                    padding: const EdgeInsets.only(left: 48, top: 4),
                    child: Text(
                      'Please confirm privacy policy acceptance to continue',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _registerTeacher,
                        child: const Text('Create Teacher Account'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
