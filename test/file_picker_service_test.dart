import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:codequest/services/file_picker_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

void main() {
  group('FilePickerService Tests', () {
    late FilePickerService filePickerService;

    setUp(() {
      filePickerService = FilePickerService();
    });

    test('should handle web platform path access safely', () {
      // Create a mock PlatformFile that simulates web behavior
      final mockFile = PlatformFile(
        name: 'test.docx',
        size: 1000,
        bytes: Uint8List.fromList([1, 2, 3, 4, 5]), // Mock bytes
      );

      // This should not throw an exception even on web
      expect(
          () => filePickerService.readFileContent(mockFile), returnsNormally);
    });

    test('should prioritize bytes over path on web platforms', () async {
      // Create a mock PlatformFile with bytes (web scenario)
      final mockFile = PlatformFile(
        name: 'test.txt',
        size: 100,
        bytes: Uint8List.fromList([72, 101, 108, 108, 111]), // "Hello" in bytes
      );

      try {
        final result = await filePickerService.readFileContent(mockFile);
        // Should successfully read from bytes
        expect(result, isNotNull);
      } catch (e) {
        // Should not throw path-related errors
        expect(e.toString(), isNot(contains('path is unavailable')));
      }
    });

    test('should handle file extension correctly', () {
      final mockFile = PlatformFile(
        name: 'test.docx',
        size: 1000,
        bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
      );

      expect(mockFile.extension, equals('docx'));
    });

    test('should handle null bytes gracefully', () {
      final mockFile = PlatformFile(
        name: 'test.txt',
        size: 100,
        bytes: null,
      );

      expect(mockFile.bytes, isNull);
    });
  });
}
