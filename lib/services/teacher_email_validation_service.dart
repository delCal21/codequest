import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherEmailValidationService {
  static const List<String> _defaultAllowedDomains = [
    'edu', // Educational institutions
    'ac', // Academic institutions
    'school', // Schools
    'university', // Universities
    'college', // Colleges
    'institute', // Institutes
    'academy', // Academies
    'gov', // Government institutions
    'org', // Non-profit organizations
  ];

  static const List<String> _specificAllowedDomains = [
    'gmail.com', // Allow Gmail for testing/demo purposes
    'outlook.com', // Allow Outlook for testing/demo purposes
    'yahoo.com', // Allow Yahoo for testing/demo purposes
  ];

  static List<String> _customDomains = [];
  static bool _domainsLoaded = false;

  /// Validates if an email is suitable for teacher registration
  static bool isValidTeacherEmail(String email) {
    if (email.isEmpty) return false;

    // Basic email format validation
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) return false;

    // Extract domain
    final domain = email.split('@').last.toLowerCase();

    // Check against specific allowed domains
    if (_specificAllowedDomains.contains(domain)) {
      return true;
    }

    // Check against custom domains
    if (_customDomains.contains(domain)) {
      return true;
    }

    // Check against educational domain patterns
    for (final allowedDomain in _defaultAllowedDomains) {
      if (domain.endsWith('.$allowedDomain') || domain == allowedDomain) {
        return true;
      }
    }

    return false;
  }

  /// Gets the list of allowed domains for teacher emails
  static List<String> getAllowedDomains() {
    return [
      ..._specificAllowedDomains,
      ..._customDomains,
      ..._defaultAllowedDomains
    ];
  }

  /// Loads custom domains from Firestore
  static Future<void> loadCustomDomains() async {
    if (_domainsLoaded) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('teacher_email_domains')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _customDomains = List<String>.from(data['custom_domains'] ?? []);
      }
      _domainsLoaded = true;
    } catch (e) {
      print('Error loading custom domains: $e');
      _domainsLoaded = true; // Mark as loaded to prevent infinite retries
    }
  }

  /// Refreshes custom domains from Firestore
  static Future<void> refreshCustomDomains() async {
    _domainsLoaded = false;
    await loadCustomDomains();
  }

  /// Gets a user-friendly message explaining the email requirements
  static String getValidationMessage() {
    return 'Teacher emails must be from an educational institution or approved domain. '
        'Examples: .edu, .ac, .school, .university, .college, .institute, .academy, .gov, .org, '
        'or approved domains like gmail.com, outlook.com, yahoo.com';
  }

  /// Gets a short validation message for form fields
  static String getShortValidationMessage() {
    return 'Please use an educational institution email or approved domain';
  }

  /// Validates teacher email and returns detailed error message if invalid
  static Future<String?> validateTeacherEmail(String email) async {
    if (email.isEmpty) {
      return 'Email is required';
    }

    // Basic email format validation
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    // Load custom domains if not loaded
    await loadCustomDomains();

    // Check if it's a valid teacher email
    if (!isValidTeacherEmail(email)) {
      return getShortValidationMessage();
    }

    return null; // Email is valid
  }

  /// Synchronous version for backward compatibility
  static String? validateTeacherEmailSync(String email) {
    if (email.isEmpty) {
      return 'Email is required';
    }

    // Basic email format validation
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    // Check if it's a valid teacher email (without custom domains)
    if (!isValidTeacherEmail(email)) {
      return getShortValidationMessage();
    }

    return null; // Email is valid
  }

  /// Checks if a domain is specifically allowed (for admin configuration)
  static bool isDomainAllowed(String domain) {
    final normalizedDomain = domain.toLowerCase();
    return _specificAllowedDomains.contains(normalizedDomain) ||
        _defaultAllowedDomains.any((allowed) =>
            normalizedDomain.endsWith('.$allowed') ||
            normalizedDomain == allowed);
  }

  /// Adds a new allowed domain (for admin configuration)
  static void addAllowedDomain(String domain) {
    final normalizedDomain = domain.toLowerCase();
    if (!_specificAllowedDomains.contains(normalizedDomain)) {
      _specificAllowedDomains.add(normalizedDomain);
    }
  }

  /// Removes an allowed domain (for admin configuration)
  static void removeAllowedDomain(String domain) {
    final normalizedDomain = domain.toLowerCase();
    _specificAllowedDomains.remove(normalizedDomain);
  }
}
