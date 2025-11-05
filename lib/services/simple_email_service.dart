import 'package:flutter/foundation.dart';

class SimpleEmailService {
  /// Send a welcome email to a teacher using a simple web-based approach
  static Future<void> sendWelcomeEmail({
    required String teacherName,
    required String teacherEmail,
    required String teacherPassword,
  }) async {
    if (!kIsWeb) {
      // For mobile, we'll just log the email details
      print('Email would be sent to: $teacherEmail');
      print('Teacher: $teacherName');
      print('Password: $teacherPassword');
      return;
    }

    try {
      // Create email content
      final subject = 'Welcome to CodeQuest - Your Teacher Account';
      final body = '''
Dear $teacherName,

Welcome to CodeQuest! Your teacher account has been created by the administrator.

Your login credentials:
Email: $teacherEmail
Password: $teacherPassword

Please log in to the CodeQuest system and change your password for security.

Best regards,
CodeQuest Administration Team
      ''';

      // Log email details for admin to send manually
      print('Email details for: $teacherEmail');
      print('Subject: $subject');
      print('Body: $body');

      // In a real implementation, you might want to use a different approach
      // For now, we'll just log the details so the admin can send manually
    } catch (e) {
      print('Error preparing email: $e');
    }
  }

  /// Generate a simple email template
  static String generateEmailTemplate({
    required String teacherName,
    required String teacherEmail,
    required String teacherPassword,
  }) {
    return '''
Subject: Welcome to CodeQuest - Your Teacher Account

Dear $teacherName,

Welcome to CodeQuest! Your teacher account has been created by the administrator.

Your login credentials:
Email: $teacherEmail
Password: $teacherPassword

Please log in to the CodeQuest system and change your password for security.

Login URL: [Your CodeQuest Login URL]

Best regards,
CodeQuest Administration Team
    ''';
  }
}
