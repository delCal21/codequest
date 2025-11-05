import 'dart:typed_data';

class WordCertificateGenerator {
  /// Generate a Word-compatible certificate as RTF (Rich Text Format)
  static Uint8List generateWordCertificate({
    required String studentName,
    required String courseName,
    required String certificateId,
    required DateTime completionDate,
    String? teacherName,
  }) {
    final rtfContent = _generateRTFContent(
      studentName: studentName,
      courseName: courseName,
      certificateId: certificateId,
      completionDate: completionDate,
      teacherName: teacherName,
    );

    return Uint8List.fromList(rtfContent.codeUnits);
  }

  /// Generate RTF content for Word compatibility
  static String _generateRTFContent({
    required String studentName,
    required String courseName,
    required String certificateId,
    required DateTime completionDate,
    String? teacherName,
  }) {
    // Debug logging
    print('=== WordCertificateGenerator RTF Debug ===');
    print('Student Name: $studentName');
    print('Course Name: $courseName');
    print('Teacher Name: $teacherName');
    print('Teacher Name is null: ${teacherName == null}');
    print('Teacher Name isEmpty: ${teacherName?.isEmpty ?? true}');

    final completionDateStr = completionDate.toLocal().toString().split(' ')[0];
    final issueDateStr = DateTime.now().toLocal().toString().split(' ')[0];

    return '''{\\rtf1\\ansi\\deff0 {\\fonttbl {\\f0 Times New Roman;}}
{\\colortbl;\\red0\\green0\\blue0;\\red0\\green0\\blue255;\\red255\\green0\\blue0;\\red128\\green0\\blue128;\\red255\\green255\\blue0;}

\\par\\pard\\qc\\f0\\fs20\\b
CodeQuest Learning Platform
\\par\\par

\\pard\\qc\\f0\\fs32\\b\\cf5
Certificate of Completion
\\par\\par\\par

\\pard\\qc\\f0\\fs18\\cf0
This is to certify that
\\par\\par

\\pard\\qc\\f0\\fs24\\b\\cf1\\ul
$studentName
\\par\\par

\\pard\\qc\\f0\\fs18
has successfully completed the course
\\par\\par

\\pard\\qc\\f0\\fs22\\b\\cf4
$courseName
\\par\\par\\par

\\pard\\qc\\f0\\fs16
Completion Date: $completionDateStr
\\par
Certificate ID: $certificateId
\\par\\par

\\pard\\qc\\f0\\fs18\\b\\cf1
Instructor: ${teacherName ?? 'CodeQuest Platform'}
\\par\\par

\\pard\\qc\\f0\\fs14
This certificate is issued by CodeQuest Learning Platform and verifies
\\par
the successful completion of all course requirements and assessments.
\\par\\par\\par

\\pard\\qc\\f0\\fs16
Date Issued: $issueDateStr
\\par\\par\\par

\\pard\\qc\\f0\\fs12
For verification, scan the QR code or visit:
\\par
https://codequest-a5317.firebasestorage.app/certificates/$certificateId/certificate.pdf
\\par\\par

\\pard\\qc\\f0\\fs10
\\b Note: \\b0 This certificate can be edited in Microsoft Word or any compatible word processor.
\\par
You can modify the content, add additional information, or change formatting as needed.
}''';
  }

  /// Generate a simple text certificate that can be opened in Word
  static Uint8List generateTextCertificate({
    required String studentName,
    required String courseName,
    required String certificateId,
    required DateTime completionDate,
    String? teacherName,
  }) {
    final textContent = _generateTextContent(
      studentName: studentName,
      courseName: courseName,
      certificateId: certificateId,
      completionDate: completionDate,
      teacherName: teacherName,
    );

    return Uint8List.fromList(textContent.codeUnits);
  }

  /// Generate plain text content
  static String _generateTextContent({
    required String studentName,
    required String courseName,
    required String certificateId,
    required DateTime completionDate,
    String? teacherName,
  }) {
    // Debug logging
    print('=== WordCertificateGenerator Text Debug ===');
    print('Student Name: $studentName');
    print('Course Name: $courseName');
    print('Teacher Name: $teacherName');
    print('Teacher Name is null: ${teacherName == null}');
    print('Teacher Name isEmpty: ${teacherName?.isEmpty ?? true}');

    final completionDateStr = completionDate.toLocal().toString().split(' ')[0];
    final issueDateStr = DateTime.now().toLocal().toString().split(' ')[0];

    return '''
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                    🏆 CERTIFICATE OF COMPLETION 🏆                          ║
║                                                                              ║
║                           CodeQuest Learning Platform                       ║
║                                                                              ║
║  This is to certify that                                                    ║
║                                                                              ║
║  ┌────────────────────────────────────────────────────────────────────────┐ ║
║  │                    $studentName                    │ ║
║  └────────────────────────────────────────────────────────────────────────┘ ║
║                                                                              ║
║  has successfully completed the course                                      ║
║                                                                              ║
║  ┌────────────────────────────────────────────────────────────────────────┐ ║
║  │                    $courseName                    │ ║
║  └────────────────────────────────────────────────────────────────────────┘ ║
║                                                                              ║
║  Completion Date: $completionDateStr                                                      ║
║  Certificate ID: $certificateId                                                      ║
║                                                                              ║
║  ┌────────────────────────────────────────────────────────────────────────┐ ║
║  │  👨‍🏫 INSTRUCTOR: ${teacherName ?? 'CodeQuest Platform'}                                        │ ║
║  └────────────────────────────────────────────────────────────────────────┘ ║
║                                                                              ║
║  This certificate is issued by CodeQuest Learning Platform and verifies    ║
║  the successful completion of all course requirements and assessments.      ║
║                                                                              ║
║  ┌────────────────────────────────────────────────────────────────────────┐ ║
║  │  Date Issued: $issueDateStr                                                      │ ║
║  └────────────────────────────────────────────────────────────────────────┘ ║
║                                                                              ║
║  For verification, scan the QR code or visit:                               ║
║  https://codequest-a5317.firebasestorage.app/certificates/$certificateId/certificate.pdf ║
║                                                                              ║
║  ┌────────────────────────────────────────────────────────────────────────┐ ║
║  │  📝 EDITABLE CERTIFICATE - INSTRUCTIONS:                              │ ║
║  │                                                                        │ ║
║  │  1. Open this file in Microsoft Word, Google Docs, or any word        │ ║
║  │     processor to edit the content                                      │ ║
║  │                                                                        │ ║
║  │  2. You can modify student name, course name, dates, and add          │ ║
║  │     additional information as needed                                   │ ║
║  │                                                                        │ ║
║  │  3. Save as PDF, Word document, or any other format you prefer        │ ║
║  │                                                                        │ ║
║  │  4. Print or share the certificate as needed                           │ ║
║  └────────────────────────────────────────────────────────────────────────┘ ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
''';
  }
}
