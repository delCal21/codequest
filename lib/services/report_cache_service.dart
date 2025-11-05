import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class ReportCacheService {
  static final ReportCacheService _instance = ReportCacheService._internal();
  factory ReportCacheService() => _instance;
  ReportCacheService._internal();

  // Cache for storing generated reports
  final Map<String, _CachedReport> _cache = {};
  
  // Cache configuration
  static const int maxCacheSize = 10; // Maximum number of cached reports
  static const Duration cacheExpiry = Duration(hours: 1); // Cache expires after 1 hour

  /// Generate a cache key based on report parameters
  String generateCacheKey({
    required String reportType,
    required Map<String, dynamic> filters,
    required int dataVersion, // Use timestamp or version number
  }) {
    final keyData = {
      'type': reportType,
      'filters': filters,
      'version': dataVersion,
    };
    return keyData.toString().hashCode.toString();
  }

  /// Get cached report if available and not expired
  Uint8List? getCachedReport(String cacheKey) {
    final cached = _cache[cacheKey];
    if (cached == null) return null;

    // Check if cache is expired
    if (DateTime.now().difference(cached.timestamp) > cacheExpiry) {
      _cache.remove(cacheKey);
      return null;
    }

    return cached.data;
  }

  /// Cache a generated report
  void cacheReport(String cacheKey, Uint8List data) {
    // Remove oldest entries if cache is full
    if (_cache.length >= maxCacheSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }

    _cache[cacheKey] = _CachedReport(
      data: data,
      timestamp: DateTime.now(),
    );
  }

  /// Clear all cached reports
  void clearCache() {
    _cache.clear();
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'size': _cache.length,
      'maxSize': maxCacheSize,
      'keys': _cache.keys.toList(),
    };
  }
}

class _CachedReport {
  final Uint8List data;
  final DateTime timestamp;

  _CachedReport({
    required this.data,
    required this.timestamp,
  });
}
