import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_event.dart';
import 'package:codequest/config/routes.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:codequest/features/teacher/presentation/pages/teacher_home_page.dart';
import 'package:codequest/features/teacher/presentation/pages/teacher_courses_page.dart';
import 'package:codequest/features/teacher/presentation/pages/teacher_challenges_page.dart';
import 'package:codequest/features/teacher/presentation/pages/teacher_students_page.dart';
import 'package:codequest/features/teacher/presentation/pages/teacher_profile_page.dart';
import 'package:codequest/features/teacher/presentation/pages/teacher_videos_page.dart';
import 'package:codequest/features/teacher/presentation/pages/teacher_forums_page.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/teacher/presentation/widgets/teacher_notification_panel.dart';
import 'package:codequest/services/notification_service.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;
  String? _teacherFullName;
  final _labels = [
    'Dashboard',
    'Courses',
    'Challenges',
    'Videos',
    'Forums',
    'Students'
  ];
  final _icons = [
    Icons.dashboard_rounded,
    Icons.menu_book_rounded,
    Icons.code_rounded,
    Icons.video_library_rounded,
    Icons.forum_rounded,
    Icons.people_rounded
  ];
  final _descriptions = [
    'Overview & Analytics',
    'Manage Your Courses',
    'Courses Challenges',
    'Video Content',
    'Forum Discussions',
    'Student Management'
  ];

  @override
  void initState() {
    super.initState();
    _pages = [
      const TeacherHomePage(),
      const TeacherCoursesPage(),
      const TeacherChallengesPage(),
      const TeacherVideosPage(),
      const TeacherForumsPage(),
      const TeacherStudentsPage(),
    ];
    _fetchTeacherFullName();
  }

  String _sidebarDisplayName() {
    final user = FirebaseAuth.instance.currentUser;
    final source =
        (_teacherFullName != null && _teacherFullName!.trim().isNotEmpty)
            ? _teacherFullName!.trim()
            : (user?.displayName?.trim().isNotEmpty == true
                ? user!.displayName!.trim()
                : (user?.email ?? 'Teacher User'));
    final at = source.indexOf('@');
    return at > 0 ? source.substring(0, at) : source;
  }

  Future<void> _fetchTeacherFullName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      if (data['fullName'] != null &&
          (data['fullName'] as String).trim().isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _teacherFullName = data['fullName'];
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _teacherFullName = user.displayName ?? 'Teacher User';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.zero,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.computer,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Teacher Dashboard',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Available only on web platform',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width > 700;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          if (isWide) _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _pages[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide ? null : _buildBottomNavigation(),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo and Brand Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/CIS SEAL2.png',
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CodeQuest',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Teacher Portal',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // User Profile Section (tap opens Profile page)
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TeacherProfilePage(key: UniqueKey()),
                ),
              );
            },
            borderRadius: BorderRadius.zero,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.school,
                      color: Colors.green[600],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sidebarDisplayName(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Educator',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Navigation Menu
          Expanded(
            child: SingleChildScrollView(
              // Remove or reduce vertical padding here
              padding: const EdgeInsets.only(top: 0, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Remove the SizedBox above the nav items
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'MAIN NAVIGATION',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...List.generate(
                    _labels.length,
                    (index) => _buildNavItem(index),
                  ),
                  const SizedBox(height: 24),
                  // Removed ACCOUNT section header
                  const SizedBox(height: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.zero,
      ),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: Colors.transparent,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green[100] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _icons[index],
            color: isSelected ? Colors.green[600] : Colors.grey[600],
            size: 20,
          ),
        ),
        title: Text(
          _labels[index],
          style: TextStyle(
            color: isSelected ? Colors.green[700] : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          _descriptions[index],
          style: TextStyle(
            color: isSelected ? Colors.green[500] : Colors.grey[500],
            fontSize: 12,
          ),
        ),
        onTap: () => setState(() => _selectedIndex = index),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
      ),
    );
  }

  // Sidebar logout removed; use header settings menu

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Page Title
          Text(
            _labels[_selectedIndex],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Spacer(),

          // User Menu
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => TeacherNotificationPanel(
                      onClose: () => Navigator.of(context).pop(),
                    ),
                  );
                },
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            size: 20,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Unread notification badge
                    Positioned(
                      right: 8,
                      top: 4,
                      child: StreamBuilder<int>(
                        stream: NotificationService
                            .getUnreadTeacherNotificationsCount(
                          FirebaseAuth.instance.currentUser?.uid ?? '',
                        ),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data ?? 0;
                          if (unreadCount == 0) return const SizedBox.shrink();

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Settings menu: Teacher Profile + Logout (professional)
              PopupMenuButton<String>(
                tooltip: 'Settings',
                icon: Icon(Icons.settings_rounded,
                    size: 22, color: Colors.grey[700]),
                splashRadius: 22,
                position: PopupMenuPosition.under,
                offset: const Offset(0, 8),
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                itemBuilder: (context) {
                  final user = FirebaseAuth.instance.currentUser;
                  final name = _teacherFullName?.trim().isNotEmpty == true
                      ? _teacherFullName!.trim()
                      : (user?.displayName ?? 'Teacher User');
                  final email = user?.email ?? '';
                  return [
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.green[100],
                                child: Icon(Icons.person,
                                    color: Colors.green[700], size: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    if (email.isNotEmpty)
                                      Text(email,
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 8),
                    const PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.account_circle_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 8),
                    PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded,
                              size: 18, color: Colors.red[600]),
                          const SizedBox(width: 8),
                          Text('Logout',
                              style: TextStyle(color: Colors.red[700])),
                        ],
                      ),
                    ),
                  ];
                },
                onSelected: (value) {
                  if (value == 'profile') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            TeacherProfilePage(key: UniqueKey()),
                      ),
                    );
                  } else if (value == 'logout') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            Icon(Icons.logout,
                                color: Colors.red[600], size: 24),
                            const SizedBox(width: 8),
                            const Text(
                              'Confirm Logout',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        content: const Text(
                          'Are you sure you want to logout?',
                          style: TextStyle(color: Colors.black87),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel',
                                style: TextStyle(color: Colors.grey[600])),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context
                                  .read<AuthBloc>()
                                  .add(const SignOutRequested());
                              Navigator.pushReplacementNamed(
                                  context, AppRouter.login);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ...List.generate(
                _labels.length,
                (index) => Expanded(
                  child: _buildBottomNavItem(index),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[50] : Colors.transparent,
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _icons[index],
              color: isSelected ? Colors.green[600] : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              _labels[index],
              style: TextStyle(
                color: isSelected ? Colors.green[600] : Colors.grey[600],
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
