import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CodeQuest Terms of Service',
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
              '1. Acceptance of Terms',
              [
                'By accessing and using CodeQuest, you accept and agree to be bound by the terms and provision of this agreement.',
                'If you do not agree to abide by the above, please do not use this service.',
              ],
            ),
            _buildSection(
              '2. Use License',
              [
                'Permission is granted to temporarily use CodeQuest for personal, non-commercial educational purposes.',
                'This is the grant of a license, not a transfer of title, and under this license you may not:',
                '• Modify or copy the materials',
                '• Use the materials for any commercial purpose or for any public display',
                '• Attempt to reverse engineer any software contained on the platform',
                '• Remove any copyright or other proprietary notations from the materials',
              ],
            ),
            _buildSection(
              '3. User Accounts',
              [
                'You are responsible for:',
                '• Maintaining the confidentiality of your account credentials',
                '• All activities that occur under your account',
                '• Providing accurate and complete information during registration',
                '• Notifying us immediately of any unauthorized use of your account',
                '• Ensuring your account information remains current and accurate',
              ],
            ),
            _buildSection(
              '4. Acceptable Use',
              [
                'You agree to use CodeQuest only for lawful purposes and in accordance with these Terms.',
                'You agree not to:',
                '• Violate any applicable laws or regulations',
                '• Transmit any harmful, threatening, or offensive content',
                '• Attempt to gain unauthorized access to any part of the platform',
                '• Interfere with or disrupt the platform or servers',
                '• Use automated systems to access the platform without permission',
                '• Share your account credentials with others',
              ],
            ),
            _buildSection(
              '5. Educational Content',
              [
                'All educational content, including courses, materials, and assessments, is provided for educational purposes only.',
                'You may not:',
                '• Copy, distribute, or share course materials without permission',
                '• Use content for commercial purposes',
                '• Submit work that is not your own (academic integrity)',
                '• Attempt to cheat or circumvent security measures',
              ],
            ),
            _buildSection(
              '6. Intellectual Property',
              [
                'The service and its original content, features, and functionality are owned by CodeQuest and are protected by international copyright, trademark, and other intellectual property laws.',
                'You may not use our trademarks, logos, or other proprietary information without our written consent.',
              ],
            ),
            _buildSection(
              '7. Privacy',
              [
                'Your privacy is important to us. Please review our Privacy Policy, which also governs your use of the service.',
                'By using our service, you consent to the collection and use of information in accordance with our Privacy Policy.',
              ],
            ),
            _buildSection(
              '8. Termination',
              [
                'We may terminate or suspend your account immediately, without prior notice, for conduct that we believe violates these Terms or is harmful to other users, us, or third parties.',
                'Upon termination, your right to use the service will cease immediately.',
              ],
            ),
            _buildSection(
              '9. Disclaimer',
              [
                'The information on this platform is provided on an "as is" basis.',
                'To the fullest extent permitted by law, CodeQuest excludes all representations, warranties, conditions and terms relating to our platform and the use of this platform.',
              ],
            ),
            _buildSection(
              '10. Limitation of Liability',
              [
                'In no event shall CodeQuest, nor its directors, employees, partners, agents, suppliers, or affiliates, be liable for any indirect, incidental, special, consequential, or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses, resulting from your use of the service.',
              ],
            ),
            _buildSection(
              '11. Governing Law',
              [
                'These Terms shall be interpreted and governed by the laws of the jurisdiction in which CodeQuest operates.',
                'Any disputes arising from these Terms will be subject to the exclusive jurisdiction of the courts in that jurisdiction.',
              ],
            ),
            _buildSection(
              '12. Changes to Terms',
              [
                'We reserve the right, at our sole discretion, to modify or replace these Terms at any time.',
                'If a revision is material, we will try to provide at least 30 days notice prior to any new terms taking effect.',
                'Your continued use of the service after any such changes constitutes your acceptance of the new Terms.',
              ],
            ),
            _buildSection(
              '13. Contact Information',
              [
                'If you have any questions about these Terms of Service, please contact us at:',
                'Email: legal@codequest.edu',
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
                child: const Text('I Agree'),
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
