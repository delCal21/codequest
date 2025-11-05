import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:codequest/services/file_picker_service.dart';

class GoogleFormsQuizWidget extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onQuestionsLoaded;
  final List<Map<String, dynamic>> currentQuestions;

  const GoogleFormsQuizWidget({
    Key? key,
    required this.onQuestionsLoaded,
    required this.currentQuestions,
  }) : super(key: key);

  @override
  State<GoogleFormsQuizWidget> createState() => _GoogleFormsQuizWidgetState();
}

class _GoogleFormsQuizWidgetState extends State<GoogleFormsQuizWidget> {
  final FilePickerService _filePickerService = FilePickerService();
  PlatformFile? _selectedFile;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showForm = false;

  // Quiz questions
  List<Map<String, dynamic>> _quizQuestions = [];

  void _syncParent() {
    // Send a shallow copy to avoid external mutation issues
    widget.onQuestionsLoaded(List<Map<String, dynamic>>.from(_quizQuestions));
  }

  @override
  void initState() {
    super.initState();
    _quizQuestions = List.from(widget.currentQuestions);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              Icon(
                Icons.quiz,
                color: Colors.green[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Challenge Forms',
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
            '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          // File upload section
          if (!_showForm) _buildFileUploadSection(),

          // Quiz form section
          if (_showForm) _buildQuizFormSection(),

          // Toggle button
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _showForm = !_showForm;
                  if (_showForm && _quizQuestions.isEmpty) {
                    _addQuestion();
                  }
                });
              },
              icon: Icon(_showForm ? Icons.upload_file : Icons.edit),
              label: Text(
                  _showForm ? 'Upload File Instead' : 'Create Quiz Manually'),
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
    );
  }

  Widget _buildFileUploadSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📄 Upload Quiz File',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Supported formats: Word (.docx) and PDF (.pdf)\nThe file will be analyzed to extract quiz information.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Text(
              '📝 Format: Each question must have exactly 4 options (A, B, C, D) with content in all fields.',
              style: TextStyle(fontSize: 12, color: Colors.amber[800]),
            ),
          ),
          const SizedBox(height: 16),

          // File picker
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: Text(_selectedFile?.name ?? 'Select Word or PDF File'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey[400]!),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (_selectedFile != null)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedFile = null;
                      _errorMessage = null;
                    });
                  },
                  icon: const Icon(Icons.clear, color: Colors.red),
                  tooltip: 'Clear file',
                ),
            ],
          ),

          if (_selectedFile != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.file_present, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFile!.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Size: ${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _processFile,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                    _isLoading ? 'Processing...' : 'Process File & Fill Form'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizFormSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📝 Quiz Form',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Quiz Questions',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),

          // Questions list
          ...List.generate(_quizQuestions.length, (index) {
            return _buildQuestionCard(index);
          }),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addQuestion,
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
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    return Container(
      key: ValueKey('question_$index'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Question ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (_quizQuestions.length > 1)
                IconButton(
                  onPressed: () => _removeQuestion(index),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Remove question',
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _quizQuestions[index]['question'] ?? '',
            decoration: const InputDecoration(
              labelText: 'Question Text',
              border: OutlineInputBorder(),
              hintText: 'Enter your question here',
            ),
            onChanged: (value) {
              _quizQuestions[index]['question'] = value;
              _syncParent();
            },
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          const Text(
            'Options:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...List.generate(4, (optionIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Radio<int>(
                    value: optionIndex,
                    groupValue: (() {
                      final raw = _quizQuestions[index]['correctAnswer'];
                      if (raw is int) return raw;
                      if (raw is String) {
                        final parsed = int.tryParse(raw);
                        if (parsed != null) return parsed;
                      }
                      return 0;
                    })(),
                    onChanged: (value) {
                      setState(() {
                        _quizQuestions[index]['correctAnswer'] = value!;
                      });
                      _syncParent();
                    },
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue:
                          _quizQuestions[index]['options']?[optionIndex] ?? '',
                      decoration: InputDecoration(
                        labelText:
                            'Option ${String.fromCharCode(65 + optionIndex)}',
                        border: const OutlineInputBorder(),
                        hintText:
                            'Enter option ${String.fromCharCode(65 + optionIndex)}',
                      ),
                      onChanged: (value) {
                        if (_quizQuestions[index]['options'] == null) {
                          _quizQuestions[index]['options'] = ['', '', '', ''];
                        }
                        _quizQuestions[index]['options'][optionIndex] = value;
                        _syncParent();
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: $e';
      });
    }
  }

  Future<void> _processFile() async {
    if (_selectedFile == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('=== DEBUG: Starting file processing ===');
      print('=== DEBUG: File name: ${_selectedFile!.name} ===');
      print('=== DEBUG: File extension: ${_selectedFile!.extension} ===');
      print('=== DEBUG: File size: ${_selectedFile!.size} bytes ===');

      final content = await _filePickerService.readFileContent(_selectedFile!);
      if (content == null) {
        throw Exception('Could not read file content');
      }

      print('=== DEBUG: File content length: ${content.length} ===');
      print(
          '=== DEBUG: First 300 characters: ${content.substring(0, content.length > 300 ? 300 : content.length)} ===');

      final fileExtension = _selectedFile!.extension ?? '';
      final questions =
          _filePickerService.parseQuizFile(content, fileExtension);

      print('=== DEBUG: Parsed questions count: ${questions.length} ===');
      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];
        print('=== DEBUG: Question ${i + 1}: "${q['question']}" ===');
        print('=== DEBUG: Options: ${q['options']} ===');
        print('=== DEBUG: Correct answer: ${q['correctAnswer']} ===');
      }

      if (questions.isEmpty) {
        throw Exception(
            'No valid questions found in the file. Please check the format.');
      }

      // Validate questions
      for (var i = 0; i < questions.length; i++) {
        final question = questions[i];
        if (question['question']?.toString().isEmpty ?? true) {
          throw Exception('Question ${i + 1} is empty');
        }

        final options = question['options'] as List<dynamic>;
        if (options.length != 4) {
          throw Exception(
              'Question ${i + 1} must have exactly 4 options (A, B, C, D)');
        }

        for (var j = 0; j < options.length; j++) {
          if (options[j].toString().trim().isEmpty) {
            final optionLetter = String.fromCharCode(65 + j); // A, B, C, D
            throw Exception(
                'Question ${i + 1}, Option ${optionLetter} is empty. Please ensure all options have content.');
          }
        }

        final correctAnswer = question['correctAnswer'] as int;
        if (correctAnswer < 0 || correctAnswer > 3) {
          throw Exception(
              'Question ${i + 1} has invalid correct answer (must be 0-3, where 0=A, 1=B, 2=C, 3=D)');
        }
      }

      setState(() {
        _quizQuestions = questions;
        _showForm = true;
      });

      // Ensure all questions have 4 valid options
      _ensureValidOptions();
      _syncParent();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully processed ${questions.length} questions from file!'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('=== DEBUG: Error processing file: $e ===');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addQuestion() {
    setState(() {
      _quizQuestions.add({
        'question': '',
        'options': ['', '', '', ''],
        'correctAnswer': 0,
      });
    });
    _syncParent();
  }

  void _removeQuestion(int index) {
    setState(() {
      _quizQuestions.removeAt(index);
    });
    _syncParent();
  }

  void _saveQuiz() {
    // Validate form
    print(
        '=== DEBUG: _saveQuiz called with ${_quizQuestions.length} questions ===');

    for (int i = 0; i < _quizQuestions.length; i++) {
      final q = _quizQuestions[i];
      print('=== DEBUG: Question ${i + 1}: "${q['question']}" ===');
      print('=== DEBUG: Options: ${q['options']} ===');
      print('=== DEBUG: Correct answer: ${q['correctAnswer']} ===');
    }

    if (_quizQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one question'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Ensure all questions have 4 valid options
    for (var i = 0; i < _quizQuestions.length; i++) {
      final question = _quizQuestions[i];
      if (question['question']?.toString().trim().isEmpty ?? true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Question ${i + 1} cannot be empty'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Ensure options array exists and has 4 elements
      if (question['options'] == null) {
        question['options'] = ['', '', '', ''];
      }

      final options = question['options'] as List<dynamic>;

      // Fill any missing options with placeholder text
      while (options.length < 4) {
        options.add('Option ${options.length + 1}');
      }

      // Replace empty options with placeholder text
      for (var j = 0; j < options.length; j++) {
        if (options[j].toString().trim().isEmpty) {
          options[j] = 'Option ${String.fromCharCode(65 + j)}';
        }
      }

      print('=== DEBUG: Question ${i + 1} options after fixing: $options ===');
    }

    // Save quiz
    print('=== DEBUG: All validation passed, calling onQuestionsLoaded ===');
    widget.onQuestionsLoaded(_quizQuestions);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quiz saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _ensureValidOptions() {
    print('=== DEBUG: Ensuring all questions have 4 valid options ===');
    for (var i = 0; i < _quizQuestions.length; i++) {
      final question = _quizQuestions[i];
      if (question['options'] == null) {
        question['options'] = ['', '', '', ''];
      }
      final options = question['options'] as List<dynamic>;
      while (options.length < 4) {
        options.add('Option ${options.length + 1}');
      }
      for (var j = 0; j < options.length; j++) {
        if (options[j].toString().trim().isEmpty) {
          options[j] = 'Option ${String.fromCharCode(65 + j)}';
        }
      }
      print(
          '=== DEBUG: Question ${i + 1} options after ensuring: $options ===');
    }
    setState(() {}); // Trigger rebuild to show the updated options
    _syncParent();
  }
}
