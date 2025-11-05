import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'word_certificate_generator.dart';

class CertificateStorageService {
  static const String _bucketName = 'codequest-a5317.firebasestorage.app';

  /// Upload certificate files to Firebase Storage
  static Future<Map<String, String>> uploadCertificateFiles({
    required String certificateId,
    required String studentName,
    required String courseName,
    required Uint8List pdfBytes,
    required Uint8List textBytes,
    required Uint8List wordBytes,
  }) async {
    try {
      final storage = FirebaseStorage.instanceFor(bucket: _bucketName);
      final certificatesRef =
          storage.ref().child('certificates/$certificateId');

      // Upload PDF certificate
      final pdfRef = certificatesRef.child('certificate.pdf');
      final pdfMetadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'studentName': studentName,
          'courseName': courseName,
          'certificateId': certificateId,
          'type': 'pdf',
          'uploadTime': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      final pdfUploadTask = pdfRef.putData(pdfBytes, pdfMetadata);
      final pdfSnapshot = await pdfUploadTask;
      final pdfUrl = await pdfSnapshot.ref.getDownloadURL();

      // Upload text certificate
      final textRef = certificatesRef.child('certificate.txt');
      final textMetadata = SettableMetadata(
        contentType: 'text/plain',
        customMetadata: {
          'studentName': studentName,
          'courseName': courseName,
          'certificateId': certificateId,
          'type': 'text',
          'uploadTime': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      final textUploadTask = textRef.putData(textBytes, textMetadata);
      final textSnapshot = await textUploadTask;
      final textUrl = await textSnapshot.ref.getDownloadURL();

      // Upload Word certificate
      final wordRef = certificatesRef.child('certificate.docx');
      final wordMetadata = SettableMetadata(
        contentType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        customMetadata: {
          'studentName': studentName,
          'courseName': courseName,
          'certificateId': certificateId,
          'type': 'word',
          'uploadTime': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      final wordUploadTask = wordRef.putData(wordBytes, wordMetadata);
      final wordSnapshot = await wordUploadTask;
      final wordUrl = await wordSnapshot.ref.getDownloadURL();

      // Store certificate metadata in Firestore
      await _storeCertificateMetadata(
        certificateId: certificateId,
        studentName: studentName,
        courseName: courseName,
        pdfUrl: pdfUrl,
        textUrl: textUrl,
        wordUrl: wordUrl,
      );

      return {
        'pdf': pdfUrl,
        'text': textUrl,
        'word': wordUrl,
      };
    } catch (e) {
      print('Error uploading certificate files: $e');
      rethrow;
    }
  }

  /// Store certificate metadata in Firestore
  static Future<void> _storeCertificateMetadata({
    required String certificateId,
    required String studentName,
    required String courseName,
    required String pdfUrl,
    required String textUrl,
    required String wordUrl,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;

      await firestore.collection('certificates').doc(certificateId).set({
        'certificateId': certificateId,
        'studentName': studentName,
        'courseName': courseName,
        'pdfUrl': pdfUrl,
        'textUrl': textUrl,
        'wordUrl': wordUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user?.uid,
        'createdByEmail': user?.email,
        'isActive': true,
      });

      print('Certificate metadata stored in Firestore');
    } catch (e) {
      print('Error storing certificate metadata: $e');
      rethrow;
    }
  }

  /// Get certificate download URLs by certificate ID
  static Future<Map<String, String>?> getCertificateUrls(
      String certificateId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final doc =
          await firestore.collection('certificates').doc(certificateId).get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'pdf': data['pdfUrl'] ?? '',
          'text': data['textUrl'] ?? '',
          'word': data['wordUrl'] ?? '',
          'studentName': data['studentName'] ?? '',
          'courseName': data['courseName'] ?? '',
        };
      }

      return null;
    } catch (e) {
      print('Error getting certificate URLs: $e');
      return null;
    }
  }

  /// Generate certificate content in different formats
  static Map<String, Uint8List> generateCertificateContent({
    required String studentName,
    required String courseName,
    required String certificateId,
    required DateTime completionDate,
    String? teacherName,
  }) {
    // Debug logging
    print('=== CertificateStorageService Debug ===');
    print('Student Name: $studentName');
    print('Course Name: $courseName');
    print('Teacher Name: $teacherName');
    print('Teacher Name is null: ${teacherName == null}');
    print('Teacher Name isEmpty: ${teacherName?.isEmpty ?? true}');

    // Generate text content
    final textContent = WordCertificateGenerator.generateTextCertificate(
      studentName: studentName,
      courseName: courseName,
      certificateId: certificateId,
      completionDate: completionDate,
      teacherName: teacherName,
    );

    // Generate Word content (RTF format for Word compatibility)
    final wordContent = WordCertificateGenerator.generateWordCertificate(
      studentName: studentName,
      courseName: courseName,
      certificateId: certificateId,
      completionDate: completionDate,
      teacherName: teacherName,
    );

    return {
      'text': textContent,
      'word': wordContent,
    };
  }

  /// Delete certificate files from Firebase Storage
  static Future<void> deleteCertificate(String certificateId) async {
    try {
      final storage = FirebaseStorage.instanceFor(bucket: _bucketName);
      final certificatesRef =
          storage.ref().child('certificates/$certificateId');

      // Delete all files in the certificate folder
      final listResult = await certificatesRef.listAll();
      for (final item in listResult.items) {
        await item.delete();
      }

      // Delete certificate metadata from Firestore
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('certificates').doc(certificateId).delete();

      print('Certificate deleted successfully');
    } catch (e) {
      print('Error deleting certificate: $e');
      rethrow;
    }
  }
}
