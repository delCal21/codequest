import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/users/data/repositories/users_repository_impl.dart';
import 'package:codequest/features/users/domain/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  TextEditingController? _nameController;
  TextEditingController? _emailController;
  bool _isLoading = false;
  UserModel? _user;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
  }

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
      setState(() {
        _user = updatedUser;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (kIsWeb) {
      // Show a message or disable the feature on web
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profile image upload is not supported on web.')),
      );
      return;
    }
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    setState(() => _isLoading = true);
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${FirebaseAuth.instance.currentUser!.uid}.jpg');
      await storageRef.putFile(File(pickedFile.path));
      final downloadUrl = await storageRef.getDownloadURL();
      final repo = UsersRepositoryImpl(FirebaseFirestore.instance);
      final updatedUser = _user!.copyWith(
        profileImage: downloadUrl,
        updatedAt: DateTime.now(),
      );
      await repo.updateUser(updatedUser);
      setState(() {
        _user = updatedUser;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
    } finally {
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
          backgroundColor: const Color(0xFFF7F8FA),
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
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: _isLoading ? null : _pickAndUploadImage,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(Icons.edit,
                                    size: 20, color: Colors.green),
                              ),
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
                        child: Text('My Enrolled Courses & Progress',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                                fontSize: 16)),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('enrollments')
                            .where('studentId', isEqualTo: userId)
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
                                'You are not enrolled in any courses.');
                          }
                          final enrollments = snapshot.data!.docs;
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: enrollments.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final enrollment = enrollments[index].data()
                                  as Map<String, dynamic>;
                              final courseId = enrollment['courseId'];
                              return FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('courses')
                                    .doc(courseId)
                                    .get(),
                                builder: (context, courseSnapshot) {
                                  if (!courseSnapshot.hasData ||
                                      !courseSnapshot.data!.exists) {
                                    return const SizedBox();
                                  }
                                  final course = courseSnapshot.data!.data()
                                      as Map<String, dynamic>;
                                  return FutureBuilder<QuerySnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('challenges')
                                        .where('courseId', isEqualTo: courseId)
                                        .get(),
                                    builder: (context, challengesSnapshot) {
                                      if (!challengesSnapshot.hasData) {
                                        return const SizedBox();
                                      }
                                      final allChallenges =
                                          challengesSnapshot.data!.docs;
                                      final allChallengeIds = allChallenges
                                          .map((c) => c.id)
                                          .toSet();
                                      return StreamBuilder<DocumentSnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('progress')
                                            .doc(userId + '_' + courseId)
                                            .snapshots(),
                                        builder: (context, progressSnapshot) {
                                          if (!progressSnapshot.hasData) {
                                            return const SizedBox();
                                          }
                                          final progressData =
                                              progressSnapshot.data!.data()
                                                  as Map<String, dynamic>?;
                                          final completedChallenges = progressData !=
                                                      null &&
                                                  progressData[
                                                          'completedChallenges']
                                                      is List
                                              ? List<String>.from(progressData[
                                                  'completedChallenges'])
                                              : <String>[];
                                          final completedForThisCourse =
                                              allChallengeIds
                                                  .where((id) =>
                                                      completedChallenges
                                                          .contains(id))
                                                  .length;
                                          final totalForThisCourse =
                                              allChallengeIds.length;
                                          final percent = totalForThisCourse > 0
                                              ? ((completedForThisCourse /
                                                          totalForThisCourse) *
                                                      100)
                                                  .clamp(0.0, 100.0)
                                              : 0.0;
                                          return Card(
                                            elevation: 3,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
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
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    course['description'] ?? '',
                                                    style: const TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child:
                                                            LinearProgressIndicator(
                                                          value: (percent / 100)
                                                              .clamp(0.0, 1.0),
                                                          minHeight: 8,
                                                          backgroundColor:
                                                              Colors.grey[200],
                                                          color: Colors.green,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                          '${percent.toStringAsFixed(0)}%',
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ],
                                                  ),
                                                  if (percent == 100.0)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 8.0),
                                                      child: Row(
                                                        children: const [
                                                          Icon(Icons.verified,
                                                              color:
                                                                  Colors.green,
                                                              size: 18),
                                                          SizedBox(width: 6),
                                                          Text('Completed',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .green,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold)),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      const Divider(height: 32, thickness: 1.2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Overall Progress',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                                fontSize: 16)),
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('enrollments')
                            .where('studentId', isEqualTo: userId)
                            .get(),
                        builder: (context, enrollmentsSnapshot) {
                          if (!enrollmentsSnapshot.hasData ||
                              enrollmentsSnapshot.data!.docs.isEmpty) {
                            return const Text(
                                'You are not enrolled in any courses.');
                          }
                          final enrollments = enrollmentsSnapshot.data!.docs;
                          return FutureBuilder<List<Map<String, dynamic>>>(
                            future: Future.wait(
                                enrollments.map((enrollmentDoc) async {
                              final enrollment =
                                  enrollmentDoc.data() as Map<String, dynamic>;
                              final courseId = enrollment['courseId'];
                              // Get progress for this course
                              final progressDoc = await FirebaseFirestore
                                  .instance
                                  .collection('progress')
                                  .doc(userId + '_' + courseId)
                                  .get();
                              final progressData =
                                  progressDoc.data() as Map<String, dynamic>?;
                              final completedChallenges =
                                  progressData != null &&
                                          progressData['completedChallenges']
                                              is List
                                      ? List<String>.from(
                                          progressData['completedChallenges'])
                                      : <String>[];
                              // Get total challenges for this course
                              final challengesQuery = await FirebaseFirestore
                                  .instance
                                  .collection('challenges')
                                  .where('courseId', isEqualTo: courseId)
                                  .get();
                              final totalChallenges =
                                  challengesQuery.docs.length;
                              return {
                                'completed': completedChallenges.length,
                                'total': totalChallenges,
                              };
                            })),
                            builder: (context, courseProgressSnapshot) {
                              if (!courseProgressSnapshot.hasData) {
                                return const SizedBox();
                              }
                              final courseProgress =
                                  courseProgressSnapshot.data!;
                              final totalCompleted = courseProgress.fold<int>(
                                  0, (sum, c) => sum + (c['completed'] as int));
                              final totalChallenges = courseProgress.fold<int>(
                                  0, (sum, c) => sum + (c['total'] as int));
                              final percent = totalChallenges > 0
                                  ? ((totalCompleted / totalChallenges) * 100)
                                      .clamp(0.0, 100.0)
                                  : 0.0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          value:
                                              (percent / 100).clamp(0.0, 1.0),
                                          minHeight: 8,
                                          backgroundColor: Colors.grey[200],
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text('${percent.toStringAsFixed(0)}%',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Completed $totalCompleted out of $totalChallenges challenges'),
                                ],
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
                          OutlinedButton.icon(
                            onPressed: () {
                              // TODO: Delete account
                            },
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            label: const Text('Delete Account'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red),
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
