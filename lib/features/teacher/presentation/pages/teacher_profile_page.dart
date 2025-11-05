import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:codequest/core/theme/app_theme.dart';
import 'package:codequest/features/users/data/repositories/users_repository_impl.dart';
import 'package:codequest/features/users/domain/models/user_model.dart';

class TeacherProfilePage extends StatefulWidget {
  const TeacherProfilePage({Key? key}) : super(key: key);

  @override
  State<TeacherProfilePage> createState() => _TeacherProfilePageState();
}

class _TeacherProfilePageState extends State<TeacherProfilePage> {
  TextEditingController? _nameController;
  TextEditingController? _emailController;
  bool _isLoading = false;
  UserModel? _user;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController?.dispose();
    _emailController?.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_user == null) return;
    setState(() => _isLoading = true);
    final repo = UsersRepositoryImpl(FirebaseFirestore.instance);
    final updatedUser = _user!.copyWith(
      fullName: _nameController!.text.trim(),
      email: _emailController!.text.trim(),
      updatedAt: DateTime.now(),
    );
    try {
      await repo.updateUser(updatedUser);
      if (!mounted) return;
      setState(() {
        _user = updatedUser;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersRepository = UsersRepositoryImpl(FirebaseFirestore.instance);
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('User not logged in.'));
    }
    return FutureBuilder<UserModel?>(
      future: usersRepository.getUser(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error.toString()}'));
        } else if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text('No profile data.'));
        }
        final user = snapshot.data!;
        if (!_initialized) {
          _user = user;
          _nameController = TextEditingController(text: user.fullName);
          _emailController = TextEditingController(text: user.email);
          _initialized = true;
        }
        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: const Text('Profile'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          body: SingleChildScrollView(
            child: Center(
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                margin: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.blue[50],
                            backgroundImage: _user?.profileImage != null &&
                                    _user!.profileImage!.isNotEmpty
                                ? NetworkImage(_user!.profileImage!)
                                : null,
                            child: (_user?.profileImage == null ||
                                    _user!.profileImage!.isEmpty)
                                ? const Icon(Icons.person,
                                    size: 50, color: Colors.grey)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(_nameController!.text,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(_emailController!.text,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 24),
                      const Divider(height: 32, thickness: 1.2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Personal Information',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                                fontSize: 16)),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Courses Created',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                                fontSize: 16)),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('courses')
                            .where('teacherId', isEqualTo: userId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Text(
                                'You have not created any courses.');
                          }
                          final courses = snapshot.data!.docs;
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: courses.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final course =
                                  courses[index].data() as Map<String, dynamic>;
                              dynamic createdAtRaw = course['createdAt'];
                              String createdAtStr;
                              if (createdAtRaw is Timestamp) {
                                createdAtStr = (createdAtRaw as Timestamp)
                                    .toDate()
                                    .toString();
                              } else if (createdAtRaw is String) {
                                createdAtStr = createdAtRaw;
                              } else {
                                createdAtStr = '';
                              }
                              return Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        course['title'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        course['description'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 13, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Created: $createdAtStr',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _saveProfile,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.save),
                            label: const Text('Save'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        final _currentPasswordController =
                                            TextEditingController();
                                        final _newPasswordController =
                                            TextEditingController();
                                        return AlertDialog(
                                          title: const Text('Change Password'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextField(
                                                controller:
                                                    _currentPasswordController,
                                                obscureText: true,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Current Password',
                                                  prefixIcon:
                                                      Icon(Icons.lock_outline),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              TextField(
                                                controller:
                                                    _newPasswordController,
                                                obscureText: true,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'New Password',
                                                  prefixIcon:
                                                      Icon(Icons.lock_reset),
                                                ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                final currentPassword =
                                                    _currentPasswordController
                                                        .text
                                                        .trim();
                                                final newPassword =
                                                    _newPasswordController.text
                                                        .trim();
                                                if (newPassword.length < 6) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            'Password must be at least 6 characters.')),
                                                  );
                                                  return;
                                                }
                                                Navigator.pop(context);
                                                setState(
                                                    () => _isLoading = true);
                                                try {
                                                  final user = FirebaseAuth
                                                      .instance.currentUser;
                                                  final email = user?.email;
                                                  if (user == null ||
                                                      email == null)
                                                    throw Exception(
                                                        'User not logged in');
                                                  // Re-authenticate
                                                  final cred = EmailAuthProvider
                                                      .credential(
                                                          email: email,
                                                          password:
                                                              currentPassword);
                                                  await user
                                                      .reauthenticateWithCredential(
                                                          cred);
                                                  // Update password
                                                  await user.updatePassword(
                                                      newPassword);
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            'Password updated successfully!')),
                                                  );
                                                } catch (e) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                        content: Text(
                                                            'Failed to update password: $e')),
                                                  );
                                                } finally {
                                                  setState(
                                                      () => _isLoading = false);
                                                }
                                              },
                                              child: const Text('Save'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                            icon: const Icon(Icons.lock_reset),
                            label: const Text('Change Password'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
