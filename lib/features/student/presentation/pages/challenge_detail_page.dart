import 'package:flutter/material.dart';
import 'package:codequest/features/challenges/domain/models/challenge_model.dart';
import 'package:codequest/features/challenges/data/challenge_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/services/jdoodle_service.dart';
import 'package:codequest/services/file_picker_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/features/courses/domain/models/course_model.dart';
import 'package:codequest/features/auth/domain/models/user_model.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_state.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:codequest/config/routes.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:timeago/timeago.dart' as timeago;
import 'package:codequest/features/student/widgets/challenge_monitor.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:printing/printing.dart';
import 'dart:ui' as ui;

class ChallengeDetailPage extends StatefulWidget {
  final ChallengeModel challenge;
  final bool isCompleted;
  final VoidCallback? onChallengePassed;

  const ChallengeDetailPage({
    Key? key,
    required this.challenge,
    this.isCompleted = false,
    this.onChallengePassed,
  }) : super(key: key);

  @override
  State<ChallengeDetailPage> createState() => _ChallengeDetailPageState();
}

class _ChallengeDetailPageState extends State<ChallengeDetailPage> {
  final _solutionController = TextEditingController();
  final _errorExplanationController = TextEditingController();
  final _challengeRepository = ChallengeRepository(FirebaseFirestore.instance);
  final _storage = FirebaseStorage.instance;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  final FilePickerService _filePicker = FilePickerService();
  final JDoodleService _jdoodleService = JDoodleService();

  int? _selectedOption;
  List<String> _blankAnswers = [];
  Timer? _timer;
  int _secondsLeft = 0;
  bool _timeUp = false;
  bool _isSubmitting = false;
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String? _uploadError;
  bool _isProcessing = false;

  // For multiple quiz questions
  Map<String, int> _quizAnswers =
      {}; // questionId (or index as string) -> selectedOption

  String _selectedLanguage = 'python3'; // Default language for JDoodle
  String _selectedVersionIndex = '0'; // Default version index

  final Map<String, Map<String, String>> _jdoodleLanguages = {
    'Python': {'language': 'python3', 'versionIndex': '0'},
    'Java': {'language': 'java', 'versionIndex': '3'},
    'C': {'language': 'c', 'versionIndex': '5'},
    'C++': {'language': 'cpp', 'versionIndex': '5'},
    'PHP': {'language': 'php', 'versionIndex': '4'},
    // JDoodle also supports HTML, CSS, JavaScript for client-side execution, but the execute API is for server-side compilation.
    // If client-side rendering is needed, a different approach (e.g., WebView) would be necessary.
    // For now, these are the server-side languages relevant to coding challenges.
  };

  bool _isChallengeCompleted = false;
  bool _hasPassedChallenge = false;
  double _bestScore = 0.0;
  bool _isReviewMode = false;

  bool _isEditorDarkMode = false;

  final _formKey = GlobalKey<FormState>();
  final _answerController = TextEditingController();
  String? _submissionResult;
  bool _showResult = false;
  String? _errorMessage;
  bool _isLoading = true;
  ChallengeModel? _challenge;
  CourseModel? _course;
  UserModel? _currentUser;
  List<String> _userAnswers = [];
  List<String> _correctAnswers = [];
  int _currentQuestionIndex = 0;
  bool _isCompleted = false;
  String? _completionMessage;
  DateTime? _startTime;
  int _remainingTime = 0;

  @override
  void initState() {
    super.initState();
    // Initialize the editor theme based on system brightness
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _isEditorDarkMode = platformBrightness == Brightness.dark;

    // Load course information if available
    _loadCourseInfo();

    // Check if student has already attempted this quiz
    _checkPreviousAttempt();

    // Check if challenge is completed
    _checkChallengeCompletion();

    // Check if this is a completed challenge and prevent access
    _checkCompletedChallengeAccess();

    if ((widget.challenge.type == ChallengeType.quiz ||
            widget.challenge.type == ChallengeType.summative) &&
        widget.challenge.options != null) {
      _selectedOption = 0;
    }
    if (widget.challenge.type == ChallengeType.fillInTheBlank &&
        widget.challenge.blanks != null) {
      _blankAnswers = List.filled(widget.challenge.blanks!.length, '');
    }
    // Start timer if timeLimit is set
    if (widget.challenge.timeLimit != null && widget.challenge.timeLimit! > 0) {
      _secondsLeft = widget.challenge.timeLimit! * 60;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsLeft > 0) {
          if (!mounted) return;
          setState(() {
            _secondsLeft--;
          });
        } else {
          timer.cancel();
          if (!mounted) return;
          setState(() {
            _timeUp = true;
          });
          _autoSubmitOnTimeout();
        }
      });
    }
    // Set initial language based on challenge type if available or default to Python
    if (widget.challenge.type == ChallengeType.coding) {
      // Always use the teacher's selected language, no fallback to default
      if (widget.challenge.language != null &&
          widget.challenge.language!.isNotEmpty) {
        _selectedLanguage = widget.challenge.language!;
        print('Setting language from challenge: ${widget.challenge.language}');
      } else {
        // Only use default if teacher didn't specify a language
        _selectedLanguage = 'python3';
        print('No language specified by teacher, using default: python3');
      }

      // Set version index based on language
      if (_selectedLanguage.isNotEmpty) {
        final matchingLanguage = _jdoodleLanguages.values
            .where((map) => map['language'] == _selectedLanguage)
            .firstOrNull;

        if (matchingLanguage != null) {
          _selectedVersionIndex = matchingLanguage['versionIndex']!;
          print(
              'Set version index for $_selectedLanguage: $_selectedVersionIndex');
        } else {
          _selectedVersionIndex = '0'; // Default to Python version
          print(
              'Language $_selectedLanguage not found in JDoodle languages, using default version index: $_selectedVersionIndex');
        }
      }
    }

    // Initialize quiz answers based on challenge type
    if (widget.challenge.type == ChallengeType.quiz ||
        widget.challenge.type == ChallengeType.summative) {
      final totalQuestions = widget.challenge.quizQuestions?.length ??
          widget.challenge.questions.length;
      _quizAnswers = {}; // Initialize as empty map
      if (widget.challenge.quizQuestions != null) {
        for (var i = 0; i < widget.challenge.quizQuestions!.length; i++) {
          final quizQuestion = widget.challenge.quizQuestions![i];
          final questionId = quizQuestion['id']?.toString() ?? i.toString();
          _quizAnswers[questionId] = -1; // -1 means unanswered
        }
      } else {
        for (var i = 0; i < widget.challenge.questions.length; i++) {
          _quizAnswers[i.toString()] = -1;
        }
      }
    }

    // Initialize blank answers for project challenges
    if (widget.challenge.type == ChallengeType.fillInTheBlank) {
      if (widget.challenge.fillBlankQuestions != null &&
          widget.challenge.fillBlankQuestions!.isNotEmpty) {
        // Calculate total number of blanks across all questions
        int totalBlanks = 0;
        for (var question in widget.challenge.fillBlankQuestions!) {
          final blanks = question['blanks'] as List<dynamic>;
          totalBlanks += blanks.length;
        }
        _blankAnswers = List.filled(totalBlanks, '');
      } else {
        // Fallback to old structure
        _blankAnswers = List.filled(
          widget.challenge.blanks?.length ?? 0,
          '',
        );
      }
    }
  }

  @override
  void dispose() {
    _solutionController.dispose();
    _errorExplanationController.dispose();
    _timer?.cancel();
    _codeController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  String _getLanguageDisplayName(String languageCode) {
    // Convert language code to display name
    switch (languageCode) {
      case 'python3':
        return 'Python';
      case 'java':
        return 'Java';
      case 'c':
        return 'C';
      case 'cpp':
        return 'C++';
      case 'php':
        return 'PHP';
      default:
        return languageCode.toUpperCase();
    }
  }

  Future<void> _pickFile() async {
    try {
      setState(() {
        _isUploading = true;
        _uploadError = null;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'html',
          'css',
          'js',
          'py',
          'java',
          'cpp',
          'c',
          'txt'
        ],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        print('File selected:');
        print('Name: ${file.name}');
        print('Size: ${file.size}');
        print('Extension: ${file.extension}');
        print('Has bytes: ${file.bytes != null}');

        if (file.bytes == null) {
          throw Exception('Could not read file data');
        }

        setState(() {
          _selectedFile = file;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File selected: ${file.name}')),
        );
      }
    } catch (e) {
      print('Error picking file: $e');
      setState(() {
        _uploadError = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _autoSubmitOnTimeout() async {
    if (!_isSubmitting) {
      await _submitSolution(auto: true);
    }
  }

  Future<void> _submitSolution({bool auto = false}) async {
    if (_isSubmitting) return;

    // For quiz challenges, validate that all questions are answered
    if (widget.challenge.type == ChallengeType.quiz ||
        widget.challenge.type == ChallengeType.summative) {
      int totalQuestions = 0;
      if (widget.challenge.quizQuestions != null &&
          widget.challenge.quizQuestions!.isNotEmpty) {
        totalQuestions = widget.challenge.quizQuestions!.length;
      } else if (widget.challenge.questions.isNotEmpty) {
        totalQuestions = widget.challenge.questions.length;
      }

      if (_quizAnswers.length < totalQuestions) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Please answer all ${totalQuestions} questions before submitting.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      String? fileUrl;
      String solution = '';

      // Prepare solution based on challenge type
      if (widget.challenge.type == ChallengeType.quiz ||
          widget.challenge.type == ChallengeType.summative) {
        // Convert quiz answers to JSON string
        solution =
            _quizAnswers.entries.map((e) => 'Q${e.key}: ${e.value}').join(', ');
      } else if (widget.challenge.type == ChallengeType.coding) {
        solution = _codeController.text;
        if (_selectedFile != null) {
          try {
            // Create a reference to the file location in Firebase Storage
            final storageRef = _storage.ref();
            final fileRef = storageRef.child(
                'submissions/${widget.challenge.id}/${_selectedFile!.name}');

            // Upload the file
            final uploadTask = fileRef.putData(
              _selectedFile!.bytes!,
              SettableMetadata(
                contentType: 'text/plain',
                customMetadata: {
                  'challengeId': widget.challenge.id,
                  'fileName': _selectedFile!.name,
                },
              ),
            );

            // Wait for the upload to complete
            final snapshot = await uploadTask;
            print(
                'File upload completed. Bytes transferred: ${snapshot.bytesTransferred}');

            // Get the download URL
            fileUrl = await fileRef.getDownloadURL();
            print('File URL: $fileUrl');
          } catch (e) {
            print('Error uploading file: $e');
            throw Exception('Failed to upload file: $e');
          }
        }
      } else {
        solution = _solutionController.text;
      }

      // Submit the solution
      await _challengeRepository.submitChallenge(
        widget.challenge.id,
        solution,
        fileUrl: fileUrl,
        language: _selectedLanguage,
        onChallengeCompleted: () async {
          // Check lesson completion after challenge is submitted
          if (widget.challenge.courseId != null) {
            // Import the student challenges page to call the static method
            // This will be handled by the progress listener in the student challenges page
            print(
                'Challenge completed, lesson completion check will be triggered');
          }
        },
      );

      // Get the submission result to determine if it passed
      final submissionDetails = await _challengeRepository.getSubmissionDetails(
        _getCurrentStudentId(),
        widget.challenge.id,
      );

      if (submissionDetails != null) {
        final passed = submissionDetails['status'] == 'passed';
        final score = (submissionDetails['score'] as num?)?.toDouble() ?? 0.0;

        // Save attempt to completed_challenges collection for consistency
        await _markCodingChallengeAsCompleted(passed, score);

        // Refresh completion status
        await _checkChallengeCompletion();
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(auto ? 'Time is up!' : 'Solution Submitted'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                auto ? Icons.timer_off : Icons.check_circle,
                color: auto ? Colors.orange : Colors.green,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                auto
                    ? 'Time is up! Your solution was auto-submitted.'
                    : 'Your solution has been submitted successfully!',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting solution: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Widget _buildCodingChallenge(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.challenge.instructions,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color:
                          _isEditorDarkMode ? Colors.white70 : Colors.black87,
                    ),
              ),
              const SizedBox(height: 16),

              // Show the selected language as a read-only display instead of dropdown
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Icon(Icons.code, color: Colors.green[700]),
                    Text(
                      'Programming Language: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _getLanguageDisplayName(_selectedLanguage),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Fixed by Teacher',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: _isEditorDarkMode
                          ? 'Switch to light editor'
                          : 'Switch to dark editor',
                      child: IconButton(
                        icon: Icon(
                          _isEditorDarkMode
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          color: Colors.black87,
                        ),
                        onPressed: () {
                          setState(() {
                            _isEditorDarkMode = !_isEditorDarkMode;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                maxLines: 20,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                  color: _isEditorDarkMode ? Colors.white70 : Colors.black,
                  fontFamily: 'monospace',
                ),
                cursorColor: _isEditorDarkMode ? Colors.white70 : Colors.blue,
                decoration: InputDecoration(
                  labelText: 'Write your code here',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor:
                      _isEditorDarkMode ? Colors.grey[900] : Colors.grey[50],
                  labelStyle: TextStyle(
                    color: _isEditorDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isProcessing ? null : _runCode,
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Run Code'),
              ),
              const SizedBox(height: 16),
              Text(
                'Output:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color:
                          _isEditorDarkMode ? Colors.white70 : Colors.black87,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _outputController,
                maxLines: 10,
                readOnly: true,
                style: TextStyle(
                  color: _isEditorDarkMode ? Colors.white70 : Colors.black87,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor:
                      _isEditorDarkMode ? Colors.black : Colors.grey[100],
                ),
              ),
              const SizedBox(height: 16),
              // Existing file upload section
              if (widget.challenge.fileUrl != null &&
                  widget.challenge.fileUrl!.isNotEmpty) ...[
                ElevatedButton(
                  onPressed: _isProcessing ? null : _pickFile,
                  child: const Text('Upload Solution File'),
                ),
                if (_selectedFile != null) ...[
                  const SizedBox(height: 8),
                  Text('Selected file: ${_selectedFile!.name}'),
                ],
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (_isProcessing || _hasPassedChallenge)
                    ? null
                    : _submitSolution,
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : _hasPassedChallenge
                        ? const Text('Challenge Passed')
                        : const Text('Submit Challenge'),
              ),
              const SizedBox(height: 16),
              // Test button for debugging error detection
              // if (widget.challenge.type == ChallengeType.coding) ...[
              //   ElevatedButton(
              //     onPressed: _isProcessing ? null : () => _testErrorDetection(),
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor: Colors.orange,
              //       foregroundColor: Colors.white,
              //     ),
              //     child: const Text('Test Error Detection (Debug)'),
              //   ),
              //   const SizedBox(height: 8),
              //   Text(
              //     'Debug: Test error detection with sample code',
              //     style: TextStyle(
              //       fontSize: 12,
              //       color: Colors.grey[600],
              //       fontStyle: FontStyle.italic,
              //     ),
              //   ),
              // ],
              // Debug button for testing error detection
              // ElevatedButton(
              //   onPressed: () async {
              //     print('=== DEBUG: Testing error detection ===');
              //     try {
              //       await _challengeRepository.submitChallenge(
              //         widget.challenge.id,
              //         'print("Hello World")\nprint(undefined_variable)', // This will cause an error
              //         language: 'python3',
              //       );
              //       print('Debug test completed');
              //     } catch (e) {
              //       print('Debug test error: $e');
              //     }
              //   },
              //   child: Text('Debug: Test Error Detection'),
              // ),
              // SizedBox(height: 16),
              // Debug button for comprehensive error detection test
              // ElevatedButton(
              //   onPressed: () async {
              //     print(
              //         '=== DEBUG: Running comprehensive error detection test ===');
              //     try {
              //       await _challengeRepository.testErrorDetection();
              //       print('Comprehensive test completed');
              //     } catch (e) {
              //       print('Comprehensive test error: $e');
              //     }
              //   },
              //   child: Text('Debug: Comprehensive Error Test'),
              // ),
              // SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChallengeMonitor(
      challengeId: widget.challenge.id,
      challengeTitle: widget.challenge.title,
      courseId: widget.challenge.courseId,
      courseTitle: _course?.title,
      challengeType: widget.challenge.type.toString().split('.').last,
      challengeDifficulty:
          widget.challenge.difficulty.toString().split('.').last,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.challenge.title),
          backgroundColor:
              widget.challenge.isSummative ? Colors.orange[600] : null,
          foregroundColor: widget.challenge.isSummative ? Colors.white : null,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: widget.isCompleted
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You have completed this challenge!',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text('Congratulations on passing this challenge.'),
                    // Add more summary or review info here if needed
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Challenge header with completion status
                    _buildChallengeHeader(),
                    const SizedBox(height: 16),
                    // Show JDoodle code editor only for coding challenges
                    if (widget.challenge.type == ChallengeType.coding)
                      _buildCodingChallenge(context),
                    // Then show the specific challenge type widget
                    if (widget.challenge.type == ChallengeType.coding)
                      const SizedBox.shrink()
                    else if (widget.challenge.type == ChallengeType.quiz ||
                        widget.challenge.type == ChallengeType.summative)
                      _buildQuizChallenge()
                    else if (widget.challenge.type ==
                        ChallengeType.fillInTheBlank)
                      _buildFillInTheBlankChallenge(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildQuizChallenge() {
    // Use structured quiz data if available, otherwise fall back to old format
    final quizDisabled = _hasPassedChallenge;
    if (widget.challenge.quizQuestions != null &&
        widget.challenge.quizQuestions!.isNotEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quiz Questions',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              ...widget.challenge.quizQuestions!
                  .asMap()
                  .entries
                  .map((questionEntry) {
                final questionIndex = questionEntry.key;
                final quizQuestion = questionEntry.value;
                final question = quizQuestion['question'] as String;
                final options = (quizQuestion['options'] as List<dynamic>)
                    .map((option) => option.toString())
                    .toList();
                final questionId =
                    quizQuestion['id']?.toString() ?? questionIndex.toString();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question ${questionIndex + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        question,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                        textAlign: TextAlign.left,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(options.length, (optionIndex) {
                      return RadioListTile<int>(
                        value: optionIndex,
                        groupValue: _quizAnswers[questionId] ?? -1,
                        onChanged: quizDisabled
                            ? null
                            : (value) {
                                setState(() {
                                  _quizAnswers[questionId] = value!;
                                });
                              },
                        title: Text(options[optionIndex]),
                      );
                    }),
                    const Divider(height: 32),
                  ],
                );
              }).toList(),
              const SizedBox(height: 16),
              // Show progress
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Answered ${_getAnsweredQuestionsCount()} of ${widget.challenge.quizQuestions!.length} questions',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _viewQuizHistory,
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('History'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Submit button for quiz
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      quizDisabled || _isSubmitting ? null : _submitQuizAnswers,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : quizDisabled
                          ? const Text('Quiz Passed')
                          : const Text('Submit Quiz Answers'),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (widget.challenge.questions.isNotEmpty) {
      // Fallback to old format - reconstruct options per question
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quiz Questions',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  widget.challenge.questions.isNotEmpty
                      ? widget.challenge.questions.first
                      : (widget.challenge.instructions.isNotEmpty
                          ? widget.challenge.instructions
                          : widget.challenge.description),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                  textAlign: TextAlign.left,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
              const SizedBox(height: 16),
              // Show progress
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Answered ${_getAnsweredQuestionsCount()} of ${widget.challenge.questions.length} questions',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _viewQuizHistory,
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('History'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Submit button for quiz
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || _isReviewMode)
                      ? null
                      : _submitQuizAnswers,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : _isReviewMode
                          ? const Text('Challenge Completed - Review Mode')
                          : const Text('Submit Quiz Answers'),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // No questions available
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No Questions Available',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  'This quiz challenge does not have any questions configured. Please contact your teacher.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.red[700],
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildSummativeChallenge() {
    // Use structured quiz data if available, otherwise fall back to old format
    final summativeDisabled = _hasPassedChallenge;
    if (widget.challenge.quizQuestions != null &&
        widget.challenge.quizQuestions!.isNotEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summative header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in,
                      color: Colors.orange[600],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Final Evaluation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Complete this evaluation to receive your certificate',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Evaluation Questions',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ...widget.challenge.quizQuestions!
                  .asMap()
                  .entries
                  .map((questionEntry) {
                final questionIndex = questionEntry.key;
                final quizQuestion = questionEntry.value;
                final question = quizQuestion['question'] as String;
                final options = (quizQuestion['options'] as List<dynamic>)
                    .map((option) => option.toString())
                    .toList();
                final questionId =
                    quizQuestion['id']?.toString() ?? questionIndex.toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${questionIndex + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.orange[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Text(
                          question,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                          textAlign: TextAlign.left,
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(options.length, (optionIndex) {
                        return RadioListTile<int>(
                          value: optionIndex,
                          groupValue: _quizAnswers[questionId] ?? -1,
                          onChanged: summativeDisabled
                              ? null
                              : (value) {
                                  setState(() {
                                    _quizAnswers[questionId] = value!;
                                  });
                                },
                          title: Text(options[optionIndex]),
                          activeColor: Colors.orange[600],
                        );
                      }),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 16),
              // Show progress
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Answered ${_getAnsweredQuestionsCount()} of ${widget.challenge.quizQuestions!.length} questions',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _viewQuizHistory,
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('History'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Submit button for summative
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (summativeDisabled || _isSubmitting || _isReviewMode)
                          ? null
                          : _submitQuizAnswers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : (summativeDisabled || _isReviewMode)
                          ? const Text('Evaluation Completed - Review Mode')
                          : const Text('Submit Final Evaluation'),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (widget.challenge.questions.isNotEmpty) {
      // Fallback to old format for summative
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summative header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in,
                      color: Colors.orange[600],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Final Evaluation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Complete this evaluation to receive your certificate',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Evaluation Questions',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Text(
                  widget.challenge.questions.isNotEmpty
                      ? widget.challenge.questions.first
                      : (widget.challenge.instructions.isNotEmpty
                          ? widget.challenge.instructions
                          : widget.challenge.description),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                  textAlign: TextAlign.left,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
              const SizedBox(height: 16),
              // Show progress
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Answered ${_getAnsweredQuestionsCount()} of ${widget.challenge.questions.length} questions',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _viewQuizHistory,
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('History'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Submit button for summative
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || _isReviewMode)
                      ? null
                      : _submitQuizAnswers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : _isReviewMode
                          ? const Text('Evaluation Completed - Review Mode')
                          : const Text('Submit Final Evaluation'),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // No questions available for summative
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summative header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in,
                      color: Colors.orange[600],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Final Evaluation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Complete this evaluation to receive your certificate',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  'This final evaluation does not have any questions configured. Please contact your teacher to set up the evaluation properly.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.red[700],
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildFillInTheBlankChallenge() {
    final hasNewStructure = widget.challenge.fillBlankQuestions != null &&
        widget.challenge.fillBlankQuestions!.isNotEmpty;
    final hasOldStructure =
        widget.challenge.blanks != null && widget.challenge.blanks!.isNotEmpty;

    if (!hasNewStructure && !hasOldStructure) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'This challenge is misconfigured: no answer fields are set. Please contact your teacher.',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      );
    }

    if (hasNewStructure) {
      // New structure with multiple questions
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...widget.challenge.fillBlankQuestions!.asMap().entries.map((entry) {
            final questionIndex = entry.key;
            final question = entry.value;
            final questionText = question['question'] as String;
            final blanks = question['blanks'] as List<dynamic>;

            // Calculate the starting index for this question's blanks
            int startIndex = 0;
            for (int i = 0; i < questionIndex; i++) {
              final prevQuestion = widget.challenge.fillBlankQuestions![i];
              final prevBlanks = prevQuestion['blanks'] as List<dynamic>;
              startIndex += prevBlanks.length;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question ${questionIndex + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      questionText,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                      textAlign: TextAlign.left,
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.orange[600], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Fill in the blanks below:',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...blanks.asMap().entries.map((blankEntry) {
                    final blankIndex = blankEntry.key;
                    final globalIndex = startIndex + blankIndex;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Blank ${blankIndex + 1}',
                          hintText: 'Enter your answer here...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: Colors.blue[600]!, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _blankAnswers[globalIndex] = val;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // Validate all blanks are filled
                final allFilled =
                    _blankAnswers.every((ans) => ans.trim().isNotEmpty);
                if (!allFilled) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Please fill in all blanks before submitting.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Grade the answers
                final correctAnswers = widget.challenge.correctAnswers;
                int correctCount = 0;
                for (int i = 0; i < _blankAnswers.length; i++) {
                  if (i < correctAnswers.length &&
                      _blankAnswers[i].trim().toLowerCase() ==
                          correctAnswers[i].trim().toLowerCase()) {
                    correctCount++;
                  }
                }
                final score = (_blankAnswers.isNotEmpty)
                    ? (correctCount / _blankAnswers.length) * 100
                    : 0.0;
                final passed = score >= widget.challenge.passingScore;

                // Save submission
                await _saveFillInTheBlankSubmission(passed, score);
              },
              child: const Text('Submit'),
            ),
          ),
        ],
      );
    } else {
      // Old structure with single question
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Text(
              widget.challenge.questions.isNotEmpty
                  ? widget.challenge.questions.first
                  : (widget.challenge.instructions.isNotEmpty
                      ? widget.challenge.instructions
                      : widget.challenge.description),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
              textAlign: TextAlign.left,
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
          const SizedBox(height: 8),
          ..._blankAnswers.asMap().entries.map((entry) {
            int idx = entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Blank ${idx + 1}',
                  hintText: 'Enter your answer here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) {
                  setState(() {
                    _blankAnswers[idx] = val;
                  });
                },
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // Validate all blanks are filled
                final allFilled =
                    _blankAnswers.every((ans) => ans.trim().isNotEmpty);
                if (!allFilled) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Please fill in all blanks before submitting.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Grade the answers
                final correctAnswers = widget.challenge.correctAnswers;
                int correctCount = 0;
                for (int i = 0; i < _blankAnswers.length; i++) {
                  if (i < correctAnswers.length &&
                      _blankAnswers[i].trim().toLowerCase() ==
                          correctAnswers[i].trim().toLowerCase()) {
                    correctCount++;
                  }
                }
                final score = (_blankAnswers.isNotEmpty)
                    ? (correctCount / _blankAnswers.length) * 100
                    : 0.0;
                final passed = score >= widget.challenge.passingScore;

                // Save submission
                await _saveFillInTheBlankSubmission(passed, score);
              },
              child: const Text('Submit'),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildErrorChallenge() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.challenge.codeSnippet ?? ''),
        const SizedBox(height: 8),
        TextFormField(
          controller: _errorExplanationController,
          decoration: const InputDecoration(labelText: 'Your Explanation'),
          maxLines: 4,
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _runCode() async {
    setState(() {
      _isProcessing = true;
      _outputController.text = 'Running code...';
    });

    try {
      final String script = _codeController.text;
      final Map<String, dynamic> result = await _jdoodleService.executeCode(
        script: script,
        language: _selectedLanguage,
        versionIndex: _selectedVersionIndex,
      );

      if (result.containsKey('output')) {
        _outputController.text = result['output'];
      } else if (result.containsKey('error')) {
        _outputController.text =
            'Error:  [31m${result['error']}\nDetails: ${result['details']}';
      } else {
        _outputController.text = 'Unknown response from JDoodle.';
      }
    } catch (e) {
      _outputController.text = 'An error occurred: $e';
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _submitQuizAnswers() async {
    // Determine total questions count
    final totalQuestions = widget.challenge.quizQuestions?.length ??
        widget.challenge.questions.length;

    // Validate that all questions are answered
    for (final entry in _quizAnswers.entries) {
      if (entry.value == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please answer all questions before submitting'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Calculate score
      int correctAnswers = 0;

      if (widget.challenge.quizQuestions != null) {
        for (var i = 0; i < widget.challenge.quizQuestions!.length; i++) {
          final quizQuestion = widget.challenge.quizQuestions![i];
          final questionId = quizQuestion['id']?.toString() ?? i.toString();
          final studentAnswer = _quizAnswers[questionId];
          final correctAnswer = quizQuestion['correctAnswer'].toString();
          if (studentAnswer.toString() == correctAnswer) {
            correctAnswers++;
          }
        }
      } else {
        for (var i = 0; i < widget.challenge.questions.length; i++) {
          final studentAnswer = _quizAnswers[i.toString()];
          final correctAnswer = widget.challenge.correctAnswers[i];
          if (studentAnswer.toString() == correctAnswer) {
            correctAnswers++;
          }
        }
      }

      final score = (correctAnswers / totalQuestions) * 100;

      // Save quiz results to Firebase
      await _saveQuizResults(score, correctAnswers, totalQuestions);

      // Refresh completion status and update UI
      await _checkChallengeCompletion();
      setState(() {});

      // Show results
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        builder: (context) => AlertDialog(
          title: const Text('Quiz Results'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Score: ${score.toStringAsFixed(1)}%'),
              Text('Correct Answers: $correctAnswers / $totalQuestions'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: score >= widget.challenge.passingScore
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  score >= widget.challenge.passingScore
                      ? '🎉 Congratulations! You passed the quiz!'
                      : '❌ Sorry, you did not pass the quiz. Please try again.',
                  style: TextStyle(
                    color: score >= widget.challenge.passingScore
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Passing Score: ${widget.challenge.passingScore}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (score >= widget.challenge.passingScore) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.blue.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Challenge completed! Retakes are not allowed.',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            // No retake button if passed
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to challenges list
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error in quiz submission: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting quiz: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  int _getAnsweredQuestionsCount() {
    return _quizAnswers.length;
  }

  Future<void> _saveQuizResults(
      double score, int correctAnswers, int totalQuestions) async {
    try {
      print('=== STARTING FIREBASE SAVE ===');

      // Create a unique document ID for this quiz attempt
      final quizAttemptId =
          '${widget.challenge.id}_${DateTime.now().millisecondsSinceEpoch}';

      final quizResult = {
        'quizAttemptId': quizAttemptId,
        'challengeId': widget.challenge.id,
        'challengeTitle': widget.challenge.title,
        'challengeType': widget.challenge.type.toString(),
        'studentId': _getCurrentStudentId(),
        'studentName': _getCurrentStudentName(),
        'score': score,
        'correctAnswers': correctAnswers,
        'totalQuestions': totalQuestions,
        'passed': score >= widget.challenge.passingScore,
        'passingScore': widget.challenge.passingScore,
        'submittedAt': FieldValue.serverTimestamp(),
        'submittedAtString': DateTime.now().toIso8601String(),
        'answers': _quizAnswers
            .map((key, value) => MapEntry(key.toString(), value.toString())),
        'timeSpent': widget.challenge.timeLimit != null
            ? (widget.challenge.timeLimit! * 60 - _secondsLeft)
            : null,
        'challengeDetails': {
          'difficulty': widget.challenge.difficulty.toString(),
          'lesson': widget.challenge.lesson,
          'courseId': widget.challenge.courseId ?? '',
        }
      };

      print('Quiz result data prepared: $quizResult');

      // Save to quiz_results collection
      print('Saving to quiz_results collection...');
      await FirebaseFirestore.instance
          .collection('quiz_results')
          .doc(quizAttemptId)
          .set(quizResult);
      print('✅ Saved to quiz_results collection');

      // Also save to student's personal quiz history
      print('Saving to student quiz history...');
      await FirebaseFirestore.instance
          .collection('students')
          .doc(_getCurrentStudentId())
          .collection('quiz_history')
          .doc(quizAttemptId)
          .set(quizResult);
      print('✅ Saved to student quiz history');

      // Update challenge statistics
      print('Updating challenge statistics...');
      await _updateChallengeStatistics(score, correctAnswers, totalQuestions);
      print('✅ Challenge statistics updated');

      // Mark challenge as completed for this student
      print('Marking challenge as completed...');
      await _markChallengeAsCompleted(
          score >= widget.challenge.passingScore, score);
      print('✅ Challenge marked as completed');

      print('=== FIREBASE SAVE COMPLETED SUCCESSFULLY ===');
      print('Quiz attempt ID: $quizAttemptId');
      print('Score: $score%, Correct: $correctAnswers/$totalQuestions');
      print('Student ID: ${_getCurrentStudentId()}');
      print('Challenge ID: ${widget.challenge.id}');
      print('Answers: $_quizAnswers');
    } catch (e) {
      print('❌ ERROR SAVING QUIZ RESULTS: $e');
      print('Error details: ${e.toString()}');
      // Show error to user but don't block the quiz completion
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Quiz completed! Results may not be saved due to connection issue: $e'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _updateChallengeStatistics(
      double score, int correctAnswers, int totalQuestions) async {
    try {
      final challengeRef = FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challenge.id);

      // Get current statistics
      final challengeDoc = await challengeRef.get();
      final currentData = challengeDoc.data() ?? {};

      // Update statistics with proper type handling
      final currentAttempts = (currentData['totalAttempts'] ?? 0) + 1;
      final currentPasses = (currentData['totalPasses'] ?? 0) +
          (score >= widget.challenge.passingScore ? 1 : 0);
      final currentTotalScore = (currentData['totalScore'] ?? 0.0) + score;
      final averageScore = currentTotalScore / currentAttempts;

      await challengeRef.update({
        'totalAttempts': currentAttempts,
        'totalPasses': currentPasses,
        'totalScore': currentTotalScore,
        'averageScore': averageScore,
        'lastAttemptedAt': FieldValue.serverTimestamp(),
        'lastAttemptedAtString': DateTime.now().toIso8601String(),
      });

      print('✅ Challenge statistics updated successfully');
    } catch (e) {
      print('❌ Error updating challenge statistics: $e');
      // Don't show error to user as this is not critical
    }
  }

  Future<void> _loadCourseInfo() async {
    if (widget.challenge.courseId != null) {
      try {
        final courseDoc = await FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.challenge.courseId)
            .get();
        if (courseDoc.exists) {
          setState(() {
            _course =
                CourseModel.fromJson(courseDoc.data()!..['id'] = courseDoc.id);
          });
        }
      } catch (e) {
        print('Error loading course info: $e');
      }
    }
  }

  Future<void> _checkPreviousAttempt() async {
    try {
      final studentId = _getCurrentStudentId();

      // Check if student has already attempted this quiz
      final previousAttempts = await FirebaseFirestore.instance
          .collection('quiz_results')
          .where('challengeId', isEqualTo: widget.challenge.id)
          .where('studentId', isEqualTo: studentId)
          .get();

      if (previousAttempts.docs.isNotEmpty) {
        // Student has already attempted this quiz
        final lastAttempt = previousAttempts.docs.first.data();
        final lastScore = lastAttempt['score'] as double;
        final lastPassed = lastAttempt['passed'] as bool;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Previous Attempt Found'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You have already attempted this quiz.'),
                const SizedBox(height: 8),
                Text('Previous Score: ${lastScore.toStringAsFixed(1)}%'),
                Text('Status: ${lastPassed ? "Passed" : "Failed"}'),
                const SizedBox(height: 16),
                const Text(
                  'You can retake the quiz if you want to improve your score.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error checking previous attempt: $e');
      // Don't block the quiz if there's an error checking previous attempts
    }
  }

  // Helper method to get current student information
  String _getCurrentStudentId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return user.uid;
    }
    throw Exception('No user logged in');
  }

  String _getCurrentStudentName() {
    // TODO: Replace with actual authentication logic
    // For now, return a placeholder
    return 'Student';
  }

  Future<void> _viewQuizHistory() async {
    try {
      final studentId = _getCurrentStudentId();

      final quizHistory = await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .collection('quiz_history')
          .where('challengeId', isEqualTo: widget.challenge.id)
          .orderBy('submittedAt', descending: true)
          .get();

      if (quizHistory.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No previous attempts found for this quiz.'),
            backgroundColor: Colors.blue,
          ),
        );
        return;
      }

      // Show quiz history dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Quiz History'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: quizHistory.docs.length,
              itemBuilder: (context, index) {
                final attempt = quizHistory.docs[index].data();
                final score = attempt['score'] as double;
                final passed = attempt['passed'] as bool;
                final submittedAt = attempt['submittedAtString'] as String;

                return ListTile(
                  title: Text('Attempt ${index + 1}'),
                  subtitle: Text('Score: ${score.toStringAsFixed(1)}%'),
                  trailing: Icon(
                    passed ? Icons.check_circle : Icons.cancel,
                    color: passed ? Colors.green : Colors.red,
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error viewing quiz history: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading quiz history: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markChallengeAsCompleted(bool passed, double score) async {
    try {
      final studentId = _getCurrentStudentId();
      final data = {
        'challengeId': widget.challenge.id,
        'challengeTitle': widget.challenge.title,
        'completedAt': FieldValue.serverTimestamp(),
        'completedAtString': DateTime.now().toIso8601String(),
        'passed': passed,
        'score': score,
        'type': 'quiz',
        'lastAttemptedAt': FieldValue.serverTimestamp(),
        'lastAttemptedAtString': DateTime.now().toIso8601String(),
      };
      print('Writing to completed_challenges: $data');
      await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .collection('completed_challenges')
          .doc(widget.challenge.id)
          .set(data);
      print(
          '✅ Challenge marked as completed for student: $studentId with score: $score');

      // --- NEW: Write to challenge_submissions for check mark in challenge list ---
      if (passed) {
        final submissionData = {
          'challengeId': widget.challenge.id,
          'studentId': studentId,
          'status': 'passed',
          'type': 'quiz',
          'score': score,
          'submittedAt': FieldValue.serverTimestamp(),
          'submittedAtString': DateTime.now().toIso8601String(),
        };
        await FirebaseFirestore.instance
            .collection('challenge_submissions')
            .add(submissionData);
        print('✅ Written to challenge_submissions for check mark');

        // --- NEW: Update progress.completedChallenges for lesson unlock logic ---
        if (widget.challenge.courseId != null) {
          final progressDoc = FirebaseFirestore.instance
              .collection('progress')
              .doc(studentId + '_' + widget.challenge.courseId!);
          await progressDoc.set({
            'completedChallenges': FieldValue.arrayUnion([widget.challenge.id]),
          }, SetOptions(merge: true));
          print('✅ Updated progress.completedChallenges for lesson unlock');
        }
        // --- END NEW ---
      }
      // --- END NEW ---
    } catch (e) {
      print('❌ Error marking challenge as completed: $e');
    }
  }

  Future<void> _markCodingChallengeAsCompleted(
      bool passed, double score) async {
    try {
      final studentId = _getCurrentStudentId();
      final data = {
        'challengeId': widget.challenge.id,
        'challengeTitle': widget.challenge.title,
        'completedAt': FieldValue.serverTimestamp(),
        'completedAtString': DateTime.now().toIso8601String(),
        'passed': passed,
        'score': score,
        'type': 'coding',
        'lastAttemptedAt': FieldValue.serverTimestamp(),
        'lastAttemptedAtString': DateTime.now().toIso8601String(),
      };
      print('Writing coding challenge to completed_challenges: $data');
      await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .collection('completed_challenges')
          .doc(widget.challenge.id)
          .set(data);
      print(
          '✅ Coding challenge marked as completed for student: $studentId with score: $score, passed: $passed');

      // Update progress tracking only if passed
      if (passed && widget.challenge.courseId != null) {
        final progressDoc = FirebaseFirestore.instance
            .collection('progress')
            .doc(studentId + '_' + widget.challenge.courseId!);
        await progressDoc.set({
          'completedChallenges': FieldValue.arrayUnion([widget.challenge.id]),
        }, SetOptions(merge: true));
        print('✅ Updated progress.completedChallenges for coding challenge');
      }
    } catch (e) {
      print('❌ Error marking coding challenge as completed: $e');
    }
  }

  Future<void> _checkCompletedChallengeAccess() async {
    try {
      final studentId = _getCurrentStudentId();

      // Check if this challenge is completed (for all challenge types)
      final completedQuery = await FirebaseFirestore.instance
          .collection('completed_challenges')
          .where('challengeId', isEqualTo: widget.challenge.id)
          .where('userId', isEqualTo: studentId)
          .where('status', isEqualTo: 'passed')
          .limit(1)
          .get();

      if (completedQuery.docs.isNotEmpty) {
        // Challenge is completed - show review mode message but allow access
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Review mode: You can view this completed challenge but cannot retake it.'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking challenge access: $e');
    }
  }

  Future<void> _checkChallengeCompletion() async {
    try {
      final studentId = _getCurrentStudentId();

      // Check the main completed_challenges collection where the repository saves submissions
      final completedQuery = await FirebaseFirestore.instance
          .collection('completed_challenges')
          .where('challengeId', isEqualTo: widget.challenge.id)
          .where('userId', isEqualTo: studentId)
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .get();

      bool hasAttempted = false;
      bool hasPassed = false;
      double bestScore = 0.0;

      if (completedQuery.docs.isNotEmpty) {
        final data = completedQuery.docs.first.data();
        print('Read from completed_challenges: $data');
        hasAttempted = true;
        hasPassed = data['status'] == 'passed';
        bestScore = (data['score'] ?? 0.0).toDouble();
      }

      // Also check the main progress tracking to ensure consistency
      if (widget.challenge.courseId != null) {
        final courseProgressDocId = '${studentId}_${widget.challenge.courseId}';
        final progressDoc = await FirebaseFirestore.instance
            .collection('user_progress')
            .doc(courseProgressDocId)
            .get();

        if (progressDoc.exists) {
          final progressData = progressDoc.data()!;
          final completedChallenges =
              List<String>.from(progressData['completedChallenges'] ?? []);

          // If challenge is in completedChallenges, it means it was passed
          if (completedChallenges.contains(widget.challenge.id)) {
            hasPassed = true;
            print('Challenge found in progress tracking - confirmed passed');
          } else if (hasAttempted && !hasPassed) {
            // Challenge was attempted but failed - ensure it's not marked as passed
            hasPassed = false;
            print(
                'Challenge was attempted but failed - not in progress tracking');
          }
        }
      }

      setState(() {
        _isChallengeCompleted = hasAttempted;
        _hasPassedChallenge = hasPassed;
        _bestScore = bestScore;
        _isReviewMode = hasPassed; // Set review mode if challenge is passed
      });

      if (hasAttempted) {
        print(
            '✅ Challenge completion status loaded: Attempted: $hasAttempted, Passed: $hasPassed, Score: $bestScore');
      } else {
        print('ℹ️ Challenge not attempted yet');
      }
    } catch (e) {
      print('❌ Error checking challenge completion: $e');
      setState(() {
        _isChallengeCompleted = false;
        _hasPassedChallenge = false;
        _bestScore = 0.0;
      });
    }
  }

  Widget _buildChallengeHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.challenge.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.challenge.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                // Completion status indicator
                if (_isChallengeCompleted)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _hasPassedChallenge
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _hasPassedChallenge ? Colors.green : Colors.orange,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _hasPassedChallenge
                              ? Icons.check_circle
                              : Icons.pending,
                          color: _hasPassedChallenge
                              ? Colors.green
                              : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _hasPassedChallenge ? 'Passed' : 'Attempted',
                          style: TextStyle(
                            color: _hasPassedChallenge
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Review mode indicator
                if (_isReviewMode)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Review Mode',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (_isChallengeCompleted) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.blue.shade700, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Best Score: ${_bestScore.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_hasPassedChallenge)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  'You have already passed this challenge. Retakes are not allowed.',
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Test method to verify Firebase connection
  Future<void> _testFirebaseConnection() async {
    try {
      print('🧪 Testing Firebase connection...');

      final testData = {
        'test': true,
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'Firebase connection test',
      };

      await FirebaseFirestore.instance
          .collection('test')
          .doc('connection_test')
          .set(testData);

      print('✅ Firebase connection test successful');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Firebase connection test successful!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Firebase connection test failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Firebase connection test failed: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _saveFillInTheBlankSubmission(bool passed, double score) async {
    // Save submission to Firestore
    final studentId = _getCurrentStudentId();
    final studentName = _getCurrentStudentName();
    final submissionId =
        '${widget.challenge.id}_${DateTime.now().millisecondsSinceEpoch}';
    final submissionData = {
      'submissionId': submissionId,
      'challengeId': widget.challenge.id,
      'challengeTitle': widget.challenge.title,
      'challengeType': 'fillInTheBlank',
      'studentId': studentId,
      'studentName': studentName,
      'answers': _blankAnswers,
      'correctAnswers': widget.challenge.correctAnswers,
      'score': score,
      'passed': passed,
      'submittedAt': FieldValue.serverTimestamp(),
      'submittedAtString': DateTime.now().toIso8601String(),
      'lesson': widget.challenge.lesson,
      'courseId': widget.challenge.courseId ?? '',
      'status': passed ? 'passed' : 'failed',
    };
    await FirebaseFirestore.instance
        .collection('project_submissions')
        .doc(submissionId)
        .set(submissionData);

    // Mark challenge as completed for this student
    if (passed) {
      final challengeSubmissionData = {
        'challengeId': widget.challenge.id,
        'studentId': studentId,
        'status': 'passed',
        'type': 'fillInTheBlank',
        'score': score,
        'submittedAt': FieldValue.serverTimestamp(),
        'submittedAtString': DateTime.now().toIso8601String(),
      };
      await FirebaseFirestore.instance
          .collection('challenge_submissions')
          .add(challengeSubmissionData);

      // Update progress: add challengeId to completedChallenges
      if (widget.challenge.courseId != null) {
        final progressDoc = FirebaseFirestore.instance
            .collection('progress')
            .doc(studentId + '_' + widget.challenge.courseId!);
        await progressDoc.set({
          'userId': studentId,
          'courseId': widget.challenge.courseId!,
          'completedChallenges': FieldValue.arrayUnion([widget.challenge.id]),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(passed ? 'Challenge Passed' : 'Challenge Not Passed'),
        content: Text(passed
            ? '🎉 Congratulations! You passed the challenge.'
            : '❌ Sorry, your answers were not correct. Please try again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              if (passed) {
                if (widget.onChallengePassed != null) {
                  widget.onChallengePassed!();
                }
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    // Optionally: refresh UI/progress
    await _checkChallengeCompletion();
    setState(() {});
  }

  Future<void> _testErrorDetection() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      print('=== Testing Error Detection ===');

      // Run the comprehensive error detection test
      await _challengeRepository.testErrorDetection();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Error detection test completed. Check console for results.'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error during test: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _showChallengeCertificateText(
      String studentName, String challengeTitle, String date) async {
    final certificateText = '''
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                    🏆 CODEQUEST CHALLENGE CERTIFICATE 🏆                    ║
║                                                                              ║
║  This is to certify that                                                    ║
║                                                                              ║
║  ┌────────────────────────────────────────────────────────────────────────┐ ║
║  │                                                                        │ ║
║  │                    $studentName                                        │ ║
║  │                                                                        │ ║
║  └────────────────────────────────────────────────────────────────────────┘ ║
║                                                                              ║
║  has successfully completed the challenge:                                  ║
║                                                                              ║
║  ┌────────────────────────────────────────────────────────────────────────┐ ║
║  │                                                                        │ ║
║  │                 $challengeTitle                                        │ ║
║  │                                                                        │ ║
║  └────────────────────────────────────────────────────────────────────────┘ ║
║                                                                              ║
║  Date of Completion: $date                                                  ║
║  Issued by: CodeQuest                                                       ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
''';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.text_snippet, color: Colors.blue, size: 28),
            SizedBox(width: 10),
            Text('Text Certificate'),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            certificateText,
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 10, height: 1.2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
