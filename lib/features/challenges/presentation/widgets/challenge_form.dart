import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:codequest/features/challenges/domain/models/challenge_model.dart';
import 'package:codequest/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:codequest/features/challenges/presentation/widgets/google_forms_quiz_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class ChallengeForm extends StatefulWidget {
  final ChallengeModel? challenge;
  final bool isEditing;
  final Function(ChallengeModel)? onChallengeCreated;
  final String? preSelectedCourseId;

  const ChallengeForm({
    Key? key,
    this.challenge,
    this.isEditing = false,
    this.onChallengeCreated,
    this.preSelectedCourseId,
  }) : super(key: key);

  @override
  State<ChallengeForm> createState() => _ChallengeFormState();
}

class _ChallengeFormState extends State<ChallengeForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _codeSnippetController = TextEditingController();
  final _errorExplanationController = TextEditingController();
  final _correctAnswerController = TextEditingController();
  PlatformFile? _selectedFile;
  ChallengeType _type = ChallengeType.coding;
  ChallengeDifficulty _difficulty = ChallengeDifficulty.easy;
  int _difficultyLevel = 1;
  List<String> _blanks = ['']; // For fill in the blank
  double _passingScore = 70.0;
  int? _timeLimit; // in minutes
  List<String> _testCases = [];
  int _lesson = 1;
  String? _selectedCourseId;
  String? _selectedLanguage;
  List<Map<String, dynamic>> _courses = [];
  bool _isSubmitting = false;
  bool _isPublished = true;

  // For multiple questions quiz
  List<Map<String, dynamic>> _quizQuestions = [
    {
      'question': '',
      'options': ['Option A', 'Option B', 'Option C', 'Option D'],
      'correctAnswer': 0,
    }
  ];

  // For multiple fill-in-the-blank questions
  List<Map<String, dynamic>> _fillBlankQuestions = [
    {
      'question': '',
      'blanks': [''],
    }
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.challenge != null) {
      _titleController.text = widget.challenge!.title;
      _descriptionController.text = widget.challenge!.description;
      _type = widget.challenge!.type;
      _difficulty = widget.challenge!.difficulty;
      _difficultyLevel = widget.challenge!.difficultyLevel ??
          (_difficulty == ChallengeDifficulty.easy
              ? 1
              : _difficulty == ChallengeDifficulty.medium
                  ? 3
                  : 5);
      _passingScore = widget.challenge!.passingScore;
      _timeLimit = widget.challenge!.timeLimit;
      _lesson = widget.challenge!.lesson;
      _selectedCourseId = widget.challenge!.courseId;
      _selectedLanguage = widget.challenge!.language;
      _isPublished = widget.challenge!.isPublished;

      if (_type == ChallengeType.coding) {
        _codeSnippetController.text = widget.challenge!.codeSnippet ?? '';
        _errorExplanationController.text =
            widget.challenge!.errorExplanation ?? '';
        if (widget.challenge!.correctAnswers.isNotEmpty) {
          _correctAnswerController.text =
              widget.challenge!.correctAnswers.first;
        }
        _testCases = widget.challenge!.testCases;
      } else if (_type == ChallengeType.quiz ||
          _type == ChallengeType.summative) {
        if (widget.challenge!.quizQuestions != null) {
          _quizQuestions =
              List<Map<String, dynamic>>.from(widget.challenge!.quizQuestions!);
        }
      } else if (_type == ChallengeType.fillInTheBlank) {
        if (widget.challenge!.blanks != null) {
          _blanks = List<String>.from(widget.challenge!.blanks!);
        }

        // Initialize fill-in-the-blank questions from existing data
        if (widget.challenge!.questions.isNotEmpty &&
            widget.challenge!.blanks != null) {
          _fillBlankQuestions = [
            {
              'question': widget.challenge!.questions.first,
              'blanks': List<String>.from(widget.challenge!.blanks!),
            }
          ];
        }
      }
    } else {
      // For new challenges, ensure default values are set
      _type = ChallengeType.coding;
      _difficulty = ChallengeDifficulty.easy;
      _difficultyLevel = 1;
      _passingScore = 70.0;
      _testCases = [];
      _lesson = 1;
      _selectedCourseId = widget.preSelectedCourseId;
      _selectedLanguage = null;
      _isPublished = true;

      // Initialize quiz questions with at least one question for new challenges
      _quizQuestions = [
        {
          'question': '',
          'options': ['', '', '', ''],
          'correctAnswer': 0,
        }
      ];
    }
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final teacherId = currentUser.uid;

    // Check if user is admin
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(teacherId)
        .get();

    bool isAdmin = false;
    if (userDoc.exists) {
      final userData = userDoc.data();
      final role = userData?['role']?.toString().toLowerCase();
      isAdmin = role == 'admin';
    }

    List<QuerySnapshot> results;

    if (isAdmin) {
      // Admin can see all courses
      final allCoursesQuery =
          FirebaseFirestore.instance.collection('courses').get();
      results = [await allCoursesQuery];
    } else {
      // Teacher can only see their own courses and collaborated courses
      final coursesQuery = FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      final collaboratedCoursesQuery = FirebaseFirestore.instance
          .collection('courses')
          .where('collaboratorIds', arrayContains: teacherId)
          .get();

      results = await Future.wait([coursesQuery, collaboratedCoursesQuery]);
    }

    final allDocs = results.expand((snapshot) => snapshot.docs).toList();
    final uniqueCourses = <String, Map<String, dynamic>>{};

    for (var doc in allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      uniqueCourses[doc.id] = data;
    }

    if (!mounted) return;
    setState(() {
      _courses = uniqueCourses.values.toList();
      if (widget.preSelectedCourseId != null && _selectedLanguage == null) {
        final suggestedLanguage =
            _suggestLanguageFromCourse(widget.preSelectedCourseId);
        if (suggestedLanguage != null) {
          _selectedLanguage = suggestedLanguage;
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _codeSnippetController.dispose();
    _errorExplanationController.dispose();
    _correctAnswerController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String? _suggestLanguageFromCourse(String? courseId) {
    if (courseId == null) return null;
    final course = _courses.firstWhere(
      (course) => course['id'] == courseId,
      orElse: () => {},
    );
    final courseTitle = course['title']?.toString().toLowerCase() ?? '';
    if (courseTitle.contains('python')) return 'python3';
    if (courseTitle.contains('java')) return 'java';
    if (courseTitle.contains('c++') || courseTitle.contains('cpp'))
      return 'cpp';
    if (courseTitle.contains('javascript') || courseTitle.contains('js'))
      return 'js';
    if (courseTitle.contains('php')) return 'php';
    return null;
  }

  void _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      // For fill-in-the-blank, require at least one blank
      if (_type == ChallengeType.fillInTheBlank) {
        bool hasValidQuestions = false;
        for (var fillBlankQuestion in _fillBlankQuestions) {
          final question = fillBlankQuestion['question'] as String;
          final blanks = (fillBlankQuestion['blanks'] as List<dynamic>)
              .map((blank) => blank.toString())
              .toList();

          if (question.trim().isNotEmpty) {
            final validBlanks =
                blanks.where((blank) => blank.trim().isNotEmpty).toList();
            if (validBlanks.isNotEmpty) {
              hasValidQuestions = true;
              break;
            }
          }
        }

        if (!hasValidQuestions) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Please add at least one question with correct answers for this challenge.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      // Duplicate title check (only for create, not edit)
      if (!widget.isEditing) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final teacherId = currentUser.uid;
          final titleToCheck = _titleController.text.trim().toLowerCase();
          final duplicateQuery = await FirebaseFirestore.instance
              .collection('challenges')
              .where('teacherId', isEqualTo: teacherId)
              .where('title', isGreaterThanOrEqualTo: titleToCheck)
              .where('title', isLessThanOrEqualTo: titleToCheck + '\uf8ff')
              .get();
          final hasDuplicate = duplicateQuery.docs.any(
              (doc) => (doc['title'] as String).toLowerCase() == titleToCheck);
          if (hasDuplicate) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('A challenge with this title already exists.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
            setState(() => _isSubmitting = false);
            return;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isSubmitting = true;
      });

      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You must be logged in to create a challenge.'),
              backgroundColor: Colors.red,
            ),
          );
          if (!mounted) return;
          setState(() {
            _isSubmitting = false;
          });
          return;
        }
        final teacherId = currentUser.uid;
        final teacherName = currentUser.displayName ?? 'Unknown Teacher';

        // Prepare questions and correct answers for quiz type
        List<String> questions = [];
        List<String> correctAnswers = [];
        List<String> allOptions = [];

        if (_type == ChallengeType.quiz || _type == ChallengeType.summative) {
          // Validate that we have at least one question with content
          bool hasValidQuestions = false;

          for (var quizQuestion in _quizQuestions) {
            final question = quizQuestion['question'] as String;
            final correctAnswer = quizQuestion['correctAnswer'] as int;
            final options = (quizQuestion['options'] as List<dynamic>)
                .map((option) => option.toString())
                .toList();

            if (question.trim().isNotEmpty) {
              // Check if this question has exactly 4 valid options (as per new quiz file upload system)
              final validOptions =
                  options.where((option) => option.trim().isNotEmpty).toList();
              if (validOptions.length == 4) {
                questions.add(question);
                correctAnswers.add(correctAnswer.toString());
                allOptions.addAll(validOptions);
                hasValidQuestions = true;
              }
            }
          }

          if (!hasValidQuestions) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_type == ChallengeType.summative
                    ? 'Please add at least one question with exactly 4 options for the final evaluation.'
                    : 'Please add at least one question with exactly 4 options'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
        } else if (_type == ChallengeType.coding) {
          if (_testCases.isEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Please add at least one test case for coding challenges.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
            setState(() => _isSubmitting = false);
            return;
          }
          questions = [];
          correctAnswers = [_correctAnswerController.text];
        } else if (_type == ChallengeType.fillInTheBlank) {
          // Collect all questions and their corresponding blanks
          questions = [];
          correctAnswers = [];

          for (var fillBlankQuestion in _fillBlankQuestions) {
            final question = fillBlankQuestion['question'] as String;
            final blanks = (fillBlankQuestion['blanks'] as List<dynamic>)
                .map((blank) => blank.toString())
                .toList();

            if (question.trim().isNotEmpty) {
              // Check if this question has at least one valid blank
              final validBlanks =
                  blanks.where((blank) => blank.trim().isNotEmpty).toList();
              if (validBlanks.isNotEmpty) {
                questions.add(question);
                correctAnswers.addAll(validBlanks);
              }
            }
          }

          // Validate that we have at least one question with content
          if (questions.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please add at least one question with answers'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
        }

        final challenge = ChallengeModel(
          id: widget.isEditing ? widget.challenge!.id : const Uuid().v4(),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          instructions: '',
          type: _type,
          difficulty: _difficulty,
          difficultyLevel: _difficultyLevel,
          timeLimit: _timeLimit ?? 0,
          passingScore: _passingScore,
          createdAt:
              widget.isEditing ? widget.challenge!.createdAt : DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: teacherId,
          teacherId: teacherId,
          teacherName: teacherName,
          testCases: _type == ChallengeType.coding ? _testCases : [],
          questions: questions,
          correctAnswers: correctAnswers,
          options:
              (_type == ChallengeType.quiz || _type == ChallengeType.summative)
                  ? allOptions
                  : null,
          blanks: _type == ChallengeType.fillInTheBlank ? _blanks : null,
          codeSnippet: _codeSnippetController.text,
          errorExplanation: _errorExplanationController.text,
          lesson: _lesson,
          courseId: _selectedCourseId,
          language: _type == ChallengeType.coding ? _selectedLanguage : null,
          quizQuestions:
              (_type == ChallengeType.quiz || _type == ChallengeType.summative)
                  ? _quizQuestions
                  : null,
          fillBlankQuestions: _type == ChallengeType.fillInTheBlank
              ? _fillBlankQuestions
              : null,
          isPublished: _isPublished,
        );

        if (widget.isEditing) {
          context.read<ChallengeBloc>().add(UpdateChallenge(
                challenge: challenge,
                file: _selectedFile,
              ));
        } else {
          context.read<ChallengeBloc>().add(CreateChallenge(
                id: challenge.id,
                title: challenge.title,
                description: challenge.description,
                instructions: '',
                type: challenge.type,
                difficulty: challenge.difficulty,
                timeLimit: challenge.timeLimit,
                passingScore: challenge.passingScore,
                createdBy: challenge.createdBy,
                teacherId: challenge.teacherId,
                teacherName: challenge.teacherName,
                file: _selectedFile,
                testCases: challenge.testCases,
                questions: challenge.questions,
                correctAnswers: challenge.correctAnswers,
                options: challenge.options,
                lesson: challenge.lesson,
                courseId: challenge.courseId,
                language: challenge.language,
                quizQuestions: challenge.quizQuestions,
                blanks: challenge.blanks,
                fillBlankQuestions: challenge.fillBlankQuestions,
                codingProblems: challenge.codingProblems,
                isPublished: _isPublished,
              ));
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing
                ? 'Challenge updated successfully!'
                : 'Challenge created successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Icon(icon, color: Colors.green[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green[600]!, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red[400]!),
          ),
          filled: true,
          fillColor: enabled ? Colors.green[50] : Colors.grey[50],
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
    String? hintText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Icon(icon, color: Colors.green[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green[600]!, width: 2),
          ),
          filled: true,
          fillColor: Colors.green[50],
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: items,
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  Widget _buildFileUploadSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.upload_file, color: Colors.green[600], size: 24),
              const SizedBox(width: 12),
              const Text(
                'Challenge Materials',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Upload additional materials (PDF, DOC, DOCX)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedFile != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFile!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (_selectedFile!.size > 0)
                          Text(
                            '${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _selectedFile = null;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label:
                  Text(_selectedFile == null ? 'Select File' : 'Change File'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green[600],
                side: BorderSide(color: Colors.green[300]!),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicFields() {
    if (_type == ChallengeType.coding) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormField(
            controller: _correctAnswerController,
            label: 'Correct Answer',
            icon: Icons.check_circle,
            hintText: 'Enter the expected correct code solution',
            maxLines: 5,
            validator: (value) =>
                _type == ChallengeType.coding && (value?.isEmpty ?? true)
                    ? 'Please enter the correct answer for coding challenge'
                    : null,
          ),
          _buildFormField(
            controller: _codeSnippetController,
            label: 'Code Snippet (Optional)',
            icon: Icons.code,
            hintText: 'Provide a starting code snippet for students',
            maxLines: 5,
          ),
          _buildFormField(
            controller: _errorExplanationController,
            label: 'Error Explanation (Optional)',
            icon: Icons.error_outline,
            hintText: 'Explain common errors students might encounter',
            maxLines: 3,
          ),
          _buildFileUploadSection(),

          // Test Cases Information Box
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Test Case Evaluation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• With test cases: Code output is compared against expected results\n'
                  '• Without test cases: Code passes if it runs without errors, fails if errors occur',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: TextFormField(
              initialValue: _testCases.join('\n'),
              decoration: InputDecoration(
                labelText: 'Test Cases',
                hintText:
                    'Enter test cases (one per line) - Leave empty for automatic pass/fail based on code execution',
                prefixIcon: Icon(Icons.check_circle, color: Colors.green[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green[600]!, width: 2),
                ),
                filled: true,
                fillColor: Colors.green[50],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              maxLines: 5,
              onChanged: (value) {
                setState(() {
                  _testCases = value
                      .split('\n')
                      .where((line) => line.trim().isNotEmpty)
                      .toList();
                });
              },
            ),
          ),
          _buildDropdownField<String>(
            value: _selectedLanguage,
            label: 'Programming Language',
            icon: Icons.language,
            hintText: 'Select the required programming language',
            items: const [
              DropdownMenuItem(value: 'python3', child: Text('Python')),
              DropdownMenuItem(value: 'java', child: Text('Java')),
              DropdownMenuItem(value: 'cpp', child: Text('C++')),
              DropdownMenuItem(value: 'c', child: Text('C')),
              DropdownMenuItem(value: 'php', child: Text('PHP')),
              DropdownMenuItem(value: 'js', child: Text('JavaScript')),
            ],
            onChanged: (val) => setState(() => _selectedLanguage = val),
            validator: (val) => val == null || val.isEmpty
                ? 'Please select the required language'
                : null,
          ),
        ],
      );
    } else if (_type == ChallengeType.quiz ||
        _type == ChallengeType.summative) {
      // Multiple questions with multiple choice (for both quiz and summative)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _type == ChallengeType.summative
                  ? Colors.orange[50]
                  : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _type == ChallengeType.summative
                      ? Colors.orange[200]!
                      : Colors.orange[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                        _type == ChallengeType.summative
                            ? Icons.assignment_turned_in
                            : Icons.quiz,
                        color: _type == ChallengeType.summative
                            ? Colors.orange[600]
                            : Colors.orange[600],
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _type == ChallengeType.summative
                          ? 'Summative Evaluation Questions'
                          : 'Quiz Questions',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _type == ChallengeType.summative
                      ? 'Add multiple choice questions for this final evaluation. Students must pass this to receive their certificate.'
                      : 'Add multiple choice questions for this quiz challenge',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                // Tip removed: referenced the file upload option which is no longer shown
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Google Forms-style quiz creation widget
          GoogleFormsQuizWidget(
            onQuestionsLoaded: (questions) {
              setState(() {
                // Replace any existing questions and drop empty ones to ensure numbering starts at 1
                _quizQuestions = questions
                    .where((q) =>
                        (q['question']?.toString().trim().isNotEmpty ?? false))
                    .toList();
              });
            },
            currentQuestions: _quizQuestions,
          ),
        ],
      );
    } else if (_type == ChallengeType.fillInTheBlank) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(_fillBlankQuestions.length, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Question ${index + 1}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      if (_fillBlankQuestions.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _fillBlankQuestions.removeAt(index);
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _fillBlankQuestions[index]['question'],
                    decoration: const InputDecoration(
                      labelText: 'Question with Blanks',
                      hintText:
                          'Use ___ to indicate blanks (e.g., "The capital of France is ___")',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      _fillBlankQuestions[index]['question'] = value;
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a question';
                      }
                      if (!value.contains('___')) {
                        return 'Please use ___ to indicate blanks';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green[600], size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Correct Answers',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(
                            _fillBlankQuestions[index]['blanks'].length,
                            (blankIndex) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Text(
                                  'Blank ${blankIndex + 1}:',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _fillBlankQuestions[index]
                                        ['blanks'][blankIndex],
                                    decoration: const InputDecoration(
                                      labelText: 'Correct Answer',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      _fillBlankQuestions[index]['blanks']
                                          [blankIndex] = value;
                                    },
                                  ),
                                ),
                                if (_fillBlankQuestions[index]['blanks']
                                        .length >
                                    1)
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _fillBlankQuestions[index]['blanks']
                                            .removeAt(blankIndex);
                                      });
                                    },
                                  ),
                              ],
                            ),
                          );
                        }),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _fillBlankQuestions[index]['blanks'].add('');
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Answer'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green[600],
                              side: BorderSide(color: Colors.green[300]!),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _fillBlankQuestions.add({
                    'question': '',
                    'blanks': [''],
                  });
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Question'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green[600],
                side: BorderSide(color: Colors.green[300]!),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (_type == ChallengeType.summative) {
      // Summative evaluation - can be any of the above types
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment_turned_in,
                        color: Colors.orange[600], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Summative Evaluation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This is a final evaluation that students must pass to receive their certificate. '
                  'You can create any type of challenge (coding, quiz, or fill-in-the-blank) as a summative evaluation.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // For summative, we'll use the same fields as regular challenges
          // The type will be determined by the actual challenge content
          _buildFormField(
            controller: _correctAnswerController,
            label: 'Correct Answer',
            icon: Icons.check_circle,
            hintText: 'Enter the expected correct solution',
            maxLines: 5,
          ),
          _buildFormField(
            controller: _codeSnippetController,
            label: 'Code Snippet (Optional)',
            icon: Icons.code,
            hintText: 'Provide a starting code snippet for students',
            maxLines: 5,
          ),
          _buildFormField(
            controller: _errorExplanationController,
            label: 'Error Explanation (Optional)',
            icon: Icons.error_outline,
            hintText: 'Explain common errors students might encounter',
            maxLines: 3,
          ),
          _buildFileUploadSection(),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.extension,
                        color: Colors.green[600], size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.isEditing
                        ? 'Edit Challenge'
                        : 'Create New Challenge',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF217A3B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Course Selection
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: DropdownButtonFormField<String>(
                  value: _selectedCourseId,
                  decoration: InputDecoration(
                    labelText: 'Course',
                    hintText: 'Select the course for this challenge',
                    prefixIcon: Icon(Icons.school, color: Colors.green[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.green[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.green[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.green[600]!, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.green[50],
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  items: _courses.map((course) {
                    return DropdownMenuItem<String>(
                      value: course['id'],
                      child: Text(course['title'] ?? 'Untitled Course'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCourseId = val;
                      // Auto-suggest language based on course
                      if (_type == ChallengeType.coding) {
                        final suggestedLanguage =
                            _suggestLanguageFromCourse(val);
                        if (suggestedLanguage != null) {
                          _selectedLanguage = suggestedLanguage;
                        }
                      }
                    });
                  },
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please select a course';
                    }
                    return null;
                  },
                ),
              ),
              // Always show these fields (title, description, lessons) for all challenge types
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Challenge Title',
                    hintText: 'Enter challenge title',
                    prefixIcon: Icon(Icons.title, color: Colors.green[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.green[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.green[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.green[600]!, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.green[50],
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter a title' : null,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Challenge Description',
                    hintText: 'Describe what this challenge is about',
                    prefixIcon:
                        Icon(Icons.description, color: Colors.green[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.green[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.green[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.green[600]!, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.green[50],
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  maxLines: 3,
                  validator: (value) => value?.isEmpty ?? true
                      ? 'Please enter a description'
                      : null,
                ),
              ),

              // Challenge Configuration Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: DropdownButtonFormField<ChallengeType>(
                        value: _type,
                        decoration: InputDecoration(
                          labelText: 'Challenge Type',
                          prefixIcon:
                              Icon(Icons.category, color: Colors.green[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.green[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.green[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.green[600]!, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.green[50],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        items: ChallengeType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.name.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _type = value;
                              // Auto-set lesson to 0 for summative challenges
                              if (value == ChallengeType.summative) {
                                _lesson = 0;
                                // For summative, we'll use quiz questions by default
                                // but keep the type as summative for identification
                              } else if (_lesson == 0) {
                                // Reset to 1 if switching from summative to regular
                                _lesson = 1;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),

              // Module and Time Limit Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: TextFormField(
                        initialValue: _type == ChallengeType.summative
                            ? 'Final Evaluation'
                            : _lesson.toString(),
                        keyboardType: TextInputType.number,
                        enabled: _type != ChallengeType.summative,
                        decoration: InputDecoration(
                          labelText: _type == ChallengeType.summative
                              ? 'Evaluation Type'
                              : 'Module Number',
                          hintText: _type == ChallengeType.summative
                              ? 'Final Evaluation'
                              : 'e.g., 1, 2, 3...',
                          prefixIcon: Icon(
                              _type == ChallengeType.summative
                                  ? Icons.assignment_turned_in
                                  : Icons.school,
                              color: Colors.green[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.green[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.green[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.green[600]!, width: 2),
                          ),
                          filled: true,
                          fillColor: _type == ChallengeType.summative
                              ? Colors.orange[50]
                              : Colors.green[50],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        onChanged: (val) {
                          if (_type != ChallengeType.summative) {
                            setState(() {
                              _lesson = int.tryParse(val) ?? 1;
                            });
                          }
                        },
                        validator: (val) {
                          if (_type == ChallengeType.summative) {
                            return null; // No validation needed for summative
                          }
                          if (val == null || val.isEmpty) {
                            return 'Enter a module';
                          }
                          final n = int.tryParse(val);
                          if (n == null || n <= 0) {
                            return 'Enter a valid positive number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: TextFormField(
                        initialValue: _timeLimit?.toString() ?? '',
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Time Limit (minutes)',
                          hintText: 'e.g., 30, 60...',
                          prefixIcon:
                              Icon(Icons.timer, color: Colors.green[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.green[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.green[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.green[600]!, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.green[50],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _timeLimit = int.tryParse(val);
                          });
                        },
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Enter a time limit';
                          }
                          final n = int.tryParse(val);
                          if (n == null || n <= 0) {
                            return 'Enter a valid positive number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ],
              ),

              // Dynamic fields based on challenge type
              _buildDynamicFields(),

              // Passing Score
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Passing Score: ${_passingScore.toInt()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _passingScore,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      activeColor: Colors.green[600],
                      inactiveColor: Colors.grey[300],
                      onChanged: (value) {
                        setState(() {
                          _passingScore = value;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Published/Unpublished Toggle
              Row(
                children: [
                  Icon(
                    _isPublished ? Icons.visibility : Icons.visibility_off,
                    color: _isPublished ? Colors.green[700] : Colors.grey[600],
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isPublished ? 'Published' : 'Unpublished',
                    style: TextStyle(
                      color:
                          _isPublished ? Colors.green[700] : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _isPublished,
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.grey[400],
                      inactiveTrackColor: Colors.grey[300],
                      onChanged: (val) {
                        setState(() {
                          _isPublished = val;
                        });
                      },
                    ),
                  ),
                ],
              ),

              // Submit Button
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitForm,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(widget.isEditing ? Icons.save : Icons.add),
                  label: Text(
                    _isSubmitting
                        ? 'Processing...'
                        : (widget.isEditing
                            ? 'Update Challenge'
                            : 'Create Challenge'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
