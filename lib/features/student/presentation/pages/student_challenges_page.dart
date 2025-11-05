import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/challenges/domain/models/challenge_model.dart';
import 'package:codequest/features/challenges/data/challenge_repository.dart';
import 'package:codequest/features/student/presentation/pages/challenge_detail_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import '../../../../../widgets/certificate_dialog.dart';

class StudentChallengesPage extends StatefulWidget {
  const StudentChallengesPage({Key? key}) : super(key: key);

  @override
  State<StudentChallengesPage> createState() => _StudentChallengesPageState();
}

class _StudentChallengesPageState extends State<StudentChallengesPage> {
  final _challengeRepository = ChallengeRepository(FirebaseFirestore.instance);
  Map<String, dynamic> _userProgress = {
    'currentLesson': 1,
    'highestLesson': 1,
    'completedChallenges': [],
  };
  List<String> _enrolledCourseIds = [];
  bool _showCertificate = false;
  Map<String, String> _courseNames = {};
  bool _isLoadingCourseNames = false;
  String? _completedCourseId;
  String? _completedCourseName;
  String? _completedCourseAuthor;
  String? _studentName;
  // Helper to load per-course progress
  Map<String, Map<String, dynamic>> _courseProgress = {};
  bool _isLoadingStudentName = false;
  // Prevent multiple dialogs
  final Set<String> _shownCertificateDialogs = {};
  String? _selectedCourseId;
  int? _selectedLesson;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEnrolledCourses().then((_) {
      // After loading enrolled courses, load course-specific progress
      _loadAllCourseProgress();
      // Then load user progress
      _loadUserProgress();
      // Add listeners for course-specific progress updates
      _addCourseProgressListeners();
    });

    // Add progress listener to automatically check lesson completion
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _challengeRepository.getUserProgress(user.uid).listen((progress) {
        setState(() {
          _userProgress = progress;
        });
        // Check lesson completion whenever progress is updated
        _checkLessonCompletionFromProgress();
      });
    }
    _loadStudentName();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('progress')
        .doc(user.uid)
        .get();
    setState(() {
      _userProgress = doc.data() ??
          {
            'currentLesson': 1,
            'completedChallenges': [],
          };
    });

    // Check lesson completion after loading progress
    await _checkLessonCompletionFromProgress();
  }

  Future<void> _checkLessonCompletionFromProgress() async {
    if (_enrolledCourseIds.isEmpty) return;

    // Get all challenges for all enrolled courses
    final challengesSnapshot = await FirebaseFirestore.instance
        .collection('challenges')
        .where('courseId', whereIn: _enrolledCourseIds)
        .get();

    final challenges = challengesSnapshot.docs
        .map((doc) => ChallengeModel.fromJson({
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            }))
        .toList();

    // Check lesson completion for all courses
    await _checkLessonCompletion(challenges);
  }

  Future<void> _loadEnrolledCourses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('enrollments')
        .where('studentId', isEqualTo: user.uid)
        .get();

    final courseIds =
        snapshot.docs.map((doc) => doc['courseId'] as String).toList();

    setState(() {
      _enrolledCourseIds = courseIds;
    });

    // Load course names for all enrolled courses
    await _loadCourseNames(courseIds);
  }

  Future<void> _loadCourseNames(List<String> courseIds) async {
    if (courseIds.isEmpty) return;

    try {
      setState(() {
        _isLoadingCourseNames = true;
      });

      // Load course names in parallel
      final courseDocs = await Future.wait(courseIds.map((courseId) =>
          FirebaseFirestore.instance
              .collection('courses')
              .doc(courseId)
              .get()));

      final Map<String, String> courseNames = {};
      for (int i = 0; i < courseIds.length; i++) {
        final courseId = courseIds[i];
        final courseDoc = courseDocs[i];
        if (courseDoc.exists) {
          final title = courseDoc.data()?['title'];
          courseNames[courseId] =
              (title != null && title.toString().trim().isNotEmpty)
                  ? title
                  : '';
        } else {
          courseNames[courseId] = '';
        }
      }

      setState(() {
        _courseNames.addAll(courseNames);
        _isLoadingCourseNames = false;
      });
    } catch (e) {
      print('Error loading course names: $e');
      // Set fallback names
      final Map<String, String> fallbackNames = {
        for (final courseId in courseIds) courseId: courseId
      };
      setState(() {
        _courseNames.addAll(fallbackNames);
        _isLoadingCourseNames = false;
      });
    }
  }

  Future<void> _loadStudentName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() {
        _isLoadingStudentName = true;
      });

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        print('User data loaded: $userData');

        // Try to construct full name from firstName and lastName
        final firstName = userData['firstName'] ?? userData['first_name'] ?? '';
        final lastName = userData['lastName'] ?? userData['last_name'] ?? '';

        String fullName = '';

        if (firstName.isNotEmpty && lastName.isNotEmpty) {
          // Construct full name from first and last name
          fullName = '$firstName $lastName';
        } else if (firstName.isNotEmpty) {
          // Only first name available
          fullName = firstName;
        } else if (lastName.isNotEmpty) {
          // Only last name available
          fullName = lastName;
        } else {
          // Try other name fields as fallbacks
          fullName = userData['fullName'] ??
              userData['full_name'] ??
              userData['name'] ??
              userData['displayName'] ??
              user.email ??
              'Unknown';
        }

        print('Student name set to: $fullName');
        setState(() {
          _studentName = fullName;
          _isLoadingStudentName = false;
        });
      } else {
        print('User document does not exist, using email: ${user.email}');
        setState(() {
          _studentName = user.email ?? 'Unknown';
          _isLoadingStudentName = false;
        });
      }
    } catch (e) {
      print('Error loading student name: $e');
      setState(() {
        _studentName = user.email ?? 'Unknown';
        _isLoadingStudentName = false;
      });
    }
  }

  void _showChallengeDetails(ChallengeModel challenge) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChallengeDetailPage(
          challenge: challenge,
          onChallengePassed: () async {
            await _loadAllCourseProgress();
            await _checkLessonCompletionFromProgress();
          },
        ),
      ),
    );
  }

  Future<void> _showCertificateDialog() async {
    if (_completedCourseId != null) {
      final courseAuthor = await _fetchCourseAuthor(_completedCourseId!);
      final courseCreator = await _fetchCourseCreator(_completedCourseId!);
      setState(() {
        _completedCourseAuthor = courseAuthor;
      });

      // Use course creator as the signing teacher, fallback to course author if no creator
      final signingTeacher =
          courseCreator.isNotEmpty ? courseCreator : courseAuthor;

      // Debug: Print what we're passing to CertificateDialog
      print('=== _showCertificateDialog Debug ===');
      print('Course ID: $_completedCourseId');
      print('Course Author: $courseAuthor');
      print('Course Creator: $courseCreator');
      print('Signing Teacher: $signingTeacher');
      print('Student Name: $_studentName');
      print('Course Name: $_completedCourseName');

      showDialog(
        context: context,
        builder: (context) => CertificateDialog(
          studentName: _studentName ?? 'Student',
          courseName: _completedCourseName ?? 'Course',
          teacherName: signingTeacher, // Use course creator as signing teacher
          allowDigitalSignature:
              true, // Allow digital signature for course creator
          completionDate: DateTime.now(), // Use current date as completion date
          courseAuthor: _completedCourseAuthor,
        ),
      );
    }
  }

  Future<void> _checkLessonCompletion(List<ChallengeModel> challenges) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Group challenges by course
    final Map<String, List<ChallengeModel>> courseChallenges = {};
    for (var challenge in challenges) {
      if (challenge.courseId != null) {
        courseChallenges
            .putIfAbsent(challenge.courseId!, () => [])
            .add(challenge);
      }
    }

    // Check lesson completion for each course separately
    for (final courseId in courseChallenges.keys) {
      await _checkCourseLessonCompletion(courseId, courseChallenges[courseId]!);
    }
  }

  Future<void> _checkCourseLessonCompletion(
      String courseId, List<ChallengeModel> courseChallenges) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get course-specific progress
    final courseProgress = _courseProgress[courseId] ??
        {'currentLesson': 1, 'completedChallenges': []};
    final currentLesson = courseProgress['currentLesson'] ?? 1;
    final completedChallenges =
        List<String>.from(courseProgress['completedChallenges'] ?? []);

    print('Checking lesson completion for course $courseId:');
    print('  Current lesson: $currentLesson');
    print('  Completed challenges: $completedChallenges');

    // Check if current lesson is completed
    final lessonChallenges =
        courseChallenges.where((c) => c.lesson == currentLesson).toList();
    final allPassed =
        lessonChallenges.every((c) => completedChallenges.contains(c.id));

    print(
        '  Lesson $currentLesson challenges: ${lessonChallenges.map((c) => c.id).toList()}');
    print('  All passed: $allPassed');

    if (allPassed) {
      // Check if there are higher lesson challenges
      final nextLessonChallenges =
          courseChallenges.where((c) => c.lesson == currentLesson + 1).toList();

      if (nextLessonChallenges.isNotEmpty) {
        print('  Advancing to lesson ${currentLesson + 1}');
        // Advance to next lesson for this course
        await FirebaseFirestore.instance
            .collection('progress')
            .doc('${user.uid}_$courseId')
            .update({'currentLesson': currentLesson + 1});

        // Update local state
        setState(() {
          _courseProgress[courseId] = {
            ..._courseProgress[courseId] ?? {},
            'currentLesson': currentLesson + 1,
          };
        });

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Module Up!'),
              content: Text(
                  'Congratulations! You unlocked Module ${currentLesson + 1} in ${_courseNames[courseId] ?? 'this course'}!'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        // Check if all required lessons (1-4) are completed for this course
        final requiredLessons = [1, 2, 3, 4];
        bool allRequiredLessonsPassed = requiredLessons.every((lessonNum) {
          final lessonChallenges =
              courseChallenges.where((c) => c.lesson == lessonNum).toList();
          return lessonChallenges.isNotEmpty &&
              lessonChallenges.every((c) => completedChallenges.contains(c.id));
        });

        print('  Required lessons: $requiredLessons');
        print('  All required lessons passed: $allRequiredLessonsPassed');

        // Check if summative evaluation is completed
        final summativeChallenges =
            courseChallenges.where((c) => c.isSummative).toList();
        bool summativeCompleted = false;

        if (summativeChallenges.isNotEmpty) {
          summativeCompleted = summativeChallenges
              .every((c) => completedChallenges.contains(c.id));
          print(
              '  Summative challenges: ${summativeChallenges.map((c) => c.id).toList()}');
          print('  Summative completed: $summativeCompleted');
        } else {
          // If no summative challenges exist, summative is NOT completed
          // This ensures summative evaluation is truly required
          summativeCompleted = false;
          print('  No summative challenges found, summative NOT completed');
        }

        if (allRequiredLessonsPassed && summativeCompleted) {
          print(
              'All required lessons and summative evaluation passed for course $courseId!');
          // All required lessons (1-4) and summative evaluation completed for this course
          final enrollmentQuery = await FirebaseFirestore.instance
              .collection('enrollments')
              .where('studentId', isEqualTo: user.uid)
              .where('courseId', isEqualTo: courseId)
              .get();
          for (var doc in enrollmentQuery.docs) {
            await doc.reference.update({
              'completed': true,
              'completedAt': FieldValue.serverTimestamp(),
            });
          }

          // Get course name for certificate
          final courseName = await _getCourseName(courseId);
          setState(() {
            _showCertificate = true;
            _completedCourseId = courseId;
            _completedCourseName = courseName;
          });
        } else if (allRequiredLessonsPassed && !summativeCompleted) {
          // Show message about summative requirement - NO certificate awarded
          print(
              'All lessons completed but summative evaluation required - NO certificate awarded');
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Summative Evaluation Required'),
                content: Text(
                    'You have completed all modules for ${_courseNames[courseId] ?? 'this course'}! '
                    'However, you must also pass the summative evaluation to receive your certificate. '
                    'Please contact your teacher to assign the final evaluation, or wait for it to be made available.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      }
    }
  }

  bool _isLessonSummative(List<ChallengeModel> challenges) {
    return challenges.any((challenge) => challenge.isSummative);
  }

  Future<String> _getCourseName(String courseId) async {
    if (_courseNames.containsKey(courseId)) {
      return _courseNames[courseId]!;
    }
    final doc = await FirebaseFirestore.instance
        .collection('courses')
        .doc(courseId)
        .get();
    final name = doc.data()?['title'] ?? courseId;
    _courseNames[courseId] = name;
    return name;
  }

  // After a challenge is passed, reload course progress and check lesson completion
  void _continueToNextChallenge() {
    setState(() {
      _showCertificate = false;
    });
    // Refresh the page to show next lesson or available challenges
    _loadAllCourseProgress().then((_) => _checkLessonCompletionFromProgress());
  }

  Future<void> _loadAllCourseProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_enrolledCourseIds.isEmpty) return;
    final progressSnapshots = await Future.wait(_enrolledCourseIds.map(
        (courseId) => FirebaseFirestore.instance
            .collection('progress')
            .doc('${user.uid}_$courseId')
            .get()));
    setState(() {
      _courseProgress = {
        for (int i = 0; i < _enrolledCourseIds.length; i++)
          _enrolledCourseIds[i]: progressSnapshots[i].data() ??
              {
                'currentLesson': 1,
                'completedChallenges': [],
              }
      };
    });
  }

  // Helper to ensure course names are loaded for all enrolled courses
  Future<void> _ensureCourseNamesLoaded() async {
    for (final courseId in _enrolledCourseIds) {
      if (!_courseNames.containsKey(courseId)) {
        final doc = await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .get();
        final name = doc.data()?['title'] ?? courseId;
        setState(() {
          _courseNames[courseId] = name;
        });
      }
    }
  }

  // Show certificate dialog for a specific course
  Future<void> _showCourseCertificateDialog(String courseId) async {
    print('Showing certificate dialog for course: $courseId');
    print('Student name in dialog: $_studentName');

    // Ensure student name is loaded
    if (_studentName == null || _studentName!.isEmpty) {
      print('Student name not loaded, loading now...');
      await _loadStudentName();
      print('Student name after loading: $_studentName');
    }

    // Get the course creator/author who should sign the certificate
    final courseCreator = await _fetchCourseCreator(courseId);
    final courseAuthor = await _fetchCourseAuthor(courseId);

    // Debug: Print what we found
    print('=== Certificate Dialog Debug ===');
    print('Course ID: $courseId');
    print('Course Creator: $courseCreator');
    print('Course Author: $courseAuthor');
    print('Student Name: $_studentName');
    print('Course Name: ${_courseNames[courseId]}');

    // Use course creator as the signing teacher, fallback to course author if no creator
    final signingTeacher =
        courseCreator.isNotEmpty ? courseCreator : courseAuthor;

    print('Signing Teacher: $signingTeacher');

    await showDialog(
      context: context,
      builder: (context) => CertificateDialog(
        studentName: _studentName ?? 'Student',
        courseName: _courseNames[courseId] ?? 'Course',
        teacherName: signingTeacher, // Use course creator as signing teacher
        allowDigitalSignature:
            true, // Allow digital signature for course creator
        completionDate: DateTime.now(), // Use current date as completion date
        courseAuthor: courseAuthor,
      ),
    );
  }

  Future<String> _fetchCourseTeacherName(String courseId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(courseId)
          .get();
      final name = doc.data()?['teacherName'] as String?;
      return name ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<String> _fetchCourseAuthor(String courseId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(courseId)
          .get();
      final author = doc.data()?['author'] as String?;
      return author ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<String> _fetchCourseCreator(String courseId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(courseId)
          .get();

      // Debug: Print all available fields
      print('=== Course Data for $courseId ===');
      print('All fields: ${doc.data()?.keys.toList()}');

      // Try different possible field names for course creator
      final creator = doc.data()?['creator'] as String? ??
          doc.data()?['author'] as String? ??
          doc.data()?['teacherName'] as String? ??
          doc.data()?['instructor'] as String? ??
          doc.data()?['createdBy'] as String?;

      print('Found creator: $creator');
      return creator ?? '';
    } catch (e) {
      print('Error fetching course creator: $e');
      return '';
    }
  }

  void _showCourseCompletionDisclaimer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[700], size: 24),
            const SizedBox(width: 8),
            const Text('Important Disclaimer'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Course Completion Notice',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'While you have successfully completed all challenges and the summative evaluation in this course, please note that:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Important:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Completing all challenges does not guarantee course passing\n'
                    '• Final course grades are determined by your teacher\n'
                    '• Additional factors may be considered in final assessment\n'
                    '• This certificate represents challenge completion only',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please consult with your teacher regarding your final course status and any additional requirements.',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I Understand'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getDifficultyColor(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return Colors.green;
      case ChallengeDifficulty.medium:
        return Colors.orange;
      case ChallengeDifficulty.hard:
        return Colors.red;
    }
  }

  // Static method to check lesson completion from other pages
  static Future<void> checkLessonCompletionAfterChallenge(
      String challengeId, String courseId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get the challenge details
      final challengeDoc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(challengeId)
          .get();

      if (!challengeDoc.exists) return;

      final challenge = ChallengeModel.fromJson({
        'id': challengeDoc.id,
        ...challengeDoc.data() as Map<String, dynamic>,
      });

      // Get all challenges for the course
      final challengesSnapshot = await FirebaseFirestore.instance
          .collection('challenges')
          .where('courseId', isEqualTo: courseId)
          .get();

      final challenges = challengesSnapshot.docs
          .map((doc) => ChallengeModel.fromJson({
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              }))
          .toList();

      // Get user progress
      final progressDoc = await FirebaseFirestore.instance
          .collection('progress')
          .doc(user.uid)
          .get();

      final userProgress = progressDoc.data() ??
          {
            'currentLesson': 1,
            'completedChallenges': [],
          };

      // Check if all challenges in the current lesson are completed
      final currentLesson = userProgress['currentLesson'] ?? 1;
      final completedChallenges =
          List<String>.from(userProgress['completedChallenges'] ?? []);

      final lessonChallenges = challenges
          .where((c) => c.lesson == currentLesson && c.courseId == courseId)
          .toList();

      final allPassed =
          lessonChallenges.every((c) => completedChallenges.contains(c.id));

      if (allPassed) {
        // Check if all required lessons (1-4) are completed
        final requiredLessons = [1, 2, 3, 4];
        bool allRequiredLessonsPassed = requiredLessons.every((lessonNum) {
          final lessonChallenges = challenges
              .where((c) => c.lesson == lessonNum && c.courseId == courseId)
              .toList();
          return lessonChallenges.isNotEmpty &&
              lessonChallenges.every((c) => completedChallenges.contains(c.id));
        });

        if (allRequiredLessonsPassed) {
          // Check if summative evaluation is completed
          final summativeChallenges = challenges
              .where((c) => c.isSummative && c.courseId == courseId)
              .toList();
          bool summativeCompleted = false;

          if (summativeChallenges.isNotEmpty) {
            summativeCompleted = summativeChallenges
                .every((c) => completedChallenges.contains(c.id));
            print(
                '  Summative challenges: ${summativeChallenges.map((c) => c.id).toList()}');
            print('  Summative completed: $summativeCompleted');
          } else {
            // If no summative challenges exist, summative is NOT completed
            summativeCompleted = false;
            print('  No summative challenges found, summative NOT completed');
          }

          if (summativeCompleted) {
            // All required lessons AND summative evaluation completed - mark course as completed
            final enrollmentQuery = await FirebaseFirestore.instance
                .collection('enrollments')
                .where('studentId', isEqualTo: user.uid)
                .where('courseId', isEqualTo: courseId)
                .get();

            for (var doc in enrollmentQuery.docs) {
              await doc.reference.update({
                'completed': true,
                'completedAt': FieldValue.serverTimestamp(),
              });
            }

            print(
                'All required lessons and summative evaluation passed for course $courseId!');
          } else {
            // All lessons completed but summative not completed - NO certificate awarded
            print(
                'All lessons completed but summative evaluation required for course: $courseId - NO certificate awarded');
          }
        } else {
          // Move to next lesson
          final nextLessonChallenges = challenges
              .where((c) =>
                  c.lesson == currentLesson + 1 && c.courseId == courseId)
              .toList();

          if (nextLessonChallenges.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('progress')
                .doc(user.uid)
                .update({'currentLesson': currentLesson + 1});
            print('Advanced to lesson ${currentLesson + 1}');
          }
        }
      }
    } catch (e) {
      print('Error checking lesson completion: $e');
    }
  }

  void _addCourseProgressListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _enrolledCourseIds.isEmpty) return;

    // Add listeners for each enrolled course
    for (final courseId in _enrolledCourseIds) {
      FirebaseFirestore.instance
          .collection('progress')
          .doc('${user.uid}_$courseId')
          .snapshots()
          .listen((doc) {
        if (doc.exists) {
          final data = doc.data() ??
              {
                'currentLesson': 1,
                'completedChallenges': [],
              };
          print('Course progress updated for $courseId: $data');
          setState(() {
            _courseProgress[courseId] = data;
          });
          // Check lesson completion when course progress is updated
          _checkLessonCompletionFromProgress();
        }
      });
    }
  }

  // All PDF certificate generation, download, sharing, and printing code has been removed. Only image and text certificate options remain.

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in.'));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Challenges'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _enrolledCourseIds.isEmpty
          ? const Center(child: Text('You are not enrolled in any courses.'))
          : Container(
              color: Colors.white, // Set background color to white
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search challenges...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0, horizontal: 12),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value.trim();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.filter_list, size: 28),
                          tooltip: 'Filter',
                          onPressed: () async {
                            // Build courseLessonMap for filter UI
                            final courseLessonMap = <String, Set<int>>{};
                            for (final courseId in _enrolledCourseIds) {
                              courseLessonMap[courseId] = {};
                            }
                            final snapshot = await FirebaseFirestore.instance
                                .collection('challenges')
                                .where('courseId', whereIn: _enrolledCourseIds)
                                .get();
                            for (final doc in snapshot.docs) {
                              final data = doc.data();
                              final courseId = data['courseId'] as String?;
                              final lesson = data['lesson'] as int?;
                              if (courseId != null && lesson != null) {
                                courseLessonMap[courseId]?.add(lesson);
                              }
                            }
                            await showModalBottomSheet(
                              context: context,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20)),
                              ),
                              builder: (context) {
                                List<int> lessons = [];
                                if (_selectedCourseId != null &&
                                    courseLessonMap[_selectedCourseId] !=
                                        null) {
                                  lessons = List<int>.from(
                                      courseLessonMap[_selectedCourseId]!);
                                  lessons.sort();
                                }
                                return StatefulBuilder(
                                  builder: (context, setModalState) {
                                    return Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('Filter by',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18)),
                                          const SizedBox(height: 16),
                                          DropdownButtonFormField<String>(
                                            value: _selectedCourseId,
                                            decoration: const InputDecoration(
                                              labelText: 'Course',
                                              border: OutlineInputBorder(),
                                            ),
                                            items: [
                                              const DropdownMenuItem<String>(
                                                value: null,
                                                child: Text('All Courses'),
                                              ),
                                              ..._enrolledCourseIds.map((id) =>
                                                  DropdownMenuItem<String>(
                                                    value: id,
                                                    child: Text(
                                                        _courseNames[id] ?? id),
                                                  )),
                                            ],
                                            onChanged: (value) {
                                              setModalState(() {
                                                _selectedCourseId = value;
                                                _selectedLesson = null;
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          DropdownButtonFormField<int>(
                                            value: _selectedLesson,
                                            decoration: const InputDecoration(
                                              labelText: 'Module',
                                              border: OutlineInputBorder(),
                                            ),
                                            items: [
                                              const DropdownMenuItem<int>(
                                                value: null,
                                                child: Text('All Modules'),
                                              ),
                                              ...lessons.map((lesson) =>
                                                  DropdownMenuItem<int>(
                                                    value: lesson,
                                                    child: Text(
                                                      lesson == 0
                                                          ? 'Summative'
                                                          : 'Module $lesson',
                                                    ),
                                                  )),
                                            ],
                                            onChanged: (value) {
                                              setModalState(() {
                                                _selectedLesson = value;
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 24),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    setState(() {});
                                                    Navigator.pop(context);
                                                  },
                                                  child: const Text('Apply'),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green,
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () {
                                                    setModalState(() {
                                                      _selectedCourseId = null;
                                                      _selectedLesson = null;
                                                    });
                                                    setState(() {});
                                                    Navigator.pop(context);
                                                  },
                                                  child: const Text('Clear'),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('challenges')
                          .where('courseId', whereIn: _enrolledCourseIds)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                              child: Text('No challenges available.'));
                        }
                        final challenges = snapshot.data!.docs
                            .map((doc) => ChallengeModel.fromJson({
                                  'id': doc.id,
                                  ...doc.data() as Map<String, dynamic>,
                                }))
                            .where((c) =>
                                c.isPublished == null || c.isPublished == true)
                            .toList();
                        // Group challenges by course, then by lesson
                        final Map<String, Map<int, List<ChallengeModel>>>
                            courseLessonMap = {};
                        for (var c in challenges) {
                          if (c.courseId == null) continue;
                          courseLessonMap.putIfAbsent(c.courseId!, () => {});
                          courseLessonMap[c.courseId!]!
                              .putIfAbsent(c.lesson, () => [])
                              .add(c);
                        }
                        // Filter by search and filter state
                        List<String> filteredCourseIds = _enrolledCourseIds;
                        if (_selectedCourseId != null &&
                            _selectedCourseId != '') {
                          filteredCourseIds = [_selectedCourseId!];
                        }
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            for (final courseId in filteredCourseIds)
                              if (courseLessonMap[courseId] != null &&
                                  courseLessonMap[courseId]!.isNotEmpty)
                                Builder(
                                  builder: (context) {
                                    final courseLessons =
                                        courseLessonMap[courseId];
                                    final progress =
                                        _courseProgress[courseId] ??
                                            {
                                              'currentLesson': 1,
                                              'completedChallenges': []
                                            };
                                    final completedChallenges =
                                        List<String>.from(
                                            progress['completedChallenges'] ??
                                                []);

                                    // Determine which lessons the student can access
                                    final currentLesson =
                                        progress['currentLesson'] ?? 1;
                                    final unlockedLessons = <int>{};

                                    // Always unlock lesson 1
                                    unlockedLessons.add(1);

                                    // Check each lesson sequentially
                                    for (int lessonNum = 1;
                                        lessonNum <= 4;
                                        lessonNum++) {
                                      final lessonChallenges =
                                          courseLessonMap[courseId]
                                                  ?[lessonNum] ??
                                              [];
                                      if (lessonChallenges.isNotEmpty) {
                                        final lessonCompleted = lessonChallenges
                                            .every((c) => completedChallenges
                                                .contains(c.id));
                                        if (lessonCompleted) {
                                          unlockedLessons.add(lessonNum);
                                          // If this lesson is completed, unlock the next lesson
                                          if (lessonNum < 4) {
                                            unlockedLessons.add(lessonNum + 1);
                                          }
                                        } else if (lessonNum == currentLesson) {
                                          // Allow access to current lesson even if not completed
                                          unlockedLessons.add(lessonNum);
                                        }
                                      }
                                    }

                                    // Check if all required lessons (1-4) are completed for this course
                                    final requiredLessons = [1, 2, 3, 4];
                                    bool allRequiredLessonsPassed =
                                        requiredLessons.every((lessonNum) {
                                      final lessonChallenges =
                                          courseLessonMap[courseId]
                                                  ?[lessonNum] ??
                                              [];
                                      return lessonChallenges.isNotEmpty &&
                                          lessonChallenges.every((c) =>
                                              completedChallenges
                                                  .contains(c.id));
                                    });

                                    // If all lessons are completed, unlock all lessons for review
                                    if (allRequiredLessonsPassed) {
                                      // Unlock all lessons for review when course is completed
                                      for (final lessonNum
                                          in (courseLessonMap[courseId]?.keys ??
                                                  <int>[])
                                              .cast<int>()) {
                                        unlockedLessons.add(lessonNum);
                                        print(
                                            'Unlocking lesson $lessonNum for review in completed course $courseId');
                                      }
                                    }

                                    print(
                                        'Course $courseId - Unlocked lessons: $unlockedLessons');
                                    print(
                                        'Course $courseId - All required lessons passed: $allRequiredLessonsPassed');
                                    print(
                                        'Course $courseId - Completed challenges: $completedChallenges');
                                    // Calculate course progress (excluding summative challenges)
                                    final allChallenges =
                                        courseLessonMap[courseId]
                                                ?.values
                                                .expand((x) => x)
                                                .toList() ??
                                            [];
                                    final regularChallenges = allChallenges
                                        .where((c) => !c.isSummative)
                                        .toList();
                                    final completedRegularChallenges =
                                        regularChallenges
                                            .where((c) => completedChallenges
                                                .contains(c.id))
                                            .length;
                                    final courseProgress =
                                        regularChallenges.isNotEmpty
                                            ? completedRegularChallenges /
                                                regularChallenges.length
                                            : 0.0;

                                    // Check if summative evaluation is completed
                                    final summativeChallenges = challenges
                                        .where((c) =>
                                            c.isSummative &&
                                            c.courseId == courseId)
                                        .toList();
                                    bool summativeCompleted = false;

                                    if (summativeChallenges.isNotEmpty) {
                                      summativeCompleted = summativeChallenges
                                          .every((c) => completedChallenges
                                              .contains(c.id));
                                    }

                                    // Certificate should only be shown when both regular lessons AND summative are completed
                                    bool canShowCertificate =
                                        courseProgress == 1.0 &&
                                            summativeCompleted;

                                    // Add congratulations message when all challenges are completed
                                    List<Widget> courseContent = [];

                                    if (canShowCertificate) {
                                      return Card(
                                        elevation: 4,
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 24,
                                                    backgroundColor:
                                                        Colors.blue[50],
                                                    child: Icon(Icons.school,
                                                        color:
                                                            Colors.green[700],
                                                        size: 28),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Text(
                                                      _courseNames[courseId] ??
                                                          'Loading course...',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 20,
                                                          color: Color.fromARGB(
                                                              255, 0, 0, 0)),
                                                      maxLines: 3,
                                                      softWrap: true,
                                                      overflow:
                                                          TextOverflow.visible,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              LinearProgressIndicator(
                                                value: 1.0,
                                                backgroundColor:
                                                    Colors.grey[200],
                                                color: Colors.green,
                                                minHeight: 8,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              const SizedBox(height: 8),
                                              Text('Progress: 100%',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[700])),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  TextButton.icon(
                                                    icon: Icon(Icons.visibility,
                                                        color:
                                                            Colors.amber[800]),
                                                    label: Text(
                                                        'View Certificate',
                                                        style: TextStyle(
                                                            color: Colors
                                                                .amber[800])),
                                                    style: TextButton.styleFrom(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 0),
                                                      minimumSize:
                                                          const Size(0, 32),
                                                    ),
                                                    onPressed: () async {
                                                      if (Navigator.of(context,
                                                              rootNavigator:
                                                                  true)
                                                          .canPop()) {
                                                        Navigator.of(context,
                                                                rootNavigator:
                                                                    true)
                                                            .pop();
                                                        await Future.delayed(
                                                            const Duration(
                                                                milliseconds:
                                                                    200));
                                                      }
                                                      _showCourseCertificateDialog(
                                                          courseId);
                                                    },
                                                  ),
                                                  const Spacer(),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12,
                                                        vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green[100],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Text(
                                                      'Completed',
                                                      style: TextStyle(
                                                        color:
                                                            Colors.green[800],
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: Colors.green[50],
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color:
                                                          Colors.green[200]!),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.celebration,
                                                        color:
                                                            Colors.green[600],
                                                        size: 24),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            '🎉 Congratulations! 🎉',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Colors
                                                                  .green[800],
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                            'You have successfully completed all challenges in this course! '
                                                            'You can review all challenges and download your certificate.',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .green[700],
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
                                                          GestureDetector(
                                                            onTap: () {
                                                              _showCourseCompletionDisclaimer();
                                                            },
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 12,
                                                                vertical: 6,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .blue[100],
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                                border:
                                                                    Border.all(
                                                                  color: Colors
                                                                          .blue[
                                                                      300]!,
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Icon(
                                                                    Icons
                                                                        .info_outline,
                                                                    color: Colors
                                                                            .blue[
                                                                        700],
                                                                    size: 16,
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 6),
                                                                  Text(
                                                                    'Important Notice',
                                                                    style:
                                                                        TextStyle(
                                                                      color: Colors
                                                                              .blue[
                                                                          700],
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
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

                                    return Card(
                                      elevation: 4,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 24,
                                                  backgroundColor:
                                                      Colors.blue[50],
                                                  child: Icon(Icons.school,
                                                      color: Colors.green[700],
                                                      size: 28),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Text(
                                                    _courseNames[courseId] ??
                                                        'Loading course...',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 20,
                                                        color: Color.fromARGB(
                                                            255, 0, 0, 0)),
                                                    maxLines: 3,
                                                    softWrap: true,
                                                    overflow:
                                                        TextOverflow.visible,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            LinearProgressIndicator(
                                              value: courseProgress,
                                              backgroundColor: Colors.grey[200],
                                              color: Colors.green,
                                              minHeight: 8,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                                'Progress: ${(courseProgress * 100).toStringAsFixed(0)}%',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[700])),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                if (canShowCertificate)
                                                  TextButton.icon(
                                                    icon: Icon(Icons.visibility,
                                                        color:
                                                            Colors.amber[800]),
                                                    label: Text(
                                                        'View Certificate',
                                                        style: TextStyle(
                                                            color: Colors
                                                                .amber[800])),
                                                    style: TextButton.styleFrom(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 0),
                                                      minimumSize:
                                                          const Size(0, 32),
                                                    ),
                                                    onPressed: () async {
                                                      if (Navigator.of(context,
                                                              rootNavigator:
                                                                  true)
                                                          .canPop()) {
                                                        Navigator.of(context,
                                                                rootNavigator:
                                                                    true)
                                                            .pop();
                                                        await Future.delayed(
                                                            const Duration(
                                                                milliseconds:
                                                                    200));
                                                      }
                                                      _showCourseCertificateDialog(
                                                          courseId);
                                                    },
                                                  ),
                                                const Spacer(),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: canShowCertificate
                                                        ? Colors.green[100]
                                                        : Colors.blue[100],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    canShowCertificate
                                                        ? 'Completed'
                                                        : 'In Progress',
                                                    style: TextStyle(
                                                      color: canShowCertificate
                                                          ? Colors.green[800]
                                                          : Colors.blue[800],
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            if (courseLessonMap[courseId] !=
                                                null) ...[
                                              // Debug logging
                                              Builder(
                                                builder: (context) {
                                                  final availableLessons =
                                                      courseLessonMap[courseId]!
                                                          .keys
                                                          .toList()
                                                        ..sort();
                                                  print(
                                                      'Course $courseId - Available lessons: $availableLessons');
                                                  print(
                                                      'Course $courseId - Unlocked lessons: $unlockedLessons');
                                                  return const SizedBox
                                                      .shrink();
                                                },
                                              ),
                                              for (final lesson
                                                  in (courseLessonMap[courseId]!
                                                      .keys
                                                      .toList()
                                                    ..sort()))
                                                if (unlockedLessons
                                                    .contains(lesson))
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 6.0),
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                                _isLessonSummative(
                                                                        courseLessonMap[courseId]![lesson] ??
                                                                            [])
                                                                    ? Icons
                                                                        .assignment_turned_in
                                                                    : Icons
                                                                        .menu_book,
                                                                color: _isLessonSummative(
                                                                        courseLessonMap[courseId]![lesson] ??
                                                                            [])
                                                                    ? Colors.orange[
                                                                        700]
                                                                    : Colors.amber[
                                                                        700]),
                                                            const SizedBox(
                                                                width: 8),
                                                            Text(
                                                              _isLessonSummative(
                                                                      courseLessonMap[courseId]![
                                                                              lesson] ??
                                                                          [])
                                                                  ? 'Summative'
                                                                  : 'Module $lesson',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16,
                                                                color: _isLessonSummative(
                                                                        courseLessonMap[courseId]![lesson] ??
                                                                            [])
                                                                    ? Colors.orange[
                                                                        800]
                                                                    : Colors.amber[
                                                                        800],
                                                              ),
                                                            ),
                                                            // Show lock status for lessons
                                                            if (lesson > 0 &&
                                                                lesson <= 4)
                                                              Container(
                                                                margin:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            8),
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: lesson ==
                                                                          currentLesson
                                                                      ? Colors.blue[
                                                                          100]
                                                                      : Colors.green[
                                                                          100],
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              12),
                                                                ),
                                                                child: Text(
                                                                  lesson ==
                                                                          currentLesson
                                                                      ? 'CURRENT'
                                                                      : 'COMPLETED',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: lesson ==
                                                                            currentLesson
                                                                        ? Colors.blue[
                                                                            700]
                                                                        : Colors
                                                                            .green[700],
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      // Show message for locked lessons
                                                      if (!unlockedLessons
                                                              .contains(
                                                                  lesson) &&
                                                          lesson > 0 &&
                                                          lesson <= 4)
                                                        Container(
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top: 8,
                                                                  bottom: 16),
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(12),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .grey[100],
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            border: Border.all(
                                                                color:
                                                                    Colors.grey[
                                                                        300]!),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Icon(Icons.lock,
                                                                  color: Colors
                                                                          .grey[
                                                                      600],
                                                                  size: 16),
                                                              const SizedBox(
                                                                  width: 8),
                                                              Expanded(
                                                                child: Text(
                                                                  'Complete Lesson ${lesson - 1} first to unlock this lesson',
                                                                  style:
                                                                      TextStyle(
                                                                    color: Colors
                                                                            .grey[
                                                                        600],
                                                                    fontSize:
                                                                        14,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      // Render challenges for this lesson
                                                      Wrap(
                                                        spacing: 12,
                                                        runSpacing: 12,
                                                        children: [
                                                          for (final challenge
                                                              in courseLessonMap[
                                                                          courseId]![
                                                                      lesson] ??
                                                                  [])
                                                            // Show all challenges for review when lessons are completed
                                                            if (_searchQuery
                                                                    .isEmpty ||
                                                                challenge.title
                                                                    .toLowerCase()
                                                                    .contains(
                                                                        _searchQuery
                                                                            .toLowerCase()) ||
                                                                challenge
                                                                    .description
                                                                    .toLowerCase()
                                                                    .contains(
                                                                        _searchQuery
                                                                            .toLowerCase()))
                                                              Builder(
                                                                builder:
                                                                    (context) {
                                                                  if (challenge
                                                                      .isSummative) {
                                                                    print(
                                                                        'Displaying summative challenge: ${challenge.title} for lesson $lesson');
                                                                  }
                                                                  return SizedBox(
                                                                    width: 340,
                                                                    child: Card(
                                                                      elevation:
                                                                          2,
                                                                      shape:
                                                                          RoundedRectangleBorder(
                                                                        borderRadius:
                                                                            BorderRadius.circular(12),
                                                                      ),
                                                                      color: completedChallenges.contains(challenge
                                                                              .id)
                                                                          ? (challenge.isSummative
                                                                              ? Colors.orange[50]
                                                                              : Colors.green[50])
                                                                          : Colors.white,
                                                                      child:
                                                                          Stack(
                                                                        children: [
                                                                          ListTile(
                                                                            leading:
                                                                                Icon(
                                                                              completedChallenges.contains(challenge.id) ? Icons.check_circle : (challenge.isSummative ? Icons.assignment_turned_in : Icons.code),
                                                                              color: completedChallenges.contains(challenge.id) ? (challenge.isSummative ? Colors.orange : Colors.green) : (challenge.isSummative ? Colors.orange[600] : Colors.blue),
                                                                            ),
                                                                            title:
                                                                                Row(
                                                                              children: [
                                                                                Expanded(
                                                                                  child: Text(
                                                                                    challenge.title,
                                                                                    style: TextStyle(
                                                                                      fontWeight: FontWeight.bold,
                                                                                      color: challenge.isSummative ? Colors.orange[800] : Colors.black87,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                if (challenge.isSummative)
                                                                                  Container(
                                                                                    padding: const EdgeInsets.symmetric(
                                                                                      horizontal: 6,
                                                                                      vertical: 2,
                                                                                    ),
                                                                                    decoration: BoxDecoration(
                                                                                      color: Colors.orange[100],
                                                                                      borderRadius: BorderRadius.circular(8),
                                                                                    ),
                                                                                    child: Text(
                                                                                      'SUMMATIVE',
                                                                                      style: TextStyle(
                                                                                        fontSize: 8,
                                                                                        fontWeight: FontWeight.bold,
                                                                                        color: Colors.orange[700],
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                              ],
                                                                            ),
                                                                            subtitle:
                                                                                Column(
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Text(
                                                                                  challenge.description,
                                                                                  maxLines: 2,
                                                                                  overflow: TextOverflow.ellipsis,
                                                                                  style: TextStyle(
                                                                                    color: challenge.isSummative ? Colors.orange[600] : Colors.grey[600],
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                            trailing:
                                                                                Icon(
                                                                              Icons.arrow_forward_ios,
                                                                              size: 16,
                                                                              color: challenge.isSummative ? Colors.orange[600] : Colors.grey[400],
                                                                            ),
                                                                            onTap:
                                                                                () {
                                                                              // Check if lesson is unlocked
                                                                              if (!unlockedLessons.contains(lesson)) {
                                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                                  SnackBar(
                                                                                    content: Text('Complete the previous lesson first to access this challenge.'),
                                                                                    backgroundColor: Colors.orange,
                                                                                  ),
                                                                                );
                                                                                return;
                                                                              }

                                                                              // Allow review of completed challenges but prevent retakes
                                                                              if (completedChallenges.contains(challenge.id)) {
                                                                                // Show review mode message
                                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                                  SnackBar(
                                                                                    content: Text('Opening challenge in review mode. You cannot retake this challenge.'),
                                                                                    backgroundColor: Colors.blue,
                                                                                    duration: Duration(seconds: 2),
                                                                                  ),
                                                                                );
                                                                              }

                                                                              _showChallengeDetails(challenge);
                                                                            },
                                                                          ),
                                                                          if (challenge.isSummative &&
                                                                              !completedChallenges.contains(challenge.id))
                                                                            Positioned(
                                                                              top: 8,
                                                                              right: 8,
                                                                              child: Container(
                                                                                padding: const EdgeInsets.all(4),
                                                                                decoration: BoxDecoration(
                                                                                  color: Colors.orange[200],
                                                                                  shape: BoxShape.circle,
                                                                                ),
                                                                                child: Icon(
                                                                                  Icons.priority_high,
                                                                                  size: 12,
                                                                                  color: Colors.orange[800],
                                                                                ),
                                                                              ),
                                                                            ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                        ],
                                                      ),
                                                      // Show message when all regular lessons are completed
                                                      if (allRequiredLessonsPassed)
                                                        Container(
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top: 16),
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(16),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .green[50],
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            border: Border.all(
                                                                color: Colors
                                                                        .green[
                                                                    200]!),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                  Icons
                                                                      .check_circle,
                                                                  color: Colors
                                                                          .green[
                                                                      600],
                                                                  size: 20),
                                                              const SizedBox(
                                                                  width: 12),
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      'All Regular Lessons Completed!',
                                                                      style:
                                                                          TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: Colors
                                                                            .green[800],
                                                                        fontSize:
                                                                            16,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            4),
                                                                    Text(
                                                                      'Congratulations! You have completed all regular lessons. '
                                                                      'Only summative evaluations are now available. '
                                                                      'Complete the summative to receive your certificate.',
                                                                      style:
                                                                          TextStyle(
                                                                        color: Colors
                                                                            .green[700],
                                                                        fontSize:
                                                                            14,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      // Show message when all lessons are completed but no summative is available
                                                      if (allRequiredLessonsPassed &&
                                                          !courseLessonMap[
                                                                  courseId]!
                                                              .values
                                                              .any((challenges) =>
                                                                  challenges.any(
                                                                      (c) => c
                                                                          .isSummative)))
                                                        Container(
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top: 16),
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(16),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .orange[50],
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            border: Border.all(
                                                                color: Colors
                                                                        .orange[
                                                                    200]!),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                  Icons
                                                                      .assignment_turned_in,
                                                                  color: Colors
                                                                          .orange[
                                                                      600],
                                                                  size: 20),
                                                              const SizedBox(
                                                                  width: 12),
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      'No Summative Available!',
                                                                      style:
                                                                          TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: Colors
                                                                            .orange[800],
                                                                        fontSize:
                                                                            16,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            4),
                                                                    Text(
                                                                      'You have completed all regular lessons, but no summative evaluation is available. '
                                                                      'Please contact your teacher to assign the final evaluation to receive your certificate.',
                                                                      style:
                                                                          TextStyle(
                                                                        color: Colors
                                                                            .orange[700],
                                                                        fontSize:
                                                                            14,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
