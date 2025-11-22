import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/challenges/domain/models/challenge_model.dart';
import 'package:codequest/features/challenges/presentation/widgets/challenge_form.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:codequest/features/courses/domain/models/course_model.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  List<ChallengeModel> _recentUploads = [];
  final int _maxRecentUploads = 5;
  Map<String, CourseModel> _courses = {};
  Map<String, List<ChallengeModel>> _challengesByCourse = {};
  bool _isLoading = true;
  String? _selectedCourseFilter;
  String? _expandedCourseId;
  int? _selectedLessonFilter;
  String _searchQuery = '';
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
      // Load courses
      final coursesSnapshot =
          await FirebaseFirestore.instance.collection('courses').get();

      final courses = <String, CourseModel>{};
      for (var doc in coursesSnapshot.docs) {
        final course = CourseModel.fromJson({
          'id': doc.id,
          ...doc.data(),
        });
        courses[doc.id] = course;
      }

      setState(() {
        _courses = courses;
      });

      // Load challenges
      context.read<ChallengeBloc>().add(const LoadChallenges(isAdmin: true));
    } catch (e) {
      print('Error loading data: ' + e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
      context.read<ChallengeBloc>().add(const LoadChallenges(isAdmin: true));
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
    context.read<ChallengeBloc>().add(DeleteChallenge(id));
  }

  Widget _buildRecentUploads() {
    if (_recentUploads.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
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
                    borderRadius: BorderRadius.circular(12),
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
                              icon: Icons.school,
                              label: challenge.lesson == 0
                                  ? 'Summative'
                                  : 'Module ${challenge.lesson}',
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            _ChallengeDetailChip(
                              icon: Icons.category,
                              label: challenge.difficulty
                                  .toString()
                                  .split('.')
                                  .last,
                              color: _getDifficultyColor(challenge.difficulty
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
                              color: Colors.blue,
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

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getCourseColor(String courseId) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
    ];

    if (courseId == 'unassigned') return Colors.grey;

    final index = courseId.hashCode % colors.length;
    return colors[index];
  }

  Widget _buildCourseAccordion(
      String courseId, List<ChallengeModel> challenges) {
    final course = _courses[courseId];
    final courseName = course?.title ?? 'Unknown Course';
    final courseColor = _getCourseColor(courseId);
    final isExpanded = _expandedCourseId == courseId;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: courseColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: courseColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.school,
                      color: courseColor,
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
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: courseColor,
                            fontFamily: 'NotoSans',
                          ),
                        ),
                        Text(
                          '${challenges.length} challenge${challenges.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: courseColor.withOpacity(0.8),
                            fontFamily: 'NotoSans',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: courseColor,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Challenge'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: courseColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _showChallengeForm(context,
                        preSelectedCourseId: courseId),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Column(
              children: [
                if (challenges.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.code_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No challenges in this course',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add challenges to this course to get started',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: challenges.length,
                    itemBuilder: (context, index) {
                      final challenge = challenges[index];
                      return Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        Text(
                                          challenge.lesson == 0
                                              ? 'Summative'
                                              : 'Module ${challenge.lesson}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontFamily: 'NotoSans',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        _showChallengeForm(context,
                                            challenge: challenge);
                                      } else if (value == 'delete') {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            title:
                                                const Text('Delete Challenge'),
                                            content: const Text(
                                                'Are you sure you want to delete this challenge? This action cannot be undone.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                    context, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          _deleteChallenge(challenge.id);
                                        }
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit,
                                                color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text('Edit Challenge'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete,
                                                color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete Challenge'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (challenge.description.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Text(
                                    challenge.description,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                      fontFamily: 'NotoSans',
                                      height: 1.4,
                                    ),
                                  ),
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
                                    color: _getDifficultyColor(challenge
                                        .difficulty
                                        .toString()
                                        .split('.')
                                        .last),
                                  ),
                                  const SizedBox(width: 8),
                                  _ChallengeDetailChip(
                                    icon: Icons.timer,
                                    label: '${challenge.timeLimit} min',
                                    color: Colors.blue,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _ActionButton(
                                    icon: Icons.play_arrow,
                                    label: 'Preview',
                                    color: Colors.green,
                                    onPressed: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Challenge preview coming soon!'),
                                          backgroundColor: Colors.blue,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _ActionButton(
                                    icon: Icons.analytics,
                                    label: 'Analytics',
                                    color: Colors.purple,
                                    onPressed: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Analytics coming soon!'),
                                          backgroundColor: Colors.purple,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }

  List<int> _getAllLessons(List<ChallengeModel> challenges) {
    final lessons = challenges.map((c) => c.lesson).toSet().toList();
    lessons.sort();
    return lessons;
  }

  Widget _buildLessonFilterBar(List<ChallengeModel> allChallenges) {
    final lessons = _getAllLessons(allChallenges);
    if (lessons.length <= 1) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Filter by Modules:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 16),
          Wrap(
            spacing: 8,
            children: [
              ...lessons.map((lesson) {
                final isSelected = _selectedLessonFilter == lesson;
                return ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedLessonFilter = isSelected ? null : lesson;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isSelected ? Colors.blue[600] : Colors.white,
                    foregroundColor:
                        isSelected ? Colors.white : Colors.blue[600],
                    side: BorderSide(
                      color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(lesson == 0 ? 'Summative' : 'Module $lesson'),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLessonFilteredChallenges(List<ChallengeModel> allChallenges) {
    final lesson = _selectedLessonFilter;
    if (lesson == null) return const SizedBox.shrink();
    final filtered = allChallenges.where((c) => c.lesson == lesson).toList();
    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.code_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              lesson == 0
                  ? 'No challenges for Summative'
                  : 'No challenges for Module $lesson',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    final byCourse = <String, List<ChallengeModel>>{};
    for (final c in filtered) {
      byCourse.putIfAbsent(c.courseId ?? 'unassigned', () => []).add(c);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...byCourse.entries.map((entry) {
          final course = _courses[entry.key];
          final courseName = course?.title ?? 'Unknown Course';
          final courseColor = _getCourseColor(entry.key);
          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: courseColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.school, color: courseColor, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        courseName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: courseColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: courseColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${entry.value.length} challenge${entry.value.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: courseColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entry.value.length,
                  itemBuilder: (context, idx) {
                    final challenge = entry.value[idx];
                    return Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
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
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      Text(
                                        challenge.lesson == 0
                                            ? 'Summative'
                                            : 'Module ${challenge.lesson}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontFamily: 'NotoSans',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      _showChallengeForm(context,
                                          challenge: challenge);
                                    } else if (value == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          title: const Text('Delete Challenge'),
                                          content: const Text(
                                              'Are you sure you want to delete this challenge? This action cannot be undone.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        _deleteChallenge(challenge.id);
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('Edit Challenge'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete Challenge'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (challenge.description.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Text(
                                  challenge.description,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                    fontFamily: 'NotoSans',
                                    height: 1.4,
                                  ),
                                ),
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
                                  color: _getDifficultyColor(challenge
                                      .difficulty
                                      .toString()
                                      .split('.')
                                      .last),
                                ),
                                const SizedBox(width: 8),
                                _ChallengeDetailChip(
                                  icon: Icons.timer,
                                  label: '${challenge.timeLimit} min',
                                  color: Colors.blue,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _ActionButton(
                                  icon: Icons.play_arrow,
                                  label: 'Preview',
                                  color: Colors.green,
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Challenge preview coming soon!'),
                                        backgroundColor: Colors.blue,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                _ActionButton(
                                  icon: Icons.analytics,
                                  label: 'Analytics',
                                  color: Colors.purple,
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Analytics coming soon!'),
                                        backgroundColor: Colors.purple,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xF3F8F1),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Container(
                  padding: const EdgeInsets.all(40),
                  child: const CircularProgressIndicator(
                    color: Colors.green,
                  ),
                ),
              )
            : BlocBuilder<ChallengeBloc, ChallengeState>(
                builder: (context, state) {
                  if (state is ChallengeLoading) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        child: const CircularProgressIndicator(
                          color: Colors.green,
                        ),
                      ),
                    );
                  } else if (state is ChallengeLoaded) {
                    final challenges = state.challenges;
                    if (challenges.isEmpty) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.code_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No challenges found',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'NotoSans',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create your first challenge to get started',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                  fontFamily: 'NotoSans',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Filter by search and course
                    List<ChallengeModel> filtered = challenges.where((c) {
                      final course = _courses[c.courseId];
                      final courseName = course?.title ?? '';
                      final courseCode = course?.courseCode ?? '';
                      final lessonStr = c.lesson.toString();
                      final difficultyStr =
                          c.difficulty.toString().split('.').last;
                      final search = _searchQuery.toLowerCase();
                      // Combine all relevant fields into a single string
                      final combined = [
                        c.title,
                        c.description,
                        c.teacherId,
                        c.teacherName,
                        c.instructions,
                        ...c.testCases,
                        c.type.name,
                        difficultyStr,
                        ...c.questions,
                        ...c.correctAnswers,
                        c.createdBy,
                        c.fileUrl ?? '',
                        c.fileName ?? '',
                        lessonStr,
                        c.passingScore.toString(),
                        c.deadline?.toString() ?? '',
                        c.grade?.toString() ?? '',
                        ...(c.options ?? []),
                        ...(c.blanks ?? []),
                        c.codeSnippet ?? '',
                        c.errorExplanation ?? '',
                        c.timeLimit?.toString() ?? '',
                        c.isPublished ? 'published' : 'unpublished',
                        c.courseId ?? '',
                        c.language ?? '',
                        courseName,
                        courseCode,
                      ].join(' ').toLowerCase();
                      final matchesSearch =
                          _searchQuery.isEmpty || combined.contains(search);
                      final matchesCourse = _selectedCourseFilter == null ||
                          c.courseId == _selectedCourseFilter;
                      return matchesSearch && matchesCourse;
                    }).toList();
                    // Pagination logic
                    final int start = _currentPage * _pageSize;
                    final int end = (start + _pageSize) > filtered.length
                        ? filtered.length
                        : (start + _pageSize);
                    final List<ChallengeModel> paginated =
                        filtered.sublist(start, end);

                    return Column(
                      children: [
                        // Green header bar
                        Container(
                          color: const Color(0xFF58B74A),
                          padding: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 26,
                                      fontFamily: 'NotoSans',
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 180,
                                constraints:
                                    const BoxConstraints(maxWidth: 200),
                                margin: const EdgeInsets.only(right: 12),
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
                                      color: const Color(0xFF58B74A),
                                      width: 1.2),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  child: TextField(
                                    onChanged: (v) =>
                                        setState(() => _searchQuery = v),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF217A3B),
                                        fontWeight: FontWeight.w500),
                                    decoration: InputDecoration(
                                      hintText: 'Search challenges...',
                                      hintStyle: TextStyle(
                                          fontSize: 13,
                                          color: const Color.fromARGB(
                                              255, 0, 0, 0)),
                                      prefixIcon: Icon(Icons.search,
                                          color: Color.fromRGBO(255, 0, 0, 0),
                                          size: 18),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Color.fromARGB(
                                                255, 214, 214, 214),
                                            width: 1.2),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Color.fromARGB(
                                                255, 216, 216, 216),
                                            width: 1.2),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Color.fromARGB(
                                                255, 213, 213, 213),
                                            width: 2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Add Challenge button (replaces IconButton)
                              ElevatedButton.icon(
                                onPressed: () => _showChallengeForm(context),
                                icon:
                                    const Icon(Icons.add, color: Colors.white),
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
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Table without description column
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  color: const Color(0xF3F8F1),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: DataTable(
                                      headingRowColor:
                                          MaterialStateProperty.all(
                                              const Color(0xFFEFF7ED)),
                                      columns: const [
                                        DataColumn(
                                            label: Text('Title',
                                                style: TextStyle(
                                                    color: Color.fromARGB(
                                                        255, 0, 0, 0),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16))),
                                        DataColumn(
                                            label: Text('Course',
                                                style: TextStyle(
                                                    color: Color.fromARGB(
                                                        255, 0, 0, 0),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16))),
                                        DataColumn(
                                            label: Text('Modules',
                                                style: TextStyle(
                                                    color: Color.fromARGB(
                                                        255, 0, 0, 0),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16))),
                                        DataColumn(
                                            label: Text('Status',
                                                style: TextStyle(
                                                    color: Color.fromARGB(
                                                        255, 0, 0, 0),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16))),
                                      ],
                                      rows: paginated.map((challenge) {
                                        final courseName =
                                            _courses[challenge.courseId]
                                                    ?.title ??
                                                'Unknown';
                                        // Removed description from the cells array
                                        final cells = [
                                          challenge.title,
                                          courseName,
                                          challenge.lesson == 0
                                              ? 'Summative'
                                              : 'Module ${challenge.lesson}',
                                          challenge.isPublished == true
                                              ? 'Published'
                                              : 'Unpublished',
                                        ];
                                        return DataRow(
                                          cells: List.generate(cells.length,
                                              (colIdx) {
                                            Widget child;
                                            if (colIdx == 3) { // Status is now at index 3
                                              final isPublished =
                                                  challenge.isPublished;
                                              String status;
                                              Color statusColor;
                                              if (isPublished == true) {
                                                status = 'Published';
                                                statusColor = Colors.green;
                                              } else if (isPublished == false) {
                                                status = 'Unpublished';
                                                statusColor = Colors.grey;
                                              } else {
                                                status = 'Unknown';
                                                statusColor = Colors.orange;
                                              }
                                              child = Row(
                                                children: [
                                                  Icon(
                                                    Icons.remove_red_eye,
                                                    color: statusColor,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    status,
                                                    style: TextStyle(
                                                      color: statusColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              );
                                              return DataCell(child);
                                            } else {
                                              child = Text(
                                                  cells[colIdx].toString());
                                              return DataCell(child);
                                            }
                                          }),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 16, right: 20, bottom: 16),
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
                                            : null, // Disabled if on first page
                                        child: const Text('Previous'),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        'Page ${_currentPage + 1} of ${((filtered.length / _pageSize).ceil()).clamp(1, 999)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 16),
                                      ElevatedButton(
                                        onPressed: end < filtered.length
                                            ? () {
                                                setState(() {
                                                  _currentPage++;
                                                });
                                              }
                                            : null, // Disabled if on last page
                                        child: const Text('Next'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  } else if (state is ChallengeError) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error: \u001b[1m${state.message.toString()}\u001b[0m',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'NotoSans',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const Center(child: Text('No challenges available.'));
                },
              ),
      ),
    );
  }

  Future<void> _addIsPublishedToAllChallenges() async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('challenges').get();
    for (var doc in snapshot.docs) {
      if (!doc.data().containsKey('isPublished')) {
        await doc.reference.update(
            {'isPublished': true}); // or false if you want default unpublished
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All challenges updated with isPublished.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'NotoSans',
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.8),
                    fontFamily: 'NotoSans',
                  ),
                ),
              ],
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
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontFamily: 'NotoSans',
              fontSize: 12,
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
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontFamily: 'NotoSans',
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
