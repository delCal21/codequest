import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import '../services/certificate_storage_service.dart';

class CertificateWidget extends StatefulWidget {
  final String studentName;
  final String courseName;
  final String? initialTeacherName;
  final bool allowDigitalSignature;
  final DateTime? completionDate;
  final String? courseAuthor;

  const CertificateWidget({
    Key? key,
    required this.studentName,
    required this.courseName,
    this.initialTeacherName,
    this.allowDigitalSignature = true,
    this.completionDate,
    this.courseAuthor,
  }) : super(key: key);

  @override
  CertificateWidgetState createState() => CertificateWidgetState();
}

class CertificateWidgetState extends State<CertificateWidget> {
  final GlobalKey _boundaryKey = GlobalKey();
  Uint8List? _signatureBytes;
  String _teacherName = '';
  String _teacherTitle = '';
  bool _signatureLocked = false;

  String _resolveInstructorName() {
    print('=== _resolveInstructorName Debug ===');
    print('_teacherName: "$_teacherName"');
    print('widget.initialTeacherName: "${widget.initialTeacherName}"');
    print('widget.courseAuthor: "${widget.courseAuthor}"');

    if (_teacherName.trim().isNotEmpty) {
      print('Using _teacherName: "$_teacherName"');
      return _teacherName.trim();
    }
    if ((widget.initialTeacherName ?? '').trim().isNotEmpty) {
      print('Using initialTeacherName: "${widget.initialTeacherName}"');
      return widget.initialTeacherName!.trim();
    }
    if ((widget.courseAuthor ?? '').trim().isNotEmpty) {
      print('Using courseAuthor: "${widget.courseAuthor}"');
      return widget.courseAuthor!.trim();
    }
    print('Using fallback: "Course Instructor"');
    return 'Course Instructor';
  }

  @override
  void initState() {
    super.initState();
    _teacherName = widget.initialTeacherName ?? '';

    // Debug: Print what we received
    print('=== CertificateWidget Debug ===');
    print('Student Name: ${widget.studentName}');
    print('Course Name: ${widget.courseName}');
    print('Initial Teacher Name: ${widget.initialTeacherName}');
    print('Course Author: ${widget.courseAuthor}');
    print('Completion Date: ${widget.completionDate}');
    print('Allow Digital Signature: ${widget.allowDigitalSignature}');
    print('_teacherName set to: $_teacherName');
    print('Resolved instructor name: ${_resolveInstructorName()}');
  }

  Future<void> _pickSignature() async {
    try {
      if (_signatureLocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signature is locked. Long-press to unlock.')),
        );
        return;
      }
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Storage permission required to add signature.')),
        );
      }
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        setState(() {
          _signatureBytes = file.bytes!;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add signature: $e')),
      );
    }
  }

  Future<void> _editTeacherInfo() async {
    final nameController = TextEditingController(text: _teacherName);
    final titleController = TextEditingController(text: _teacherTitle);
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Instructor details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title (e.g., Instructor)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _teacherName = nameController.text.trim();
                  _teacherTitle = titleController.text.trim();
                });
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> downloadCertificate(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Generating PDF certificate...'),
            ],
          ),
        ),
      );

      // Generate PDF certificate
      final pdfBytes = await _generatePDFCertificate();

      // Upload certificate to Firebase Storage
      await _uploadCertificateToFirebase(pdfBytes);

      // Close loading dialog
      Navigator.of(context).pop();

      // Request storage permission
      var status = await Permission.storage.request();
      if (status.isGranted) {
        // Save PDF to device
        final result = await _savePDFToDevice(pdfBytes);
        if (result) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF Certificate saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save PDF certificate.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission denied.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating certificate: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Uint8List> _loadAssetBytes(String assetPath) async {
    final ByteData data = await DefaultAssetBundle.of(context).load(assetPath);
    return data.buffer.asUint8List();
  }

  Future<void> _uploadCertificateToFirebase(Uint8List pdfBytes) async {
    try {
      final certificateId = _generateCertificateId();
      final completionDate = widget.completionDate ?? DateTime.now();

      // Generate certificate content in different formats
      final certificateContent =
          CertificateStorageService.generateCertificateContent(
        studentName: widget.studentName,
        courseName: widget.courseName,
        certificateId: certificateId,
        completionDate: completionDate,
        teacherName: widget.initialTeacherName,
      );

      // Upload all certificate formats to Firebase Storage
      await CertificateStorageService.uploadCertificateFiles(
        certificateId: certificateId,
        studentName: widget.studentName,
        courseName: widget.courseName,
        pdfBytes: pdfBytes,
        textBytes: certificateContent['text']!,
        wordBytes: certificateContent['word']!,
      );

      print('Certificate uploaded to Firebase Storage successfully');
    } catch (e) {
      print('Error uploading certificate to Firebase Storage: $e');
      // Don't throw error here to avoid breaking the download flow
    }
  }

  String _generateCertificateId() {
    try {
      // Sanitize inputs to prevent URL issues
      final sanitizedStudentName =
          widget.studentName.trim().replaceAll(RegExp(r'[^\w\s-]'), '');
      final sanitizedCourseName =
          widget.courseName.trim().replaceAll(RegExp(r'[^\w\s-]'), '');

      // Generate a unique certificate ID based on student name, course, and timestamp
      final certificateId =
          '${sanitizedStudentName.replaceAll(' ', '_')}_${sanitizedCourseName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';

      return certificateId;
    } catch (e) {
      print('Error generating certificate ID: $e');
      return 'error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  String _generateCertificateUrl() {
    try {
      final certificateId = _generateCertificateId();

      // Debug: Print the certificate URL being generated
      print('=== QR Code Debug ===');
      print('Original Student: ${widget.studentName}');
      print('Original Course: ${widget.courseName}');
      print('Certificate ID: $certificateId');

      // Generate a simple URL that points to the certificate verification page
      // This displays only essential verification information (Certificate ID, verification date, completion date)
      final certificateUrl =
          'https://codequest-a5317.web.app/certificate-verification.html?cert=$certificateId&debug=NEW_URL_WORKING';

      print('=== QR CODE URL GENERATION ===');
      print('Generated certificate URL: $certificateUrl');
      print('URL length: ${certificateUrl.length} characters');
      print(
          'This URL should show ONLY: Certificate ID, Verification Date, Completion Date');
      print('=== END QR CODE URL ===');

      // Validate URL length (QR codes have limits)
      if (certificateUrl.length > 2000) {
        print(
            'WARNING: URL is very long (${certificateUrl.length} chars). This might cause QR code issues.');
      }

      return certificateUrl;
    } catch (e) {
      print('Error generating certificate URL: $e');
      // Fallback URL with minimal data
      return 'https://codequest-a5317.web.app/certificate-verification.html?cert=error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<Uint8List> _generateQRCodeBytes(String data) async {
    try {
      final qrValidationResult = QrValidator.validate(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final painter = QrPainter.withQr(
          qr: qrCode,
          gapless: false,
        );

        final picData = await painter.toImageData(200);
        return picData!.buffer.asUint8List();
      }
    } catch (e) {
      print('Error generating QR code: $e');
    }

    // Fallback: return empty bytes if QR generation fails
    return Uint8List(0);
  }

  Future<Uint8List> _generatePDFCertificate() async {
    final pdf = pw.Document();
    final completionDate = widget.completionDate ?? DateTime.now();
    final date = DateFormat('yyyy-MM-dd').format(completionDate);

    // Resolve instructor name before PDF generation
    final instructorName = _resolveInstructorName();

    // Force fallback if instructor name is empty
    final finalInstructorName = instructorName.isEmpty
        ? (widget.initialTeacherName?.isNotEmpty == true
            ? widget.initialTeacherName!
            : 'Course Instructor')
        : instructorName;

    // Debug: Print instructor information
    print('=== PDF Generation Debug ===');
    print('Student: ${widget.studentName}');
    print('Course: ${widget.courseName}');
    print('Initial Teacher: ${widget.initialTeacherName}');
    print('Course Author: ${widget.courseAuthor}');
    print('Resolved Instructor: $instructorName');
    print('Final Instructor Name: $finalInstructorName');
    print('Instructor name length: ${instructorName.length}');
    print('Instructor name isEmpty: ${instructorName.isEmpty}');
    print('Final instructor text: "$finalInstructorName"');

    // Load CIS SEAL2 logo and generate QR code before PDF generation
    final codequestLogoBytes =
        await _loadAssetBytes('assets/images/CIS SEAL2.png');
    final certificateUrl = _generateCertificateUrl();
    final qrCodeBytes = await _generateQRCodeBytes(certificateUrl);

    // Final debug before PDF generation
    print('=== FINAL DEBUG BEFORE PDF ===');
    print('finalInstructorName: "$finalInstructorName"');
    print('finalInstructorName length: ${finalInstructorName.length}');
    print('finalInstructorName isEmpty: ${finalInstructorName.isEmpty}');

    // Add page with landscape orientation
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColors.amber,
                width: 3,
              ),
            ),
            padding: const pw.EdgeInsets.all(40),
            child: pw.Stack(
              children: [
                // Background watermark
                pw.Positioned(
                  right: 50,
                  bottom: 50,
                  child: pw.Opacity(
                    opacity: 0.1,
                    child: pw.Text(
                      'CodeQuest',
                      style: pw.TextStyle(
                        fontSize: 80,
                        color: PdfColors.grey,
                      ),
                    ),
                  ),
                ),
                // Main content
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Header with CIS logo, platform name, and QR code
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        // Left side - CodeQuest logo
                        pw.Image(
                          pw.MemoryImage(codequestLogoBytes),
                          height: 60,
                          fit: pw.BoxFit.contain,
                        ),
                        // Center - Platform name
                        pw.Expanded(
                          child: pw.Padding(
                            padding:
                                const pw.EdgeInsets.symmetric(horizontal: 20),
                            child: pw.Text(
                              'CodeQuest Learning Platform',
                              style: pw.TextStyle(
                                fontSize: 24,
                                color: PdfColors.grey700,
                                fontStyle: pw.FontStyle.italic,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ),
                        // Right side - QR code
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Column(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              if (qrCodeBytes.isNotEmpty)
                                pw.Image(
                                  pw.MemoryImage(qrCodeBytes),
                                  width: 40,
                                  height: 40,
                                  fit: pw.BoxFit.contain,
                                )
                              else
                                pw.Container(
                                  width: 40,
                                  height: 40,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.grey100,
                                  ),
                                  child: pw.Center(
                                    child: pw.Text(
                                      'QR',
                                      style: pw.TextStyle(
                                        fontSize: 20,
                                        color: PdfColors.grey600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 15),
                    // Certificate title
                    pw.Text(
                      'Certificate of Completion',
                      style: pw.TextStyle(
                        fontSize: 30, // reduced to ensure bottom content fits
                        color: PdfColors.amber,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 30),
                    // Certificate content
                    pw.Text(
                      'This is to certify that',
                      style: pw.TextStyle(
                        fontSize: 18,
                        color: PdfColors.grey800,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 15),
                    pw.Text(
                      widget.studentName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        color: PdfColors.blue900,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      width: 200,
                      height: 2,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue900,
                        borderRadius: pw.BorderRadius.circular(1),
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Text(
                      'has successfully completed the course',
                      style: pw.TextStyle(
                        fontSize: 18,
                        color: PdfColors.grey800,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      widget.courseName,
                      style: pw.TextStyle(
                        fontSize: 22,
                        color: PdfColors.purple700,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 15),
                    pw.Text(
                      'Completion Date: $date',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.blueGrey900,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 10),
                    // Instructor name right after completion date
                    pw.Text(
                      finalInstructorName,
                      style: pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.blue900,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 8),
                    // Line below instructor name
                    pw.Container(
                      width: 200,
                      height: 2,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue900,
                        borderRadius: pw.BorderRadius.circular(1),
                      ),
                    ),
                    pw.SizedBox(height: 30),
                    pw.Divider(thickness: 2, color: PdfColors.grey400),
                    pw.SizedBox(height: 15),
                    pw.SizedBox(height: 15),
                    pw.SizedBox(height: 15),
                    pw.Text(
                      'Congratulations on your outstanding achievement\nand dedication to learning!',
                      style: pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.grey900,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 40),
                    // Bottom area: Course Author (left) and Instructor signature (right)
                    pw.SizedBox(height: 24),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        // Course instructor/author on the left
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                finalInstructorName,
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  color: PdfColors.blueGrey900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 24),
                        // Instructor signature on the right
                        pw.Column(
                          children: [
                            pw.Container(
                              width: 180,
                              height: 50,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey400),
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Container(
                              width: 180,
                              child: pw.Divider(
                                  thickness: 1, color: PdfColors.grey600),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              finalInstructorName,
                              style: pw.TextStyle(
                                fontSize: 14,
                                color: PdfColors.grey900,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<bool> _savePDFToDevice(Uint8List pdfBytes) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'CodeQuest_Certificate_${widget.studentName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(pdfBytes);

      // Also save to gallery/documents folder
      final result = await ImageGallerySaverPlus.saveFile(
        file.path,
        name: fileName,
      );

      return result['isSuccess'] == true;
    } catch (e) {
      print('Error saving PDF: $e');
      return false;
    }
  }

  Future<void> previewPDFCertificate(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Generating PDF preview...'),
            ],
          ),
        ),
      );

      // Generate PDF certificate
      final pdfBytes = await _generatePDFCertificate();

      // Close loading dialog
      Navigator.of(context).pop();

      // Show PDF preview
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'CodeQuest Certificate - ${widget.studentName}',
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error previewing certificate: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> downloadAsImage(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Generating image certificate...'),
            ],
          ),
        ),
      );

      RenderRepaintBoundary boundary = _boundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Close loading dialog
      Navigator.of(context).pop();

      var status = await Permission.storage.request();
      if (status.isGranted) {
        final result = await ImageGallerySaverPlus.saveImage(pngBytes,
            name:
                'CodeQuest_Certificate_${widget.studentName.replaceAll(' ', '_')}');
        if (result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image certificate saved to gallery!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save image certificate.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission denied.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating image certificate: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final completionDate = widget.completionDate ?? DateTime.now();
    final date = DateFormat('yyyy-MM-dd').format(completionDate);
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive dimensions for landscape short bond paper size
    // Landscape short bond paper is 11" x 8.5" (279mm x 216mm)
    // For mobile devices, scale down proportionally
    double certificateWidth = 842; // Landscape width (11")
    double certificateHeight = 595; // Landscape height (8.5")

    if (screenWidth < 900) {
      // Scale down for smaller screens while maintaining aspect ratio
      final scale = screenWidth / 900;
      certificateWidth = 842 * scale;
      certificateHeight = 595 * scale;
    }

    return Center(
      child: RepaintBoundary(
        key: _boundaryKey,
        child: Container(
          width: certificateWidth,
          height: certificateHeight,
          constraints: BoxConstraints(
            maxWidth: certificateWidth,
            minWidth: certificateWidth,
            maxHeight: certificateHeight,
            minHeight: certificateHeight,
          ),
          padding: EdgeInsets.symmetric(
            vertical: certificateHeight * 0.05, // 5% of height
            horizontal: certificateWidth * 0.05, // 5% of width
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: Color(0xFFFFD700), width: 6), // Gold border
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Optional: Watermark or faint logo in the background
              Positioned(
                right: certificateWidth * 0.05, // 5% from right
                bottom: certificateHeight * 0.05, // 5% from bottom
                child: Opacity(
                  opacity: 0.08,
                  child: Image.asset(
                    'assets/images/CIS SEAL2.png',
                    width: certificateWidth * 0.15, // 15% of width
                    height: certificateWidth * 0.15, // 15% of width (square)
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Main content
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header with CIS logo, platform name, and QR code
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left side - CIS logo
                      Image.asset(
                        'assets/images/CIS SEAL2.png',
                        height:
                            certificateHeight * 0.08, // Responsive logo size
                        fit: BoxFit.contain,
                      ),
                      // Center - Platform name
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'CodeQuest Learning Platform',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[700],
                              fontSize: certificateHeight *
                                  0.025, // Responsive font size
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                            softWrap: true,
                            maxLines: 2,
                          ),
                        ),
                      ),
                      // Right side - QR code
                      Container(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // QR Code with error handling
                            Builder(
                              builder: (context) {
                                try {
                                  final qrData = _generateCertificateUrl();
                                  print('=== FLUTTER WIDGET QR CODE ===');
                                  print('QR Code Data: $qrData');
                                  print(
                                      'QR Code Data Length: ${qrData.length}');
                                  print(
                                      'This should point to certificate-verification.html');
                                  print('=== END FLUTTER WIDGET QR CODE ===');

                                  // Validate QR data
                                  if (qrData.isEmpty) {
                                    print('ERROR: QR data is empty!');
                                    return Container(
                                      width: certificateHeight * 0.08,
                                      height: certificateHeight * 0.08,
                                      decoration: BoxDecoration(
                                        color: Colors.red[100],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: Colors.red, width: 2),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'QR ERROR',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  return QrImageView(
                                    data: qrData,
                                    version: QrVersions.auto,
                                    size: certificateHeight * 0.08,
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    errorStateBuilder: (context, error) {
                                      print('QR Code Generation Error: $error');
                                      return Container(
                                        width: certificateHeight * 0.08,
                                        height: certificateHeight * 0.08,
                                        decoration: BoxDecoration(
                                          color: Colors.orange[100],
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: Colors.orange, width: 2),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'QR FAIL',
                                            style: TextStyle(
                                              color: Colors.orange[800],
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                } catch (e) {
                                  print('QR Code Error: $e');
                                  // Fallback: Show a placeholder
                                  return Container(
                                    width: certificateHeight * 0.08,
                                    height: certificateHeight * 0.08,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.grey[400]!, width: 1),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.qr_code,
                                          size: certificateHeight * 0.06,
                                          color: Colors.grey[600],
                                        ),
                                        Text(
                                          'QR Error',
                                          style: TextStyle(
                                            fontSize: certificateHeight * 0.02,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Certificate of Completion',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize:
                          certificateHeight * 0.04, // Responsive font size
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB8860B), // Dark gold
                      letterSpacing: 2.0,
                      fontFamily: 'Serif',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This is to certify that',
                    style: TextStyle(
                        fontSize:
                            certificateHeight * 0.022, // Responsive font size
                        color: Colors.grey[800]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.studentName,
                    style: TextStyle(
                      fontSize:
                          certificateHeight * 0.033, // Responsive font size
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                      fontFamily: 'Serif',
                      letterSpacing: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: certificateWidth * 0.4, // 40% of certificate width
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.blue[900],
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'has successfully completed the course',
                    style: TextStyle(
                        fontSize:
                            certificateHeight * 0.022, // Responsive font size
                        color: Colors.grey[800]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.courseName,
                    style: TextStyle(
                      fontSize:
                          certificateHeight * 0.026, // Responsive font size
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                      fontFamily: 'Serif',
                      letterSpacing: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Completion Date: $date',
                    style: TextStyle(
                      fontSize:
                          certificateHeight * 0.022, // Responsive font size
                      color: Colors.blueGrey[900],
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Divider(thickness: 1.5, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  // Always show teacher name if available
                  if (widget.initialTeacherName != null &&
                      widget.initialTeacherName!.isNotEmpty) ...[
                    Text(
                      'Course Instructor: ${widget.initialTeacherName}',
                      style: TextStyle(
                        fontSize:
                            certificateHeight * 0.02, // Responsive font size
                        color: Colors.grey[800],
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ] else if (widget.courseAuthor != null &&
                      widget.courseAuthor!.isNotEmpty) ...[
                    Text(
                      'Course Author: ${widget.courseAuthor}',
                      style: TextStyle(
                        fontSize:
                            certificateHeight * 0.02, // Responsive font size
                        color: Colors.grey[800],
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  // ALWAYS SHOW TEACHER NAME - FORCE DISPLAY
                  if (widget.initialTeacherName != null &&
                      widget.initialTeacherName!.isNotEmpty) ...[
                    Text(
                      'Course Instructor: ${widget.initialTeacherName}',
                      style: TextStyle(
                        fontSize: certificateHeight * 0.025,
                        color: Colors.blue[900],
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                  // RED DEBUG TEXT - ALWAYS SHOW
                  if (widget.initialTeacherName != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        border: Border.all(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'TEACHER NAME: ${widget.initialTeacherName}',
                        style: TextStyle(
                          fontSize: certificateHeight * 0.02,
                          color: Colors.red[900],
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Congratulations on your outstanding achievement\nand dedication to learning!',
                    style: TextStyle(
                        fontSize:
                            certificateHeight * 0.02, // Responsive font size
                        color: Colors.grey[900]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Signature area (tappable to add)
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: widget.allowDigitalSignature
                            ? _pickSignature
                            : null,
                        onLongPress: () {
                          setState(() {
                            _signatureLocked = !_signatureLocked;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _signatureLocked
                                    ? 'Signature locked'
                                    : 'Signature unlocked',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: SizedBox(
                          width: certificateWidth *
                              0.25, // 25% of certificate width
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (_signatureBytes != null)
                                Image.memory(
                                  _signatureBytes!,
                                  height: certificateHeight *
                                      0.08, // Responsive height
                                  fit: BoxFit.contain,
                                )
                              else
                                Container(
                                  height: certificateHeight *
                                      0.08, // Responsive height
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey[400]!),
                                  ),
                                  child: widget.allowDigitalSignature
                                      ? Text(
                                          'Tap to add signature',
                                          style: TextStyle(
                                            fontSize: certificateHeight *
                                                0.015, // Responsive font size
                                            color: Colors.grey[700],
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              const SizedBox(height: 6),
                              Container(height: 1, color: Colors.grey[600]),
                              const SizedBox(height: 6),
                              // FORCE SHOW TEACHER NAME IN SIGNATURE AREA
                              if (widget.initialTeacherName != null &&
                                  widget.initialTeacherName!.isNotEmpty) ...[
                                Text(
                                  widget.initialTeacherName!,
                                  style: TextStyle(
                                    fontSize: certificateHeight * 0.02,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Course Instructor',
                                  style: TextStyle(
                                    fontSize: certificateHeight * 0.015,
                                    color: Colors.grey[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ] else if (_teacherName.isNotEmpty) ...[
                                Text(
                                  _teacherName,
                                  style: TextStyle(
                                    fontSize: certificateHeight * 0.02,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Course Instructor',
                                  style: TextStyle(
                                    fontSize: certificateHeight * 0.015,
                                    color: Colors.grey[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ] else ...[
                                Text(
                                  'Course Instructor',
                                  style: TextStyle(
                                    fontSize: certificateHeight * 0.018,
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: 4),
                              if (widget.allowDigitalSignature)
                                TextButton(
                                  onPressed: _editTeacherInfo,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Edit name & title',
                                    style: TextStyle(
                                      fontSize: certificateHeight * 0.012,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Bottom row: course author on the left, signature placeholder on the right
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Course Author label + name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Course Author:',
                              style: TextStyle(
                                fontSize: certificateHeight * 0.016,
                                color: Colors.grey[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (widget.courseAuthor != null &&
                                      widget.courseAuthor!.isNotEmpty)
                                  ? widget.courseAuthor!
                                  : (widget.initialTeacherName ?? 'Unknown'),
                              style: TextStyle(
                                fontSize: certificateHeight * 0.02,
                                color: Colors.blueGrey[900],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: certificateWidth * 0.08),
                      // Signature box placeholder to align with PDF layout
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: certificateWidth * 0.25,
                            height: certificateHeight * 0.08,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[400]!),
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                              height: 1,
                              width: certificateWidth * 0.25,
                              color: Colors.grey[600]),
                          const SizedBox(height: 4),
                          Text(
                            _resolveInstructorName(),
                            style: TextStyle(
                              fontSize: certificateHeight * 0.016,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
