import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:codequest/services/file_picker_service.dart';

class QuizFileUploadWidget extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onQuestionsLoaded;
  final List<Map<String, dynamic>> currentQuestions;

  const QuizFileUploadWidget({
    Key? key,
    required this.onQuestionsLoaded,
    required this.currentQuestions,
  }) : super(key: key);

  @override
  State<QuizFileUploadWidget> createState() => _QuizFileUploadWidgetState();
}

class _QuizFileUploadWidgetState extends State<QuizFileUploadWidget> {
  final FilePickerService _filePickerService = FilePickerService();
  PlatformFile? _selectedFile;
  bool _isLoading = false;
  String? _errorMessage;
  bool _appendMode = false; // New: toggle between replace and append mode

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              Icon(
                Icons.upload_file,
                color: Colors.blue[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Upload Quiz File',
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
            'Upload a DOCX or TXT file with questions in any reasonable format',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),

          // Upload mode selection
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload Mode:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Replace All Questions'),
                        subtitle: Text(
                          'Remove ${widget.currentQuestions.length} existing questions and load new ones',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        value: false,
                        groupValue: _appendMode,
                        onChanged: (value) {
                          setState(() {
                            _appendMode = value!;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Append Questions'),
                        subtitle: Text(
                          'Keep ${widget.currentQuestions.length} existing questions and add new ones',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        value: true,
                        groupValue: _appendMode,
                        onChanged: (value) {
                          setState(() {
                            _appendMode = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // File format instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Supported Formats:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _buildFormatInstruction('DOCX/TXT',
                    '1. What is the capital of France?\nA) Paris\nB) London\nC) Berlin\nD) Madrid\nCorrect: A\n\n2. Next question?\nA) Option 1\nB) Option 2\nC) Option 3\nD) Option 4\nCorrect: B'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange[600], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You can upload multiple files sequentially. Each file can contain multiple questions that will be automatically parsed.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // File selection and upload
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _pickFile,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_upload),
                      label: Text(_selectedFile?.name ?? 'Select Quiz File'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue[600],
                        side: BorderSide(color: Colors.blue[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isLoading ? null : _loadQuestions,
                      icon: const Icon(Icons.play_arrow),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                      ),
                      tooltip: 'Load Questions',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pickMultipleFiles,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Upload Multiple Files at Once'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green[600],
                    side: BorderSide(color: Colors.green[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_selectedFile != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'File selected: ${_selectedFile!.name}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : _clearFile,
                    icon: const Icon(Icons.close, size: 16),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(24, 24),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Current questions summary
          if (widget.currentQuestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
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
                      Icon(Icons.quiz, color: Colors.grey[600], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Current Questions: ${widget.currentQuestions.length}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (widget.currentQuestions.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _showCurrentQuestionsPreview(),
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('Preview'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue[600],
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue[600], size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You can continue uploading more files to add questions, or edit existing questions below.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormatInstruction(String format, String example) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$format: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              example,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _errorMessage = null;
    });

    final file = await _filePickerService.pickQuizFile();
    if (file != null) {
      setState(() {
        _selectedFile = file;
      });
    }
  }

  Future<void> _pickMultipleFiles() async {
    setState(() {
      _errorMessage = null;
    });

    final files = await _filePickerService.pickMultipleQuizFiles();
    if (files != null && files.isNotEmpty) {
      // Show file summary before processing
      final shouldProcess = await _showFileSummaryDialog(files);
      if (shouldProcess) {
        await _loadMultipleFiles(files);
      }
    }
  }

  Future<void> _loadQuestions() async {
    if (_selectedFile == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final content = await _filePickerService.readFileContent(_selectedFile!);
      if (content == null) {
        throw Exception('Could not read file content');
      }

      final fileExtension = _selectedFile!.extension ?? '';
      final questions =
          _filePickerService.parseQuizFile(content, fileExtension);

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
          throw Exception('Question ${i + 1} must have exactly 4 options');
        }

        for (var j = 0; j < options.length; j++) {
          if (options[j].toString().isEmpty) {
            throw Exception('Question ${i + 1}, Option ${j + 1} is empty');
          }
        }

        final correctAnswer = question['correctAnswer'] as int;
        if (correctAnswer < 0 || correctAnswer > 3) {
          throw Exception(
              'Question ${i + 1} has invalid correct answer (must be 0-3)');
        }
      }

      // Show confirmation dialog based on mode
      final shouldLoad = await _showConfirmationDialog(questions.length);
      if (shouldLoad) {
        // Prepare final questions list based on mode
        List<Map<String, dynamic>> finalQuestions;
        String actionMessage;

        if (_appendMode) {
          // Append mode: combine existing and new questions
          finalQuestions = [...widget.currentQuestions, ...questions];
          actionMessage =
              'Successfully appended ${questions.length} questions. Total: ${finalQuestions.length} questions';
        } else {
          // Replace mode: use only new questions
          finalQuestions = questions;
          actionMessage = 'Successfully loaded ${questions.length} questions';
        }

        widget.onQuestionsLoaded(finalQuestions);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(actionMessage),
              backgroundColor: Colors.green[600],
            ),
          );
        }

        // Clear the selected file after successful upload
        _clearFile();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMultipleFiles(List<PlatformFile> files) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Processing Files'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Processing ${files.length} file(s)...'),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we extract questions from all files.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final questions = await _filePickerService.parseMultipleQuizFiles(files);

      // Close progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (questions.isEmpty) {
        throw Exception(
            'No valid questions found in any of the files. Please check the formats.');
      }

      // Validate questions
      for (var i = 0; i < questions.length; i++) {
        final question = questions[i];
        if (question['question']?.toString().isEmpty ?? true) {
          throw Exception('Question ${i + 1} is empty');
        }

        final options = question['options'] as List<dynamic>;
        if (options.length != 4) {
          throw Exception('Question ${i + 1} must have exactly 4 options');
        }

        for (var j = 0; j < options.length; j++) {
          if (options[j].toString().isEmpty) {
            throw Exception('Question ${i + 1}, Option ${j + 1} is empty');
          }
        }

        final correctAnswer = question['correctAnswer'] as int;
        if (correctAnswer < 0 || correctAnswer > 3) {
          throw Exception(
              'Question ${i + 1} has invalid correct answer (must be 0-3)');
        }
      }

      // Show confirmation dialog for multiple files
      final shouldLoad = await _showMultipleFilesConfirmationDialog(
          questions.length, files.length);
      if (shouldLoad) {
        // Prepare final questions list based on mode
        List<Map<String, dynamic>> finalQuestions;
        String actionMessage;

        if (_appendMode) {
          // Append mode: combine existing and new questions
          finalQuestions = [...widget.currentQuestions, ...questions];
          actionMessage =
              'Successfully appended ${questions.length} questions from ${files.length} files. Total: ${finalQuestions.length} questions';
        } else {
          // Replace mode: use only new questions
          finalQuestions = questions;
          actionMessage =
              'Successfully loaded ${questions.length} questions from ${files.length} files';
        }

        widget.onQuestionsLoaded(finalQuestions);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(actionMessage),
              backgroundColor: Colors.green[600],
            ),
          );
        }
      }
    } catch (e) {
      // Close progress dialog if it's still open
      if (mounted) {
        Navigator.of(context).pop();
      }

      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _showConfirmationDialog(int questionCount) async {
    final currentCount = widget.currentQuestions.length;

    String title, content, buttonText;

    if (_appendMode) {
      title = 'Append Quiz Questions';
      content = currentCount > 0
          ? 'This will add $questionCount new question(s) to your existing $currentCount question(s). Total will be ${currentCount + questionCount} questions. Continue?'
          : 'Load $questionCount question(s) from the file?';
      buttonText = 'Append Questions';
    } else {
      title = 'Load Quiz Questions';
      content = currentCount > 0
          ? 'This will replace your current $currentCount question(s) with $questionCount new question(s) from the file. Continue?'
          : 'Load $questionCount question(s) from the file?';
      buttonText = 'Load Questions';
    }

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(buttonText),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showMultipleFilesConfirmationDialog(
      int questionCount, int fileCount) async {
    final currentCount = widget.currentQuestions.length;

    String title, content, buttonText;

    if (_appendMode) {
      title = 'Append Questions from Multiple Files';
      content = currentCount > 0
          ? 'This will add $questionCount new question(s) from $fileCount file(s) to your existing $currentCount question(s). Total will be ${currentCount + questionCount} questions. Continue?'
          : 'Load $questionCount question(s) from $fileCount file(s)?';
      buttonText = 'Append Questions';
    } else {
      title = 'Load Questions from Multiple Files';
      content = currentCount > 0
          ? 'This will replace your current $currentCount question(s) with $questionCount new question(s) from $fileCount file(s). Continue?'
          : 'Load $questionCount question(s) from $fileCount file(s)?';
      buttonText = 'Load Questions';
    }

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(buttonText),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showFileSummaryDialog(List<PlatformFile> files) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Files Selected for Upload'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You have selected ${files.length} file(s):'),
                const SizedBox(height: 12),
                ...files
                    .map((file) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                file.extension?.toLowerCase() == 'docx'
                                    ? Icons.description
                                    : Icons.text_snippet,
                                color: Colors.blue[600],
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  file.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                              Text(
                                '${(file.size / 1024).toStringAsFixed(1)} KB',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
                const SizedBox(height: 12),
                Text(
                  'All questions from these files will be automatically parsed and added to your quiz.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Process Files'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _clearFile() {
    setState(() {
      _selectedFile = null;
      _errorMessage = null;
    });
  }

  void _showCurrentQuestionsPreview() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Current Questions Preview (${widget.currentQuestions.length})'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.currentQuestions.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Q${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            question['question'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(4, (optionIndex) {
                      final isCorrect =
                          question['correctAnswer'] == optionIndex;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              isCorrect
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isCorrect
                                  ? Colors.green[600]
                                  : Colors.grey[400],
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${String.fromCharCode(65 + optionIndex)}) ${question['options'][optionIndex] ?? ''}',
                                style: TextStyle(
                                  color: isCorrect
                                      ? Colors.green[700]
                                      : Colors.grey[700],
                                  fontWeight: isCorrect
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }).toList(),
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
