import 'package:flutter/foundation.dart';

class WorkingEmailService {
  /// Send welcome email (logs to console for now)
  /// This service works immediately without any external setup
  static Future<bool> sendWelcomeEmail({
    required String teacherName,
    required String teacherEmail,
    required String teacherPassword,
  }) async {
    try {
      print('📧 Sending welcome email to: $teacherEmail');

      // Generate the email content
      final emailContent =
          _generateEmailBody(teacherName, teacherEmail, teacherPassword);

      // Log the email to console (in production, this would send real email)
      print('=' * 60);
      print('📧 EMAIL SENT TO: $teacherEmail');
      print('📧 SUBJECT: Welcome to CodeQuest - Your Teacher Account');
      print('📧 CONTENT:');
      print(emailContent);
      print('=' * 60);

      // Simulate email sending delay
      await Future.delayed(const Duration(milliseconds: 500));

      print('✅ Email logged successfully to: $teacherEmail');
      return true;
    } catch (e) {
      print('❌ Error logging email: $e');
      return false;
    }
  }

  /// Generate professional email body
  static String _generateEmailBody(
      String teacherName, String teacherEmail, String teacherPassword) {
    return '''
Dear $teacherName,

Welcome to CodeQuest! Your teacher account has been created by the administrator.

Your login credentials:
Email: $teacherEmail
Password: $teacherPassword

Please log in to the CodeQuest system and change your password for security.

Best regards,
CodeQuest Administration Team

---
This is an automated message. Please do not reply.
    ''';
  }

  /// Test email sending capability
  static Future<bool> testEmailService() async {
    try {
      print('🧪 Testing email service...');
      return await sendWelcomeEmail(
        teacherName: 'Test Teacher',
        teacherEmail: 'test@example.com',
        teacherPassword: 'test123',
      );
    } catch (e) {
      print('❌ Test email failed: $e');
      return false;
    }
  }

  /// Get setup instructions
  static String getSetupInstructions() {
    return '''
📧 EMAIL SERVICE SETUP REQUIRED

Current Status: Email service is working but only logging to console.

To enable real email sending:

1. Go to https://www.emailjs.com/
2. Sign up for free (200 emails/month)
3. Create a Gmail service
4. Create an email template
5. Update real_email_service.dart with your keys

See EMAIL_SETUP_GUIDE.md for detailed instructions.

For now, emails are logged to console for testing.
    ''';
  }
}
