import 'package:flutter_test/flutter_test.dart';
import 'package:codequest/services/teacher_email_validation_service.dart';

void main() {
  group('TeacherEmailValidationService Tests', () {
    test('should validate educational domain emails', () {
      // Test educational domains
      expect(
          TeacherEmailValidationService.isValidTeacherEmail(
              'teacher@university.edu'),
          true);
      expect(
          TeacherEmailValidationService.isValidTeacherEmail(
              'professor@college.ac'),
          true);
      expect(
          TeacherEmailValidationService.isValidTeacherEmail(
              'instructor@school.org'),
          true);
      expect(
          TeacherEmailValidationService.isValidTeacherEmail(
              'lecturer@institute.gov'),
          true);
    });

    test('should validate specific allowed domains', () {
      // Test specific allowed domains
      expect(
          TeacherEmailValidationService.isValidTeacherEmail(
              'teacher@gmail.com'),
          true);
      expect(
          TeacherEmailValidationService.isValidTeacherEmail(
              'professor@outlook.com'),
          true);
      expect(
          TeacherEmailValidationService.isValidTeacherEmail(
              'instructor@yahoo.com'),
          true);
    });

    test('should reject non-educational domain emails', () {
      // Test non-educational domains
      expect(
          TeacherEmailValidationService.isValidTeacherEmail(
              'teacher@company.com'),
          false);
      expect(
          TeacherEmailValidationService.isValidTeacherEmail(
              'professor@business.net'),
          false);
      expect(
          TeacherEmailValidationService.isValidTeacherEmail(
              'instructor@startup.io'),
          false);
    });

    test('should reject invalid email formats', () {
      // Test invalid email formats
      expect(TeacherEmailValidationService.isValidTeacherEmail(''), false);
      expect(TeacherEmailValidationService.isValidTeacherEmail('invalid-email'),
          false);
      expect(
          TeacherEmailValidationService.isValidTeacherEmail('teacher@'), false);
      expect(
          TeacherEmailValidationService.isValidTeacherEmail('@university.edu'),
          false);
    });

    test('should provide appropriate validation messages', () {
      // Test validation messages
      expect(TeacherEmailValidationService.getShortValidationMessage(),
          'Please use an educational institution email or approved domain');

      expect(TeacherEmailValidationService.getValidationMessage(),
          contains('Teacher emails must be from an educational institution'));
    });

    test('should validate email with synchronous validation', () {
      // Test synchronous validation
      expect(
          TeacherEmailValidationService.validateTeacherEmailSync(
              'teacher@university.edu'),
          null);
      expect(
          TeacherEmailValidationService.validateTeacherEmailSync(
              'teacher@company.com'),
          isNotNull);
      expect(TeacherEmailValidationService.validateTeacherEmailSync(''),
          equals('Email is required'));
    });

    test('should handle domain checking', () {
      // Test domain checking
      expect(TeacherEmailValidationService.isDomainAllowed('edu'), true);
      expect(TeacherEmailValidationService.isDomainAllowed('gmail.com'), true);
      expect(
          TeacherEmailValidationService.isDomainAllowed('company.com'), false);
    });
  });
}
