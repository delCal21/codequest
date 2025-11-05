import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:archive/archive.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class FilePickerService {
  Future<PlatformFile?> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        return result.files.first;
      } else {
        // User canceled the picker
        return null;
      }
    } catch (e) {
      print('Error picking file: ${e.toString()}');
      return null;
    }
  }

  Future<PlatformFile?> pickQuizFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'txt', 'pdf'],
        allowMultiple: false,
      );

      if (result != null) {
        return result.files.first;
      } else {
        // User canceled the picker
        return null;
      }
    } catch (e) {
      print('Error picking quiz file: ${e.toString()}');
      return null;
    }
  }

  Future<List<PlatformFile>?> pickMultipleQuizFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'txt', 'pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files;
      } else {
        // User canceled the picker
        return null;
      }
    } catch (e) {
      print('Error picking multiple quiz files: ${e.toString()}');
      return null;
    }
  }

  Future<String?> readFileContent(PlatformFile file) async {
    try {
      final fileExtension = file.extension?.toLowerCase() ?? '';
      final hasInlineBytes = file.bytes != null && file.bytes!.isNotEmpty;
      
      // Safely check if path is available (web platforms don't support path)
      bool hasPath = false;
      String? filePath;
      try {
        filePath = file.path;
        hasPath = filePath != null;
      } catch (e) {
        // On web platforms, accessing path throws an exception
        hasPath = false;
        filePath = null;
      }

      print(
          '=== DEBUG: File size: ${file.size}, has path: $hasPath, has bytes: $hasInlineBytes ===');

      // DOCX handling (supports web via inline bytes)
      if (fileExtension == 'docx') {
        String content = '';

        // Try file path first (more reliable) - only on non-web platforms
        if (hasPath && !kIsWeb) {
          print('=== DEBUG: Trying file path ===');
          content = await _readDOCXFile(filePath!);
          print('=== DEBUG: File path result length: ${content.length} ===');
        }

        // If file path failed or not available, try bytes
        if (content.isEmpty && hasInlineBytes) {
          print('=== DEBUG: Trying bytes ===');
          content = _readDOCXFromBytes(file.bytes!);
          print('=== DEBUG: Bytes result length: ${content.length} ===');
        }

        if (content.isNotEmpty) return content;

        throw Exception(
            'Could not read DOCX file. Please convert to TXT format or check the file.');
      }

      // PDF handling
      if (fileExtension == 'pdf') {
        if (hasInlineBytes) {
          return _readPDFFromBytes(file.bytes!);
        }
        if (hasPath && !kIsWeb) {
          return await _readPDFFile(filePath!);
        }
        throw Exception('Could not read PDF file.');
      }

      // TXT handling
      if (fileExtension == 'txt') {
        if (hasInlineBytes) {
          return String.fromCharCodes(file.bytes!);
        }
        if (hasPath && !kIsWeb) {
          return await File(filePath!).readAsString();
        }
        throw Exception('Could not read TXT file.');
      }

      // Unsupported
      throw Exception(
          'Unsupported file type: $fileExtension. Please use DOCX, PDF, or TXT files only.');
    } catch (e) {
      print('Error reading file content: ${e.toString()}');
      rethrow; // Re-throw the exception so the UI can show the error message
    }
  }

  Future<String> _readDOCXFile(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      return _readDOCXFromBytes(bytes);
    } catch (e) {
      print('DOCX file reading error: $e');
      return '';
    }
  }

  String _readDOCXFromBytes(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentXml = archive.findFile('word/document.xml');
      if (documentXml != null) {
        final xmlContent = utf8.decode(documentXml.content as List<int>);
        return _extractTextFromDOCX(xmlContent);
      }
      return '';
    } catch (e) {
      print('DOCX bytes extraction failed: $e');
      return _extractReadableTextFromBytes(bytes);
    }
  }

  Future<String> _readPDFFile(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      return _readPDFFromBytes(bytes);
    } catch (e) {
      print('PDF file reading error: $e');
      return '';
    }
  }

  String _readPDFFromBytes(List<int> bytes) {
    try {
      return _extractReadableTextFromBytes(bytes);
    } catch (e) {
      print('PDF bytes extraction failed: $e');
      return '';
    }
  }

  String _extractTextFromDOCX(String xmlContent) {
    final StringBuffer buffer = StringBuffer();
    final RegExp paragraphRegex = RegExp(r'<w:p[\s\S]*?<\/w:p>');
    final RegExp textNodeRegex = RegExp(r'<w:t[^>]*>([\s\S]*?)<\/w:t>');

    final Iterable<RegExpMatch> paragraphMatches =
        paragraphRegex.allMatches(xmlContent);
    for (final RegExpMatch para in paragraphMatches) {
      final String paragraphXml = para.group(0) ?? '';
      final Iterable<RegExpMatch> textMatches =
          textNodeRegex.allMatches(paragraphXml);
      if (textMatches.isEmpty) continue;

      final String line = textMatches
          .map((m) => (m.group(1) ?? ''))
          .join('')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&apos;', "'")
          .trim();
      if (line.isNotEmpty) {
        buffer.writeln(line);
      }
    }

    if (buffer.isNotEmpty) {
      return buffer.toString().trim();
    }

    // Fallback: simple cleanup
    String text = xmlContent;
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
    return text.trim();
  }

  String _extractReadableTextFromBytes(List<int> bytes) {
    try {
      final decoded = utf8.decode(bytes, allowMalformed: true);
      if (decoded.trim().isNotEmpty) {
        return decoded;
      }
    } catch (_) {}

    // ASCII fallback
    final StringBuffer buffer = StringBuffer();
    for (final b in bytes) {
      if ((b >= 32 && b <= 126) || b == 9 || b == 10 || b == 13) {
        buffer.writeCharCode(b);
      }
    }
    return buffer.toString();
  }

  String _fixTruncatedText(String content) {
    // Look for truncated options like "D. It ca" and try to complete them
    // This is a heuristic approach to fix common truncation issues

    // Pattern 1: Look for "D. It ca" followed by "Answer:" and try to find the complete text
    final truncatedPattern = RegExp(
        r'([A-D]\.\s+[A-Za-z\s]+?)(?=\s*Answer\s*:)',
        caseSensitive: false);
    content = content.replaceAllMapped(truncatedPattern, (match) {
      final truncatedOption = match.group(1)?.trim() ?? '';
      print(
          '=== DEBUG: Found potentially truncated option: "$truncatedOption" ===');

      // Try to find the complete option by looking ahead
      final afterAnswer = content.substring(match.end);
      final nextOptionMatch = RegExp(r'^([A-D]\.\s+)', caseSensitive: false)
          .firstMatch(afterAnswer);

      if (nextOptionMatch != null) {
        // We found the next option, so the current one is complete
        return truncatedOption;
      }

      // If no next option found, this might be the last option
      return truncatedOption;
    });

    // Pattern 2: Fix lines where the 4th option is combined with the answer
    // e.g., "D. It can run without electricityAnswer: B" -> "D. It can run without electricity" + "Answer: B"
    final combinedPattern =
        RegExp(r'([A-D]\.\s+[^A]+?)(Answer\s*:[A-D])', caseSensitive: false);
    content = content.replaceAllMapped(combinedPattern, (match) {
      final optionPart = match.group(1)?.trim() ?? '';
      final answerPart = match.group(2)?.trim() ?? '';
      print(
          '=== DEBUG: Separated combined line: option="$optionPart", answer="$answerPart" ===');
      return '$optionPart\n$answerPart';
    });

    // Pattern 3: Fix lines where the 4th option is combined with the answer (more aggressive)
    // This catches cases like "D. It can run without electricityAnswer: B" that the above pattern missed
    final aggressivePattern =
        RegExp(r'([A-D]\.\s+[^A]+?)(Answer\s*:)', caseSensitive: false);
    content = content.replaceAllMapped(aggressivePattern, (match) {
      final optionPart = match.group(1)?.trim() ?? '';
      final answerPart = match.group(2)?.trim() ?? '';
      print(
          '=== DEBUG: Aggressively separated: option="$optionPart", answer="$answerPart" ===');
      return '$optionPart\n$answerPart';
    });

    return content;
  }

  List<Map<String, dynamic>> parseQuizFile(
      String content, String fileExtension) {
    try {
      print('=== DEBUG: Content length: ${content.length} ===');
      print(
          '=== DEBUG: First 200 chars: ${content.substring(0, content.length > 200 ? 200 : content.length)} ===');

      List<Map<String, dynamic>> questions;
      if (fileExtension.toLowerCase() == 'docx') {
        questions = _parseDOCX(content);
      } else if (fileExtension.toLowerCase() == 'pdf') {
        questions = _parsePDF(content);
      } else if (fileExtension.toLowerCase() == 'txt') {
        questions = _parseTXT(content);
      } else {
        questions = [];
      }

      print('=== DEBUG: Parsed ${questions.length} questions ===');
      return questions;
    } catch (e) {
      print('Error parsing quiz file: ${e.toString()}');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> parseMultipleQuizFiles(
      List<PlatformFile> files) async {
    try {
      List<Map<String, dynamic>> allQuestions = [];

      for (final file in files) {
        try {
          final content = await readFileContent(file);
          if (content != null && content.isNotEmpty) {
            final fileExtension = file.extension ?? '';
            final questions = parseQuizFile(content, fileExtension);
            allQuestions.addAll(questions);
            print(
                '=== DEBUG: Parsed ${questions.length} questions from ${file.name} ===');
          }
        } catch (e) {
          print('Error parsing file ${file.name}: ${e.toString()}');
          // Continue with other files even if one fails
        }
      }

      print(
          '=== DEBUG: Total questions from all files: ${allQuestions.length} ===');
      return allQuestions;
    } catch (e) {
      print('Error parsing multiple quiz files: ${e.toString()}');
      return [];
    }
  }

  List<Map<String, dynamic>> _parseDOCX(String content) {
    return _parseGeneric(content);
  }

  List<Map<String, dynamic>> _parsePDF(String content) {
    return _parseGeneric(content);
  }

  List<Map<String, dynamic>> _parseTXT(String content) {
    return _parseGeneric(content);
  }

  List<Map<String, dynamic>> _parseGeneric(String content) {
    print('=== DEBUG: Starting generic parsing ===');
    print('=== DEBUG: Content length: ${content.length} ===');

    // Clean up the content
    content = content.trim();
    // Pre-fix common DOCX/PDF extraction issues where option D is concatenated
    // with the answer token on the same line (e.g., "D. TextAnswer: B").
    content = _fixTruncatedText(content);

    // Split into lines and clean them
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    print('=== DEBUG: Total lines to parse: ${lines.length} ===');
    print('=== DEBUG: First 10 lines: ${lines.take(10).toList()} ===');

    final List<Map<String, dynamic>> questions = [];
    Map<String, dynamic>? currentQuestion;
    List<String> currentOptions = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      print('=== DEBUG: Processing line $i: "$line" ===');

      // Check if this is a question line
      bool isQuestion = false;
      String questionText = '';

      // Pattern 1: Q: Question text
      if (line.startsWith('Q:') || line.startsWith('q:')) {
        isQuestion = true;
        questionText = line.substring(2).trim();
      }
      // Pattern 2: Numbered questions (1., 2., etc.)
      else if (RegExp(r'^\d+[\.\)]\s+').hasMatch(line)) {
        isQuestion = true;
        questionText = line.replaceFirst(RegExp(r'^\d+[\.\)]\s+'), '').trim();
      }
      // Pattern 3: Lines ending with question mark
      else if (line.endsWith('?')) {
        isQuestion = true;
        questionText = line.trim();
      }
      // Pattern 4: Lines that are longer than 20 characters and don't look like options
      else if (line.length > 20 &&
          !RegExp(r'^[A-Da-d1-4][\.\)]\s+').hasMatch(line) &&
          !line.toLowerCase().contains('correct') &&
          !line.toLowerCase().contains('answer') &&
          !line.toLowerCase().contains('option')) {
        isQuestion = true;
        questionText = line.trim();
      }

      if (isQuestion) {
        // Save previous question if it exists
        if (currentQuestion != null && currentOptions.isNotEmpty) {
          // Ensure we have exactly 4 options
          while (currentOptions.length < 4) {
            currentOptions.add('Option ${currentOptions.length + 1}');
          }

          currentQuestion['options'] = currentOptions;
          questions.add(currentQuestion);
          print(
              '=== DEBUG: Added question: "${currentQuestion['question']}" with ${currentOptions.length} options ===');
        }

        // Start new question
        currentQuestion = {
          'question': questionText,
          'options': [],
          'correctAnswer': 0,
        };
        currentOptions = [];
        print('=== DEBUG: Started new question: "$questionText" ===');
        continue;
      }

      // Check if this is an option line
      bool isOption = false;
      String optionText = '';
      int optionIndex = -1;

      // Pattern 1: A: Option text, B: Option text, etc.
      if (RegExp(r'^[A-Da-d][\.\)]\s+').hasMatch(line)) {
        isOption = true;
        final match = RegExp(r'^([A-Da-d])[\.\)]\s+(.+)$').firstMatch(line);
        if (match != null) {
          final letter = match.group(1)!.toUpperCase();
          optionText = match.group(2)!.trim();
          optionIndex = 'ABCD'.indexOf(letter);
          // If the option line accidentally contains an appended answer token,
          // strip it and capture the correct answer.
          final suffixMatch = RegExp(
                  r'^(.*?)\s*(?:correct(?:\s+(?:answer|option))?|answer|ans(?:wer)?|key|solution)\s*(?:is|=|:)?\s*([A-Da-d1-4])\s*$',
                  caseSensitive: false)
              .firstMatch(optionText);
          if (suffixMatch != null) {
            final cleaned = (suffixMatch.group(1) ?? '').trim();
            final token = (suffixMatch.group(2) ?? '').toUpperCase();
            if (cleaned.isNotEmpty) optionText = cleaned;
            int idx = 0;
            if (token == 'A' || token == '1')
              idx = 0;
            else if (token == 'B' || token == '2')
              idx = 1;
            else if (token == 'C' || token == '3')
              idx = 2;
            else if (token == 'D' || token == '4') idx = 3;
            if (currentQuestion != null) {
              currentQuestion['correctAnswer'] = idx;
              print(
                  '=== DEBUG: Captured inline answer token on option: $token (index: $idx) ===');
            }
          }
        }
      }
      // Pattern 2: 1. Option text, 2. Option text, etc.
      else if (RegExp(r'^[1-4][\.\)]\s+').hasMatch(line)) {
        isOption = true;
        final match = RegExp(r'^([1-4])[\.\)]\s+(.+)$').firstMatch(line);
        if (match != null) {
          final number = int.parse(match.group(1)!);
          optionText = match.group(2)!.trim();
          optionIndex = number - 1; // Convert to 0-based index
          // Handle appended answer token at the end of numeric option lines too
          final suffixMatch = RegExp(
                  r'^(.*?)\s*(?:correct(?:\s+(?:answer|option))?|answer|ans(?:wer)?|key|solution)\s*(?:is|=|:)?\s*([A-Da-d1-4])\s*$',
                  caseSensitive: false)
              .firstMatch(optionText);
          if (suffixMatch != null) {
            final cleaned = (suffixMatch.group(1) ?? '').trim();
            final token = (suffixMatch.group(2) ?? '').toUpperCase();
            if (cleaned.isNotEmpty) optionText = cleaned;
            int idx = 0;
            if (token == 'A' || token == '1')
              idx = 0;
            else if (token == 'B' || token == '2')
              idx = 1;
            else if (token == 'C' || token == '3')
              idx = 2;
            else if (token == 'D' || token == '4') idx = 3;
            if (currentQuestion != null) {
              currentQuestion['correctAnswer'] = idx;
              print(
                  '=== DEBUG: Captured inline answer token on option (numeric): $token (index: $idx) ===');
            }
          }
        }
      }

      if (isOption &&
          optionText.isNotEmpty &&
          optionIndex >= 0 &&
          optionIndex < 4) {
        // Add option to current question
        if (currentQuestion != null) {
          // Ensure we have space for this option
          while (currentOptions.length <= optionIndex) {
            currentOptions.add('');
          }
          currentOptions[optionIndex] = optionText;
          print(
              '=== DEBUG: Added option ${optionIndex + 1}: "$optionText" ===');
        }
        continue;
      }

      // Check if this is an answer line (support multiple common formats)
      final lower = line.toLowerCase();
      if (lower.contains('correct') ||
          lower.contains('answer') ||
          lower.contains('ans') ||
          lower.contains('key') ||
          lower.contains('solution')) {
        if (currentQuestion != null) {
          // Try several regex patterns to extract the answer token (A-D or 1-4)
          final patterns = <RegExp>[
            // e.g., "Correct Answer: B", "Answer = 2", "Solution is C", "Key: A", "Correct option: D"
            RegExp(
                r'(?:correct(?:\s+(?:answer|option))?|answer|ans(?:wer)?|key|solution)\s*(?:is|=|:)?\s*([A-Da-d1-4])',
                caseSensitive: false),
            // e.g., "(B)" at end of line
            RegExp(r'\(([A-Da-d1-4])\)\s*$', caseSensitive: false),
            // e.g., trailing token "B" or "3"
            RegExp(r'([A-Da-d1-4])\s*(?:\.)?\s*$', caseSensitive: false),
          ];
          for (final pattern in patterns) {
            final match = pattern.firstMatch(line);
            if (match != null) {
              final token = match.group(1)!.toUpperCase();
              int correctAnswer = 0;
              if (token == 'A' || token == '1') {
                correctAnswer = 0;
              } else if (token == 'B' || token == '2') {
                correctAnswer = 1;
              } else if (token == 'C' || token == '3') {
                correctAnswer = 2;
              } else if (token == 'D' || token == '4') {
                correctAnswer = 3;
              }

              currentQuestion['correctAnswer'] = correctAnswer;
              print(
                  '=== DEBUG: Set correct answer to $token (index: $correctAnswer) ===');
              break;
            }
          }
        }
        continue;
      }

      // If we have a current question and this line doesn't look like an option or answer,
      // and we have less than 4 options, treat it as a fallback option
      if (currentQuestion != null &&
          currentOptions.length < 4 &&
          line.length > 3 &&
          !line.toLowerCase().contains('correct') &&
          !line.toLowerCase().contains('answer')) {
        // Find the next available option slot
        int nextSlot = currentOptions.length;
        currentOptions.add(line);
        print('=== DEBUG: Added fallback option ${nextSlot + 1}: "$line" ===');
      }
    }

    // Add the last question if it exists
    if (currentQuestion != null && currentOptions.isNotEmpty) {
      // Ensure we have exactly 4 options
      while (currentOptions.length < 4) {
        currentOptions.add('Option ${currentOptions.length + 1}');
      }

      currentQuestion['options'] = currentOptions;
      questions.add(currentQuestion);
      print(
          '=== DEBUG: Added final question: "${currentQuestion['question']}" with ${currentOptions.length} options ===');
    }

    // Final validation and cleanup
    final List<Map<String, dynamic>> validQuestions = [];
    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final options = question['options'] as List<dynamic>;

      // Ensure all options have content and fill empty ones
      for (int j = 0; j < options.length; j++) {
        if (options[j].toString().trim().isEmpty) {
          options[j] = 'Option ${String.fromCharCode(65 + j)}'; // A, B, C, D
        }
      }

      // All questions are valid after filling empty options
      validQuestions.add(question);
      print(
          '=== DEBUG: Question ${i + 1} is valid: "${question['question']}" with ${options.length} options ===');
    }

    print(
        '=== DEBUG: Final valid question count: ${validQuestions.length} ===');
    print('=== DEBUG: All questions: ===');
    for (int i = 0; i < validQuestions.length; i++) {
      final q = validQuestions[i];
      print('  Question ${i + 1}: "${q['question']}"');
      print('    Options: ${q['options']}');
      print('    Correct: ${q['correctAnswer']}');
    }
    return validQuestions;
  }
}
