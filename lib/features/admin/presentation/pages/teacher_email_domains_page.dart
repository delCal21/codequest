import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/services/teacher_email_validation_service.dart';

class TeacherEmailDomainsPage extends StatefulWidget {
  const TeacherEmailDomainsPage({super.key});

  @override
  State<TeacherEmailDomainsPage> createState() =>
      _TeacherEmailDomainsPageState();
}

class _TeacherEmailDomainsPageState extends State<TeacherEmailDomainsPage> {
  final _formKey = GlobalKey<FormState>();
  final _domainController = TextEditingController();
  bool _isLoading = false;
  List<String> _customDomains = [];

  @override
  void initState() {
    super.initState();
    _loadCustomDomains();
  }

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomDomains() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('teacher_email_domains')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _customDomains = List<String>.from(data['custom_domains'] ?? []);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading domains: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addDomain() async {
    if (!_formKey.currentState!.validate()) return;

    final domain = _domainController.text.trim().toLowerCase();
    if (_customDomains.contains(domain)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Domain already exists')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      _customDomains.add(domain);
      await FirebaseFirestore.instance
          .collection('config')
          .doc('teacher_email_domains')
          .set({
        'custom_domains': _customDomains,
        'updated_at': FieldValue.serverTimestamp(),
      });

      _domainController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Domain $domain added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding domain: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeDomain(String domain) async {
    setState(() => _isLoading = true);
    try {
      _customDomains.remove(domain);
      await FirebaseFirestore.instance
          .collection('config')
          .doc('teacher_email_domains')
          .set({
        'custom_domains': _customDomains,
        'updated_at': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Domain $domain removed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing domain: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Email Domains'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Teacher Email Domain Configuration',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            TeacherEmailValidationService
                                .getValidationMessage(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add Custom Domain',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _domainController,
                              decoration: const InputDecoration(
                                labelText: 'Domain (e.g., example.com)',
                                border: OutlineInputBorder(),
                                helperText: 'Enter domain without @ symbol',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a domain';
                                }
                                if (value.contains('@')) {
                                  return 'Please enter domain without @ symbol';
                                }
                                if (!RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                                    .hasMatch(value)) {
                                  return 'Please enter a valid domain';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _addDomain,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Domain'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Default Allowed Domains',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TeacherEmailValidationService.getAllowedDomains()
                        .where((domain) => !_customDomains.contains(domain))
                        .map((domain) => Chip(
                              label: Text(domain),
                              backgroundColor: Colors.blue[100],
                              deleteIcon: null,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Custom Domains',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_customDomains.isEmpty)
                    Text(
                      'No custom domains added yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _customDomains
                          .map((domain) => Chip(
                                label: Text(domain),
                                backgroundColor: Colors.green[100],
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () => _removeDomain(domain),
                              ))
                          .toList(),
                    ),
                ],
              ),
            ),
    );
  }
}
