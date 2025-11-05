import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_event.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_state.dart';
import 'package:codequest/features/student/presentation/pages/videos_page.dart';
import 'package:codequest/features/student/presentation/pages/forums_page.dart';
import 'package:codequest/features/student/presentation/pages/student_courses_page.dart';
import 'package:codequest/features/student/presentation/pages/student_challenges_page.dart';
import 'package:codequest/features/student/presentation/pages/student_my_courses_page.dart';
import 'package:codequest/features/student/presentation/pages/profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/student/presentation/pages/student_notifications_page.dart';

/// Main entry point for the student dashboard with bottom navigation.
class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({Key? key}) : super(key: key);

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  int _selectedIndex = 0;

  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.school),
      label: 'Courses',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.book),
      label: 'My Courses',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.code),
      label: 'Challenges',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.video_library),
      label: 'Videos',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.forum),
      label: 'Forums',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const StudentCoursesPage(),
      const StudentMyCoursesPage(),
      const StudentChallengesPage(),
      const VideosPage(),
      const ForumsPage(),
      const ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          // Navigate to login page when unauthenticated
          Navigator.of(context).pushReplacementNamed('/');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        if (state is Authenticated) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Student Dashboard'),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              actions: [
                Builder(
                  builder: (context) => StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .where('userId',
                            isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .where('read', isEqualTo: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final unreadCount =
                          snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return IconButton(
                        icon: Stack(
                          children: [
                            const Icon(Icons.notifications),
                            if (unreadCount > 0)
                              Positioned(
                                right: 0,
                                child: CircleAvatar(
                                  radius: 8,
                                  backgroundColor: Colors.red,
                                  child: Text(
                                    '$unreadCount',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        tooltip: 'Notifications',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const StudentNotificationsPage()),
                          );
                        },
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                    context.read<AuthBloc>().add(SignOutRequested());
                  },
                ),
                // Temporary button to create test challenges
                // IconButton(
                //   icon: const Icon(Icons.add_task),
                //   onPressed: () async {
                //     try {
                //       final repository =
                //           ChallengeRepository(FirebaseFirestore.instance);
                //       await repository.createTestChallenges();
                //       if (mounted) {
                //         ScaffoldMessenger.of(context).showSnackBar(
                //           const SnackBar(
                //             content:
                //                 Text('Test challenges created successfully!'),
                //           ),
                //         );
                //       }
                //     } catch (e) {
                //       if (mounted) {
                //         ScaffoldMessenger.of(context).showSnackBar(
                //           SnackBar(
                //             content: Text('Error creating test challenges: $e'),
                //             backgroundColor: Colors.red,
                //           ),
                //         );
                //       }
                //     }
                //   },
                // ),
              ],
            ),
            body: _pages[_selectedIndex],
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              items: _navItems,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.green,
              selectedIconTheme: const IconThemeData(color: Colors.green),
              // For web hover effect (Flutter 3.7+), you can use MaterialStateProperty
              // Uncomment the following if your Flutter version supports it:
              // mouseCursor: MaterialStateProperty.resolveWith<MouseCursor>((states) {
              //   if (states.contains(MaterialState.hovered)) {
              //     return SystemMouseCursors.click;
              //   }
              //   return SystemMouseCursors.basic;
              // }),
            ),
          );
        }

        return const Scaffold(
          body: Center(
            child: Text('Not logged in'),
          ),
        );
      },
    );
  }
}
