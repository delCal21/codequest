import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class JDoodleService {
  // IMPORTANT: Replace with your actual JDoodle Client ID and Client Secret
  // You can get these from your JDoodle account dashboard: https://www.jdoodle.com/compiler-api
  static const String _clientId = 'f87072d962e576eb73b5b3fff4b4dcd6';
  static const String _clientSecret =
      '3ddd18797f1f5bd9fdcb43d76296660fb1dee99a26cc4737a9a2397834073687';
  static const String _baseUrl = 'https://api.jdoodle.com/v1';

  // Rate limiting configuration
  static const int _maxRequestsPerDay =
      200; // Adjust based on your JDoodle plan
  static const int _maxRequestsPerMinute = 10; // Prevent spam
  static const Duration _cacheExpiry =
      Duration(hours: 24); // Cache results for 24 hours

  // Cache for storing execution results
  final Map<String, Map<String, dynamic>> _memoryCache = {};

  // Track daily usage
  int _dailyRequestCount = 0;
  DateTime? _lastRequestDate;

  // Track minute usage for rate limiting
  final List<DateTime> _recentRequests = [];

  Future<Map<String, dynamic>> executeCode({
    required String script,
    required String language,
    String? stdin,
    String? versionIndex,
  }) async {
    // Check rate limits
    if (!_canMakeRequest()) {
      return {
        'error': 'Rate limit exceeded. Please try again later.',
        'details': 'Daily or minute limit reached'
      };
    }

    // Create cache key
    final cacheKey = _generateCacheKey(script, language, stdin, versionIndex);

    // Check cache first
    final cachedResult = await _getCachedResult(cacheKey);
    if (cachedResult != null) {
      print('Returning cached result for code execution');
      return cachedResult;
    }

    // Check memory cache
    if (_memoryCache.containsKey(cacheKey)) {
      final cached = _memoryCache[cacheKey]!;
      if (DateTime.now().difference(cached['timestamp'] as DateTime) <
          _cacheExpiry) {
        print('Returning memory cached result for code execution');
        return cached['result'] as Map<String, dynamic>;
      } else {
        _memoryCache.remove(cacheKey);
      }
    }

    // Track request
    _trackRequest();

    final url = Uri.parse('$_baseUrl/execute');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'clientId': _clientId,
      'clientSecret': _clientSecret,
      'script': script,
      'language': language,
      'stdin': stdin ?? '',
      'versionIndex': versionIndex ?? '0', // Default to latest version
    });

    try {
      print('Sending code to JDoodle for execution...');
      print('Language: $language, VersionIndex: ${versionIndex ?? '0'}');
      print(
          'Script preview: ${script.substring(0, script.length > 100 ? 100 : script.length)}...');

      final response = await http.post(url, headers: headers, body: body);

      print('JDoodle API Response Status: ${response.statusCode}');
      print('JDoodle API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Cache the result
        await _cacheResult(cacheKey, responseData);

        return responseData;
      } else if (response.statusCode == 429) {
        // Rate limit exceeded
        return {
          'error': 'JDoodle rate limit exceeded. Please try again later.',
          'details': 'API quota exceeded'
        };
      } else {
        // Handle other API errors
        print(
            'JDoodle API Error: ${response.statusCode} - ${response.body.toString()}');
        return {
          'error': 'JDoodle API Error: ${response.statusCode}',
          'details': response.body
        };
      }
    } catch (e) {
      print('Error executing code with JDoodle: ' + e.toString());
      return {'error': 'Network or unexpected error', 'details': e.toString()};
    }
  }

  // Check if we can make a request based on rate limits
  bool _canMakeRequest() {
    final now = DateTime.now();

    // Check daily limit
    if (_lastRequestDate == null ||
        now.difference(_lastRequestDate!).inDays >= 1) {
      _dailyRequestCount = 0;
      _lastRequestDate = now;
    }

    if (_dailyRequestCount >= _maxRequestsPerDay) {
      print('Daily limit reached: $_dailyRequestCount/$_maxRequestsPerDay');
      return false;
    }

    // Check minute limit
    _recentRequests.removeWhere((time) => now.difference(time).inMinutes >= 1);

    if (_recentRequests.length >= _maxRequestsPerMinute) {
      print(
          'Minute limit reached: ${_recentRequests.length}/$_maxRequestsPerMinute');
      return false;
    }

    return true;
  }

  // Track a request
  void _trackRequest() {
    _dailyRequestCount++;
    _recentRequests.add(DateTime.now());
    print('Request tracked. Daily: $_dailyRequestCount/$_maxRequestsPerDay');
  }

  // Generate cache key
  String _generateCacheKey(
      String script, String language, String? stdin, String? versionIndex) {
    final data = '$script|$language|${stdin ?? ""}|${versionIndex ?? "0"}';
    return base64Encode(utf8.encode(data));
  }

  // Get cached result from SharedPreferences
  Future<Map<String, dynamic>?> _getCachedResult(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('jdoodle_cache_$cacheKey');

      if (cachedData != null) {
        final decoded = jsonDecode(cachedData);
        final timestamp = DateTime.parse(decoded['timestamp']);

        if (DateTime.now().difference(timestamp) < _cacheExpiry) {
          return decoded['result'] as Map<String, dynamic>;
        } else {
          // Remove expired cache
          await prefs.remove('jdoodle_cache_$cacheKey');
        }
      }
    } catch (e) {
      print('Error reading cache: $e');
    }

    return null;
  }

  // Cache result in SharedPreferences
  Future<void> _cacheResult(
      String cacheKey, Map<String, dynamic> result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'result': result,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await prefs.setString('jdoodle_cache_$cacheKey', jsonEncode(cacheData));

      // Also cache in memory
      _memoryCache[cacheKey] = cacheData;

      print('Result cached successfully');
    } catch (e) {
      print('Error caching result: $e');
    }
  }

  // Get current usage statistics
  Map<String, dynamic> getUsageStats() {
    return {
      'dailyRequests': _dailyRequestCount,
      'dailyLimit': _maxRequestsPerDay,
      'recentRequests': _recentRequests.length,
      'minuteLimit': _maxRequestsPerMinute,
      'remainingDaily': _maxRequestsPerDay - _dailyRequestCount,
      'remainingMinute': _maxRequestsPerMinute - _recentRequests.length,
    };
  }

  // Clear cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (final key in keys) {
        if (key.startsWith('jdoodle_cache_')) {
          await prefs.remove(key);
        }
      }

      _memoryCache.clear();
      print('JDoodle cache cleared');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Reset daily counter (useful for testing or manual reset)
  void resetDailyCounter() {
    _dailyRequestCount = 0;
    _lastRequestDate = null;
    print('Daily counter reset');
  }
}
