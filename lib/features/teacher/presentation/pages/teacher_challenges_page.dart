import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/challenges/domain/models/challenge_model.dart';
import 'package:codequest/features/challenges/presentation/widgets/challenge_form.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:codequest/features/courses/domain/models/course_model.dart';
import 'package:codequest/core/theme/app_theme.dart';

const Color kCourseAccent = AppTheme.accentColor;

Color getDifficultyColor(BuildContext context, String difficulty) {
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return Colors.green;
    case 'medium':
      return Colors.green.shade700;
    case 'hard':
      return Colors.green.shade900;
    default:
      return Colors.green;
  }
}

class TeacherChallengesPage extends StatefulWidget {
  const TeacherChallengesPage({super.key});

  @override
  State<TeacherChallengesPage> createState() => _TeacherChallengesPageState();
}

class _TeacherChallengesPageState extends State<TeacherChallengesPage> {
  List<ChallengeModel> _recentUploads = [];
  final int _maxRecentUploads = 5;
  Map<String, CourseModel> _courses = {};
  Map<String, List<ChallengeModel>> _challengesByCourse = {};
  bool _isLoading = true;
  String? _selectedCourseFilter;
  String? _expandedCourseId;
  final String _currentTeacherId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _searchQuery = '';
  List<ChallengeModel> _allChallenges = [];
  int _currentPage = 0;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final coursesQuery = FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: _currentTeacherId)
          .get();

      final collaboratedCoursesQuery = FirebaseFirestore.instance
          .collection('courses')
          .where('collaboratorIds', arrayContains: _currentTeacherId)
          .get();

      final results =
          await Future.wait([coursesQuery, collaboratedCoursesQuery]);
      final coursesSnapshot = results[0];
      final collaboratedCoursesSnapshot = results[1];

      final courses = <String, CourseModel>{};
      final allCourseDocs = [
        ...coursesSnapshot.docs,
        ...collaboratedCoursesSnapshot.docs
      ];
      final uniqueCourseIds = <String>{};

      for (var doc in allCourseDocs) {
        if (uniqueCourseIds.add(doc.id)) {
          final course = CourseModel.fromJson({
            'id': doc.id,
            ...doc.data(),
          });
          courses[doc.id] = course;
        }
      }

      if (!mounted) return;
      setState(() {
        _courses = courses;
      });

      // Load teacher's challenges
      context.read<ChallengeBloc>().add(LoadChallenges(isAdmin: false));
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, List<ChallengeModel>> _getOrganizedChallenges(
      List<ChallengeModel> challenges) {
    final organized = <String, List<ChallengeModel>>{};

    for (var challenge in challenges) {
      final courseId = challenge.courseId;
      if (courseId != null && courseId.isNotEmpty) {
        organized.putIfAbsent(courseId, () => []);
        organized[courseId]!.add(challenge);
      } else {
        organized.putIfAbsent('unassigned', () => []);
        organized['unassigned']!.add(challenge);
      }
    }

    // Sort challenges within each course by lesson
    for (var courseId in organized.keys) {
      organized[courseId]!.sort((a, b) => a.lesson.compareTo(b.lesson));
    }

    return organized;
  }

  void _addToRecentUploads(ChallengeModel challenge) {
    setState(() {
      _recentUploads.insert(0, challenge);
      if (_recentUploads.length > _maxRecentUploads) {
        _recentUploads.removeLast();
      }

      // Also update the organized challenges
      if (challenge.courseId != null && challenge.courseId!.isNotEmpty) {
        _challengesByCourse.putIfAbsent(challenge.courseId!, () => []);
        _challengesByCourse[challenge.courseId!]!.add(challenge);
        _challengesByCourse[challenge.courseId!]!
            .sort((a, b) => a.lesson.compareTo(b.lesson));
      } else {
        _challengesByCourse.putIfAbsent('unassigned', () => []);
        _challengesByCourse['unassigned']!.add(challenge);
        _challengesByCourse['unassigned']!
            .sort((a, b) => a.lesson.compareTo(b.lesson));
      }
    });
  }

  void _showChallengeForm(BuildContext context,
      {ChallengeModel? challenge, String? preSelectedCourseId}) async {
    final result = await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 500,
            child: BlocProvider.value(
              value: context.read<ChallengeBloc>(),
              child: ChallengeForm(
                challenge: challenge,
                isEditing: challenge != null,
                onChallengeCreated: (newChallenge) {
                  _addToRecentUploads(newChallenge);
                },
                preSelectedCourseId: preSelectedCourseId,
              ),
            ),
          ),
        ),
      ),
    );
    if (result == true) {
      context.read<ChallengeBloc>().add(const LoadChallenges(isAdmin: false));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(challenge == null
              ? 'Challenge created successfully!'
              : 'Challenge updated successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _deleteChallenge(String? id) async {
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Challenge ID is missing. Cannot delete.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Find the challenge to get its title for the confirmation dialog
    String challengeTitle = 'this challenge';
    try {
      final challenge = _allChallenges.firstWhere((c) => c.id == id);
      challengeTitle = challenge.title;
    } catch (e) {
      // Challenge not found in local list, use generic title
      challengeTitle = 'this challenge';
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Confirm Deletion'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$challengeTitle"? This action cannot be undone.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    // Only delete if user confirmed
    if (confirmed == true) {
      context.read<ChallengeBloc>().add(DeleteChallenge(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Challenge "$challengeTitle" deleted successfully.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildRecentUploads() {
    if (_recentUploads.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.new_releases,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Recently Added Challenges',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'NotoSans',
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recentUploads.length,
              itemBuilder: (context, index) {
                final challenge = _recentUploads[index];
                return Container(
                  width: 300,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.zero,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.code,
                                color: Colors.green,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                challenge.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  fontFamily: 'NotoSans',
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          challenge.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            fontFamily: 'NotoSans',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _ChallengeDetailChip(
                              icon: Icons.category,
                              label: challenge.difficulty
                                  .toString()
                                  .split('.')
                                  .last,
                              color: getDifficultyColor(
                                  context,
                                  challenge.difficulty
                                      .toString()
                                      .split('.')
                                      .last),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _ActionButton(
                              icon: Icons.edit,
                              label: 'Edit',
                              color: Colors.green,
                              onPressed: () => _showChallengeForm(context,
                                  challenge: challenge),
                            ),
                            const SizedBox(width: 8),
                            _ActionButton(
                              icon: Icons.delete,
                              label: 'Delete',
                              color: Colors.red,
                              onPressed: () => _deleteChallenge(challenge.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getCourseColor(BuildContext context, String courseId) {
    // Always return the course accent color
    return Colors.green;
  }

  Widget _buildCourseAccordion(
      String courseId, List<ChallengeModel> challenges) {
    final course = _courses[courseId];
    final courseName = course?.title ?? 'Unknown Course';
    final courseColor = _getCourseColor(context, courseId);
    final isExpanded = _expandedCourseId == courseId;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedCourseId = isExpanded ? null : courseId;
              });
            },
            borderRadius: BorderRadius.zero,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.zero,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.school,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          courseName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'NotoSans',
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${challenges.length} challenges',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontFamily: 'NotoSans',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.green,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            ...challenges
                .map((challenge) => _buildChallengeCard(context, challenge)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _ActionButton(
                  icon: Icons.add,
                  label: 'Add Challenge to $courseName',
                  color: Colors.green,
                  onPressed: () => _showChallengeForm(context,
                      preSelectedCourseId: courseId),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChallengeCard(BuildContext context, ChallengeModel challenge) {
    final course = _courses[challenge.courseId ?? ''];
    final courseName = course?.title ?? 'Unknown Course';
    final courseColor = _getCourseColor(context, challenge.courseId ?? '');

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.code,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'NotoSans',
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        challenge.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          fontFamily: 'NotoSans',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showChallengeForm(context, challenge: challenge);
                        break;
                      case 'delete':
                        _deleteChallenge(challenge.id);
                        break;
                      case 'toggle':
                        context.read<ChallengeBloc>().add(
                            ToggleChallengePublish(
                                challenge.id, !challenge.isPublished));
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit, size: 16),
                          const SizedBox(width: 8),
                          const Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            challenge.isPublished
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(challenge.isPublished ? 'Unpublish' : 'Publish'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.zero,
                    ),
                    child: const Icon(Icons.more_vert, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ChallengeDetailChip(
                  icon: Icons.category,
                  label: (challenge.difficultyLevel ??
                          (challenge.difficulty.index == 0
                              ? 1
                              : challenge.difficulty.index == 1
                                  ? 3
                                  : 5))
                      .toString(),
                  color: getDifficultyColor(
                      context, challenge.difficulty.toString().split('.').last),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(challenge.isPublished ? 'Published' : 'Draft'),
                  backgroundColor:
                      challenge.isPublished ? Colors.green : Colors.orange,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final challengeState = context.watch<ChallengeBloc>().state;
    if (challengeState is ChallengeLoaded) {
      // Get all course IDs where this teacher is the main teacher or a collaborator
      final teacherCourseIds = _courses.keys.toSet();

      // Show all challenges from courses this teacher teaches or collaborates on
      _allChallenges = challengeState.challenges
          .where((challenge) =>
              challenge.courseId != null &&
              teacherCourseIds.contains(challenge.courseId))
          .toList();
      _challengesByCourse = _getOrganizedChallenges(_allChallenges);
    }
    final filteredChallenges = _allChallenges.where((challenge) {
      final search = _searchQuery.trim().toLowerCase();
      if (search.isEmpty) return true;
      // Match lesson number if query is a number
      final lessonNum = int.tryParse(search);
      if (lessonNum != null && challenge.lesson == lessonNum) {
        return true;
      }
      // Match title, description, and course name
      final courseName =
          _courses[challenge.courseId]?.title.toLowerCase() ?? '';
      return challenge.title.toLowerCase().contains(search) ||
          challenge.description.toLowerCase().contains(search) ||
          courseName.contains(search);
    }).toList();
    // Pagination logic
    final int start = _currentPage * _pageSize;
    final int end = (start + _pageSize) > filteredChallenges.length
        ? filteredChallenges.length
        : (start + _pageSize);
    final List<ChallengeModel> paginated =
        filteredChallenges.sublist(start, end);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'NotoSans',
          ),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          Row(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  return Container(
                    width: isWide ? 180 : 120,
                    constraints: const BoxConstraints(maxWidth: 200),
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.10),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                          color: const Color(0xFF58B74A), width: 1.2),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: TextField(
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color.fromARGB(255, 0, 0, 0),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search challenges...',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                          prefixIcon: const Icon(Icons.search,
                              color: Colors.black, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear,
                                      color: Colors.green[300], size: 18),
                                  onPressed: () =>
                                      setState(() => _searchQuery = ''),
                                  tooltip: 'Clear search',
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF58B74A), width: 1.2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF58B74A), width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF58B74A), width: 2),
                          ),
                        ),
                        onChanged: (value) => setState(
                            () => _searchQuery = value.trim().toLowerCase()),
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16, right: 15, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showChallengeForm(context),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add Challenge'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    elevation: 2,
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRecentUploads(),
                  // Handle empty state for challenges
                  if (filteredChallenges.isEmpty)
                    SizedBox(
                      height: 600,
                      width: double.infinity,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No challenges found',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            child: DataTable(
                              headingRowColor:
                                  MaterialStateProperty.resolveWith<Color?>(
                                      (states) => Colors.green[50]),
                              dataRowColor:
                                  MaterialStateProperty.resolveWith<Color?>(
                                      (states) {
                                if (states.contains(MaterialState.selected)) {
                                  return Colors.green[100]!;
                                }
                                return Colors.white;
                              }),
                              headingTextStyle: const TextStyle(
                                color: Color.fromARGB(255, 0, 0, 0),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'NotoSans',
                              ),
                              columns: const [
                                DataColumn(label: Text('Title')),
                                DataColumn(label: Text('Description')),
                                DataColumn(label: Text('Course')),
                                DataColumn(label: Text('Modules')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: paginated.asMap().entries.map((entry) {
                                final index = entry.key;
                                final challenge = entry.value;
                                final course =
                                    _courses[challenge.courseId ?? ''];
                                final courseName =
                                    course?.title ?? 'Unknown Course';
                                final isPublished = challenge.isPublished;
                                return DataRow(
                                  color:
                                      MaterialStateProperty.resolveWith<Color?>(
                                          (states) {
                                    return Colors.white;
                                  }),
                                  cells: [
                                    DataCell(SizedBox(
                                      width: 220,
                                      child: Text(challenge.title),
                                    )),
                                    DataCell(SizedBox(
                                      width: 180,
                                      child: Text(
                                        challenge.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )),
                                    DataCell(SizedBox(
                                      width: 120,
                                      child: Text(courseName),
                                    )),
                                    DataCell(Text(challenge.lesson.toString())),
                                    DataCell(Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(),
                                          child: Text(
                                            isPublished
                                                ? 'Published'
                                                : 'Unpublished',
                                            style: TextStyle(
                                              color: isPublished
                                                  ? Colors.green[800]
                                                  : Colors.grey[700],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Transform.scale(
                                          scale: 0.75,
                                          child: Switch(
                                            value: isPublished,
                                            activeColor: Colors.green,
                                            inactiveThumbColor: Colors.grey,
                                            inactiveTrackColor:
                                                Colors.grey[300],
                                            onChanged: (val) {
                                              context.read<ChallengeBloc>().add(
                                                    ToggleChallengePublish(
                                                        challenge.id, val),
                                                  );
                                            },
                                          ),
                                        ),
                                      ],
                                    )),
                                    DataCell(Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.green),
                                          tooltip: 'Edit',
                                          onPressed: () => _showChallengeForm(
                                              context,
                                              challenge: challenge),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          tooltip: 'Delete',
                                          onPressed: () =>
                                              _deleteChallenge(challenge.id),
                                        ),
                                      ],
                                    )),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
                  // Pagination controls - only show if there are challenges
                  if (filteredChallenges.isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 16, right: 15, bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: _currentPage > 0
                                ? () {
                                    setState(() {
                                      _currentPage--;
                                    });
                                  }
                                : null,
                            child: const Text('Previous'),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Page ${_currentPage + 1} of ${((filteredChallenges.length / _pageSize).ceil()).clamp(1, 999)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: end < filteredChallenges.length
                                ? () {
                                    setState(() {
                                      _currentPage++;
                                    });
                                  }
                                : null,
                            child: const Text('Next'),
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

class _ChallengeDetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ChallengeDetailChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
              fontFamily: 'NotoSans',
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
