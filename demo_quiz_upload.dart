// Simple demo of quiz file parsing functionality
// This can be run with: dart demo_quiz_upload.dart

void main() {
  print('=== Quiz File Upload Feature Demo ===\n');

  // Demo DOCX parsing
  print('1. DOCX Format Demo:');
  const docxContent = '''1. What is the capital of France?
A) Paris
B) London
C) Berlin
D) Madrid
Correct: A

2. Which programming language is known as the "language of the web"?
A) Java
B) Python
C) JavaScript
D) C++
Correct: C

3. What does HTML stand for?
A) Hyper Text Markup Language
B) High Tech Modern Language
C) Home Tool Markup Language
D) Hyperlink and Text Markup Language
Correct: A''';

  final docxQuestions = _parseDOCX(docxContent);
  print('Parsed ${docxQuestions.length} questions from DOCX:');
  for (var i = 0; i < docxQuestions.length; i++) {
    final question = docxQuestions[i];
    print('  Q${i + 1}: ${question['question']}');
    print('    A: ${question['options'][0]}');
    print('    B: ${question['options'][1]}');
    print('    C: ${question['options'][2]}');
    print('    D: ${question['options'][3]}');
    print(
        '    Correct: ${String.fromCharCode(65 + (question['correctAnswer'] as int))}');
    print('');
  }

  // Demo PDF parsing
  print('2. PDF Format Demo:');
  const pdfContent = '''1. What is the primary purpose of CSS?
A) To create databases
B) To style web pages
C) To write server code
D) To create animations
Correct: B

2. Which of the following is a JavaScript framework?
A) Django
B) Flask
C) React
D) Express
Correct: C''';

  final pdfQuestions = _parsePDF(pdfContent);
  print('Parsed ${pdfQuestions.length} questions from PDF:');
  for (var i = 0; i < pdfQuestions.length; i++) {
    final question = pdfQuestions[i];
    print('  Q${i + 1}: ${question['question']}');
    print('    A: ${question['options'][0]}');
    print('    B: ${question['options'][1]}');
    print('    C: ${question['options'][2]}');
    print('    D: ${question['options'][3]}');
    print(
        '    Correct: ${String.fromCharCode(65 + (question['correctAnswer'] as int))}');
    print('');
  }

  // Demo TXT parsing
  print('3. TXT Format Demo:');
  const txtContent = '''Q: What is the capital of France?
A: Paris
B: London
C: Berlin
D: Madrid
Correct: A

Q: Which programming language is known as the "language of the web"?
A: Java
B: Python
C: JavaScript
D: C++
Correct: C''';

  final txtQuestions = _parseTXT(txtContent);
  print('Parsed ${txtQuestions.length} questions from TXT:');
  for (var i = 0; i < txtQuestions.length; i++) {
    final question = txtQuestions[i];
    print('  Q${i + 1}: ${question['question']}');
    print('    A: ${question['options'][0]}');
    print('    B: ${question['options'][1]}');
    print('    C: ${question['options'][2]}');
    print('    D: ${question['options'][3]}');
    print(
        '    Correct: ${String.fromCharCode(65 + (question['correctAnswer'] as int))}');
    print('');
  }

  // Demo error handling
  print('4. Error Handling Demo:');
  const invalidContent = 'Invalid format content';
  final invalidQuestions = _parseDOCX(invalidContent);
  print(
      'Invalid DOCX content resulted in ${invalidQuestions.length} questions');

  print('=== Demo Complete ===');
  print('\nTeachers can now:');
  print('1. Create quiz files in Word (.docx), PDF, or TXT format');
  print('2. Upload them using the Quiz File Upload widget');
  print('3. Automatically populate quiz questions');
  print('4. Edit questions after upload if needed');
  print('5. Save time creating comprehensive quizzes!');
}

// Simplified parsing functions for demo
List<Map<String, dynamic>> _parseDOCX(String content) {
  final lines = content.split('\n');
  final questions = <Map<String, dynamic>>[];
  Map<String, dynamic>? currentQuestion;

  for (var line in lines) {
    line = line.trim();
    if (line.isEmpty) continue;

    // Look for question patterns (lines ending with ? or starting with numbers)
    if (line.contains('?') || RegExp(r'^\d+[\.\)]').hasMatch(line)) {
      // Save previous question if exists
      if (currentQuestion != null &&
          (currentQuestion['options'] as List).any((opt) => opt.isNotEmpty)) {
        questions.add(currentQuestion);
      }

      // Start new question
      currentQuestion = {
        'question': line.replaceAll(RegExp(r'^\d+[\.\)]\s*'), '').trim(),
        'options': ['', '', '', ''],
        'correctAnswer': 0,
      };
    } else if (currentQuestion != null) {
      // Look for option patterns (A), B), C), D) or a), b), c), d)
      final optionMatch = RegExp(r'^[A-Da-d][\.\)]\s*(.+)$').firstMatch(line);
      if (optionMatch != null) {
        final optionLetter = line[0].toUpperCase();
        final optionText = optionMatch.group(1)?.trim() ?? '';

        switch (optionLetter) {
          case 'A':
            currentQuestion['options'][0] = optionText;
            break;
          case 'B':
            currentQuestion['options'][1] = optionText;
            break;
          case 'C':
            currentQuestion['options'][2] = optionText;
            break;
          case 'D':
            currentQuestion['options'][3] = optionText;
            break;
        }
      } else if (line.toLowerCase().contains('correct') ||
          line.toLowerCase().contains('answer')) {
        // Look for correct answer indicator
        final correctMatch = RegExp(r'[A-Da-d]').firstMatch(line);
        if (correctMatch != null) {
          final correctLetter = correctMatch.group(0)?.toUpperCase() ?? 'A';
          switch (correctLetter) {
            case 'A':
              currentQuestion['correctAnswer'] = 0;
              break;
            case 'B':
              currentQuestion['correctAnswer'] = 1;
              break;
            case 'C':
              currentQuestion['correctAnswer'] = 2;
              break;
            case 'D':
              currentQuestion['correctAnswer'] = 3;
              break;
          }
        }
      }
    }
  }

  // Add the last question
  if (currentQuestion != null &&
      (currentQuestion['options'] as List).any((opt) => opt.isNotEmpty)) {
    questions.add(currentQuestion);
  }

  return questions;
}

List<Map<String, dynamic>> _parsePDF(String content) {
  // PDF content is typically plain text, so we can use similar parsing as DOCX
  final lines = content.split('\n');
  final questions = <Map<String, dynamic>>[];
  Map<String, dynamic>? currentQuestion;

  for (var line in lines) {
    line = line.trim();
    if (line.isEmpty) continue;

    // Look for question patterns (lines ending with ? or starting with numbers)
    if (line.contains('?') || RegExp(r'^\d+[\.\)]').hasMatch(line)) {
      // Save previous question if exists
      if (currentQuestion != null &&
          (currentQuestion['options'] as List).any((opt) => opt.isNotEmpty)) {
        questions.add(currentQuestion);
      }

      // Start new question
      currentQuestion = {
        'question': line.replaceAll(RegExp(r'^\d+[\.\)]\s*'), '').trim(),
        'options': ['', '', '', ''],
        'correctAnswer': 0,
      };
    } else if (currentQuestion != null) {
      // Look for option patterns (A), B), C), D) or a), b), c), d)
      final optionMatch = RegExp(r'^[A-Da-d][\.\)]\s*(.+)$').firstMatch(line);
      if (optionMatch != null) {
        final optionLetter = line[0].toUpperCase();
        final optionText = optionMatch.group(1)?.trim() ?? '';

        switch (optionLetter) {
          case 'A':
            currentQuestion['options'][0] = optionText;
            break;
          case 'B':
            currentQuestion['options'][1] = optionText;
            break;
          case 'C':
            currentQuestion['options'][2] = optionText;
            break;
          case 'D':
            currentQuestion['options'][3] = optionText;
            break;
        }
      } else if (line.toLowerCase().contains('correct') ||
          line.toLowerCase().contains('answer')) {
        // Look for correct answer indicator
        final correctMatch = RegExp(r'[A-Da-d]').firstMatch(line);
        if (correctMatch != null) {
          final correctLetter = correctMatch.group(0)?.toUpperCase() ?? 'A';
          switch (correctLetter) {
            case 'A':
              currentQuestion['correctAnswer'] = 0;
              break;
            case 'B':
              currentQuestion['correctAnswer'] = 1;
              break;
            case 'C':
              currentQuestion['correctAnswer'] = 2;
              break;
            case 'D':
              currentQuestion['correctAnswer'] = 3;
              break;
          }
        }
      }
    }
  }

  // Add the last question
  if (currentQuestion != null &&
      (currentQuestion['options'] as List).any((opt) => opt.isNotEmpty)) {
    questions.add(currentQuestion);
  }

  return questions;
}

List<Map<String, dynamic>> _parseTXT(String content) {
  final lines = content.split('\n');
  final questions = <Map<String, dynamic>>[];
  Map<String, dynamic>? currentQuestion;

  for (var line in lines) {
    line = line.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('Q:')) {
      if (currentQuestion != null) {
        questions.add(currentQuestion);
      }

      currentQuestion = {
        'question': line.substring(2).trim(),
        'options': ['', '', '', ''],
        'correctAnswer': 0,
      };
    } else if (line.startsWith('A:') && currentQuestion != null) {
      currentQuestion['options'][0] = line.substring(2).trim();
    } else if (line.startsWith('B:') && currentQuestion != null) {
      currentQuestion['options'][1] = line.substring(2).trim();
    } else if (line.startsWith('C:') && currentQuestion != null) {
      currentQuestion['options'][2] = line.substring(2).trim();
    } else if (line.startsWith('D:') && currentQuestion != null) {
      currentQuestion['options'][3] = line.substring(2).trim();
    } else if (line.startsWith('Correct:') && currentQuestion != null) {
      final correct = line.substring(8).trim().toUpperCase();
      switch (correct) {
        case 'A':
          currentQuestion['correctAnswer'] = 0;
          break;
        case 'B':
          currentQuestion['correctAnswer'] = 1;
          break;
        case 'C':
          currentQuestion['correctAnswer'] = 2;
          break;
        case 'D':
          currentQuestion['correctAnswer'] = 3;
          break;
      }
    }
  }

  if (currentQuestion != null) {
    questions.add(currentQuestion);
  }

  return questions;
}
