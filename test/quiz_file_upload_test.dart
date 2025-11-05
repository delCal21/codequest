import 'package:flutter_test/flutter_test.dart';
import 'package:codequest/services/file_picker_service.dart';

void main() {
  group('Quiz File Upload Tests', () {
    late FilePickerService filePickerService;

    setUp(() {
      filePickerService = FilePickerService();
    });

    group('DOCX Parsing', () {
      test('should parse valid DOCX format', () {
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
Correct: C''';

        final questions = filePickerService.parseQuizFile(docxContent, 'docx');

        expect(questions.length, equals(2));
        expect(
            questions[0]['question'], equals('What is the capital of France?'));
        expect(questions[0]['options'],
            equals(['Paris', 'London', 'Berlin', 'Madrid']));
        expect(questions[0]['correctAnswer'], equals(0));
        expect(
            questions[1]['question'],
            equals(
                'Which programming language is known as the "language of the web"?'));
        expect(questions[1]['options'],
            equals(['Java', 'Python', 'JavaScript', 'C++']));
        expect(questions[1]['correctAnswer'], equals(2));
      });

      test('should handle empty lines in DOCX', () {
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
Correct: C''';

        final questions = filePickerService.parseQuizFile(docxContent, 'docx');

        expect(questions.length, equals(2));
      });

      test('should return empty list for invalid DOCX', () {
        const docxContent = 'Invalid format content';

        final questions = filePickerService.parseQuizFile(docxContent, 'docx');

        expect(questions.length, equals(0));
      });
    });

    group('PDF Parsing', () {
      test('should parse valid PDF format', () {
        const pdfContent = '''1. What is the capital of France?
A) Paris
B) London
C) Berlin
D) Madrid
Correct: A

2. Which programming language is known as the web language?
A) Java
B) Python
C) JavaScript
D) C++
Correct: C''';

        final questions = filePickerService.parseQuizFile(pdfContent, 'pdf');

        expect(questions.length, equals(2));
        expect(
            questions[0]['question'], equals('What is the capital of France?'));
        expect(questions[0]['options'],
            equals(['Paris', 'London', 'Berlin', 'Madrid']));
        expect(questions[0]['correctAnswer'], equals(0));
      });

      test('should parse PDF with questions property', () {
        const pdfContent = '''1. What is the capital of France?
A) Paris
B) London
C) Berlin
D) Madrid
Correct: A''';

        final questions = filePickerService.parseQuizFile(pdfContent, 'pdf');

        expect(questions.length, equals(1));
        expect(
            questions[0]['question'], equals('What is the capital of France?'));
      });

      test('should return empty list for invalid PDF', () {
        const pdfContent = 'Invalid PDF content';

        final questions = filePickerService.parseQuizFile(pdfContent, 'pdf');

        expect(questions.length, equals(0));
      });
    });

    group('TXT Parsing', () {
      test('should parse valid TXT format', () {
        const txtContent = '''Q: What is the capital of France?
A: Paris
B: London
C: Berlin
D: Madrid
Correct: A

Q: Which programming language is known as the web language?
A: Java
B: Python
C: JavaScript
D: C++
Correct: C''';

        final questions = filePickerService.parseQuizFile(txtContent, 'txt');

        expect(questions.length, equals(2));
        expect(
            questions[0]['question'], equals('What is the capital of France?'));
        expect(questions[0]['options'],
            equals(['Paris', 'London', 'Berlin', 'Madrid']));
        expect(questions[0]['correctAnswer'], equals(0));
        expect(questions[1]['question'],
            equals('Which programming language is known as the web language?'));
        expect(questions[1]['options'],
            equals(['Java', 'Python', 'JavaScript', 'C++']));
        expect(questions[1]['correctAnswer'], equals(2));
      });

      test('should handle case insensitive correct answers', () {
        const txtContent = '''Q: What is the capital of France?
A: Paris
B: London
C: Berlin
D: Madrid
Correct: a''';

        final questions = filePickerService.parseQuizFile(txtContent, 'txt');

        expect(questions.length, equals(1));
        expect(questions[0]['correctAnswer'], equals(0));
      });

      test('should return empty list for invalid TXT format', () {
        const txtContent = 'Invalid text format without proper structure';

        final questions = filePickerService.parseQuizFile(txtContent, 'txt');

        expect(questions.length, equals(0));
      });
    });

    group('File Extension Handling', () {
      test('should handle different case extensions', () {
        const content =
            '1. What is the capital of France?\nA) Paris\nB) London\nC) Berlin\nD) Madrid\nCorrect: A';

        final questionsDocx = filePickerService.parseQuizFile(content, 'DOCX');
        final questionsPdf = filePickerService.parseQuizFile(content, 'PDF');
        final questionsTxt = filePickerService.parseQuizFile(content, 'TXT');

        expect(questionsDocx.length, equals(1));
        expect(questionsPdf.length, equals(1));
        expect(questionsTxt.length, equals(0));
      });

      test('should handle unknown file extensions', () {
        const content = 'Some content';

        final questions = filePickerService.parseQuizFile(content, 'unknown');

        expect(questions.length, equals(0));
      });
    });
  });
}
