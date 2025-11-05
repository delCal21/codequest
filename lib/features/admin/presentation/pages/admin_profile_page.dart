import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/auth/domain/models/user_model.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_event.dart';
import 'package:codequest/config/routes.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
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

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'name': _nameController!.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        setState(() {
          _user = _user!.copyWith(
            name: _nameController!.text.trim(),
            updatedAt: DateTime.now(),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated!')),
        );
      }
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

  Future<UserModel?> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        return UserModel.fromFirestore(userDoc, firebaseUser: user);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('User not logged in.'));
    }
    return FutureBuilder<UserModel?>(
      future: _loadUserData(),
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
          _nameController = TextEditingController(text: user.name);
          _emailController = TextEditingController(text: user.email);
          _initialized = true;
        }
        return Scaffold(
          backgroundColor: Colors.green[50],
          appBar: AppBar(
            title: const Text('Admin Profile'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.green[700],
            iconTheme: IconThemeData(color: Colors.green[700]),
          ),
          body: SingleChildScrollView(
            child: Center(
              child: Card(
                elevation: 6,
                color: Colors.white,
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
                            backgroundColor: Colors.green[50],
                            backgroundImage: _user?.avatarUrl != null &&
                                    _user!.avatarUrl!.isNotEmpty
                                ? NetworkImage(_user!.avatarUrl!)
                                : null,
                            child: (_user?.avatarUrl == null ||
                                    _user!.avatarUrl!.isEmpty)
                                ? const Icon(Icons.person,
                                    size: 50, color: Colors.grey)
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.green[600],
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings,
                              color: Colors.white,
                              size: 16,
                            ),
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
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Administrator',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
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
                        decoration: InputDecoration(
                          labelText: 'Name',
                          prefixIcon: Icon(Icons.person_outline,
                              color: Colors.green[600]),
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.green[600]!, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined,
                              color: Colors.green[600]),
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.green[600]!, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('System Statistics',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                                fontSize: 16)),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData) {
                            return const Text('Unable to load statistics.');
                          }
                          final users = snapshot.data!.docs;
                          final teachers = users
                              .where((doc) =>
                                  (doc.data()
                                      as Map<String, dynamic>)['role'] ==
                                  'teacher')
                              .length;
                          final students = users
                              .where((doc) =>
                                  (doc.data()
                                      as Map<String, dynamic>)['role'] ==
                                  'student')
                              .length;
                          final admins = users
                              .where((doc) =>
                                  (doc.data()
                                      as Map<String, dynamic>)['role'] ==
                                  'admin')
                              .length;

                          return Column(
                            children: [
                              _buildStatCard('Total Users',
                                  users.length.toString(), Icons.people),
                              const SizedBox(height: 12),
                              _buildStatCard('Teachers', teachers.toString(),
                                  Icons.school),
                              const SizedBox(height: 12),
                              _buildStatCard('Students', students.toString(),
                                  Icons.person),
                              const SizedBox(height: 12),
                              _buildStatCard(
                                  'Administrators',
                                  admins.toString(),
                                  Icons.admin_panel_settings),
                            ],
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                            ),
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
                                                  prefixIcon: Icon(
                                                      Icons.lock_outline,
                                                      color: Colors.green),
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
                                                  prefixIcon: Icon(
                                                      Icons.lock_reset,
                                                      color: Colors.green),
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
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.green[600],
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                            icon: const Icon(Icons.lock_reset),
                            label: const Text('Change Password'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              context.read<AuthBloc>().add(SignOutRequested());
                              Navigator.pushReplacementNamed(
                                  context, AppRouter.login);
                            },
                            icon: const Icon(Icons.logout),
                            label: const Text('Sign Out'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                              foregroundColor: Colors.white,
                            ),
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

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.green[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
