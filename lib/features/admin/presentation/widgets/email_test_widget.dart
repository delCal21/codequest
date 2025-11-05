import 'package:flutter/material.dart';
import 'package:codequest/services/real_email_service.dart';

class EmailTestWidget extends StatefulWidget {
  const EmailTestWidget({super.key});

  @override
  State<EmailTestWidget> createState() => _EmailTestWidgetState();
}

class _EmailTestWidgetState extends State<EmailTestWidget> {
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  Future<void> _testEmailConfiguration() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {
      final success = await RealEmailService.testEmailService();

      setState(() {
        _testSuccess = success;
        _testResult = success
            ? 'Test email sent successfully! Check your email inbox.'
            : 'Email service test failed.';
      });
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = 'Error testing email: $e';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.email,
                  color: Colors.blue[600],
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Email Configuration Test',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Test the Gmail email notification system by sending a real email to your Gmail inbox.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isTesting ? null : _testEmailConfiguration,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_isTesting ? 'Sending...' : 'Send Gmail Test Email'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      _testSuccess == true ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testSuccess == true
                        ? Colors.green[300]!
                        : Colors.red[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _testSuccess == true ? Icons.check_circle : Icons.error,
                      color: _testSuccess == true
                          ? Colors.green[600]
                          : Colors.red[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          color: _testSuccess == true
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange[600], size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Email Configuration Required',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Email service is now configured and ready!',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '✅ Service ID: service_3wnmqqm\n✅ Template ID: template_md2nhco\n✅ Public Key: Z7zKku6N2zYHp1Zhu',
                    style: TextStyle(
                      fontSize: 11,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
