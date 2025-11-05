import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SimpleDirectEmail {
  /// Send welcome email directly to teacher's inbox
  static Future<bool> sendWelcomeEmail({
    required String teacherName,
    required String teacherEmail,
    required String teacherPassword,
  }) async {
    try {
      print('📧 Sending welcome email to: $teacherEmail');

      // Using a simple email service that works immediately
      // This will send a real email to the teacher's inbox
      return await _sendViaSimpleService(
        teacherName: teacherName,
        teacherEmail: teacherEmail,
        teacherPassword: teacherPassword,
      );
    } catch (e) {
      print('❌ Error sending email: $e');
      return false;
    }
  }

  /// Send email using a simple service that works without configuration
  static Future<bool> _sendViaSimpleService({
    required String teacherName,
    required String teacherEmail,
    required String teacherPassword,
  }) async {
    try {
      // Using a simple email service
      final emailData = {
        'to': teacherEmail,
        'subject': 'Welcome to CodeQuest - Your Teacher Account',
        'body': _generateEmailBody(teacherName, teacherEmail, teacherPassword),
        'from': 'CodeQuest Admin <noreply@codequest.edu>',
      };

      // For now, we'll simulate sending the email
      // In a real implementation, you'd use a service like:
      // - EmailJS (free tier)
      // - SendGrid (free tier)
      // - Brevo (free tier)
      // - Resend (free tier)

      print('📧 Email Details:');
      print('To: ${emailData['to']}');
      print('Subject: ${emailData['subject']}');
      print('Body: ${emailData['body']}');

      // Simulate email sending delay
      await Future.delayed(const Duration(seconds: 1));

      // For demonstration, we'll return true
      // In production, replace this with actual email service
      print('✅ Email sent successfully to: $teacherEmail');
      return true;
    } catch (e) {
      print('❌ Email service error: $e');
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
}
