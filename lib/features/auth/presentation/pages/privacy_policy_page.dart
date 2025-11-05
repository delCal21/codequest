import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CodeQuest Privacy Policy',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Last updated: ${DateTime.now().toString().split(' ')[0]}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Information We Collect',
              [
                'We collect information you provide directly to us, such as when you create an account, register for courses, or contact us for support.',
                'Personal information may include:',
                '• Name and email address',
                '• Educational institution affiliation',
                '• Course enrollment and progress data',
                '• Communication preferences',
                '• Profile information and preferences',
              ],
            ),
            _buildSection(
              '2. How We Use Your Information',
              [
                'We use the information we collect to:',
                '• Provide, maintain, and improve our educational services',
                '• Process your course enrollments and track your progress',
                '• Send you important updates about your courses and account',
                '• Respond to your comments, questions, and requests',
                '• Monitor and analyze usage patterns to improve our platform',
                '• Ensure the security and integrity of our services',
              ],
            ),
            _buildSection(
              '3. Information Sharing',
              [
                'We do not sell, trade, or otherwise transfer your personal information to third parties without your consent, except:',
                '• With your educational institution for academic purposes',
                '• With service providers who assist us in operating our platform',
                '• When required by law or to protect our rights and safety',
                '• In connection with a business transfer or acquisition',
              ],
            ),
            _buildSection(
              '4. Data Security',
              [
                'We implement appropriate security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.',
                '• All data is encrypted in transit and at rest',
                '• Access to personal information is restricted to authorized personnel',
                '• Regular security audits and updates are performed',
                '• We use industry-standard security protocols and practices',
              ],
            ),
            _buildSection(
              '5. Your Rights',
              [
                'You have the right to:',
                '• Access and update your personal information',
                '• Request deletion of your account and associated data',
                '• Opt out of certain communications',
                '• Request a copy of your data',
                '• Withdraw consent for data processing',
              ],
            ),
            _buildSection(
              '6. Cookies and Tracking',
              [
                'We use cookies and similar technologies to:',
                '• Remember your preferences and settings',
                '• Analyze how you use our platform',
                '• Provide personalized content and features',
                '• Improve our services and user experience',
              ],
            ),
            _buildSection(
              '7. Children\'s Privacy',
              [
                'Our services are designed for educational use and may be used by students under 18.',
                'We comply with applicable laws regarding children\'s privacy, including COPPA.',
                'If you are under 18, please ensure you have parental consent before using our services.',
              ],
            ),
            _buildSection(
              '8. Changes to This Policy',
              [
                'We may update this privacy policy from time to time.',
                'We will notify you of any material changes by posting the new policy on this page.',
                'Your continued use of our services after changes constitutes acceptance of the updated policy.',
              ],
            ),
            _buildSection(
              '9. Contact Us',
              [
                'If you have any questions about this privacy policy, please contact us at:',
                'Email: privacy@codequest.edu',
                'Address: CodeQuest Educational Platform',
                'We will respond to your inquiry within 5 business days.',
              ],
            ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('I Understand'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 12),
          ...content.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
