import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmailDialog extends StatelessWidget {
  final String teacherName;
  final String teacherEmail;
  final String teacherPassword;

  const EmailDialog({
    super.key,
    required this.teacherName,
    required this.teacherEmail,
    required this.teacherPassword,
  });

  @override
  Widget build(BuildContext context) {
    final emailContent = _generateEmailContent();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.email, color: Colors.blue[600]),
          const SizedBox(width: 8),
          const Text('Send Welcome Email'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Copy the email content below and send it to the teacher:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'To: $teacherEmail',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: emailContent));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Email content copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        tooltip: 'Copy email content',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Subject: Welcome to CodeQuest - Your Teacher Account',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('Body:'),
                  const SizedBox(height: 4),
                  SelectableText(
                    emailContent,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
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
                  Icon(Icons.info, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Copy the email content and send it manually to the teacher via your email client.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: emailContent));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email content copied to clipboard!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy & Close'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  String _generateEmailContent() {
    return '''Dear $teacherName,

Welcome to CodeQuest! Your teacher account has been created by the administrator.

Your login credentials:
Email: $teacherEmail
Password: $teacherPassword

Please log in to the CodeQuest system and change your password for security.

Best regards,
CodeQuest Administration Team''';
  }
}
