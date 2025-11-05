import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RealEmailService {
  // EmailJS configuration (free tier: 200 emails/month)
  // ✅ Service ID: service_3wnmqqm (configured)
  // ✅ Template ID: template_md2nhco (configured)
  // ✅ Public Key: Z7zKku6N2zYHp1Zhu (configured)
  static const String _serviceId = 'service_3wnmqqm'; // Your actual service ID
  static const String _templateId =
      'template_md2nhco'; // Replace with your template ID
  static const String _publicKey =
      'Z7zKku6N2zYHp1Zhu'; // Replace with your public key

  /// Send welcome email directly to teacher's inbox
  static Future<bool> sendWelcomeEmail({
    required String teacherName,
    required String teacherEmail,
    required String teacherPassword,
  }) async {
    try {
      print('📧 Sending welcome email to: $teacherEmail');

      // Using EmailJS service for real email sending
      return await _sendViaEmailJS(
        teacherName: teacherName,
        teacherEmail: teacherEmail,
        teacherPassword: teacherPassword,
      );
    } catch (e) {
      print('❌ Error sending email: $e');
      return false;
    }
  }

  /// Send email using EmailJS service
  static Future<bool> _sendViaEmailJS({
    required String teacherName,
    required String teacherEmail,
    required String teacherPassword,
  }) async {
    try {
      final emailData = {
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'template_params': {
          'to_email': teacherEmail,
          'from_name': 'CodeQuest Admin',
          'subject': 'Welcome to CodeQuest - Your Teacher Account',
          'message':
              _generateEmailBody(teacherName, teacherEmail, teacherPassword),
          'teacher_name': teacherName,
        }
      };

      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(emailData),
      );

      if (response.statusCode == 200) {
        print('✅ Email sent successfully to: $teacherEmail');
        return true;
      } else {
        print(
            '❌ Email sending failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ EmailJS error: $e');
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
