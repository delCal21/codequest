import 'package:flutter/material.dart';
import 'certificate_widget.dart';

class CertificateDialog extends StatefulWidget {
  final String studentName;
  final String courseName;
  final String? teacherName;
  final bool allowDigitalSignature;
  final DateTime? completionDate;
  final String? courseAuthor;

  const CertificateDialog({
    required this.studentName,
    required this.courseName,
    this.teacherName,
    this.allowDigitalSignature = true,
    this.completionDate,
    this.courseAuthor,
    Key? key,
  }) : super(key: key);

  @override
  State<CertificateDialog> createState() => _CertificateDialogState();
}

class _CertificateDialogState extends State<CertificateDialog> {
  final GlobalKey<CertificateWidgetState> _certKey =
      GlobalKey<CertificateWidgetState>();
  bool _showCertificate =
      false; // Hide preview; show only Download Options buttons

  void _withCertReady(void Function(CertificateWidgetState s) action) {
    final state = _certKey.currentState;
    if (state != null) {
      action(state);
      return;
    }
    setState(() {
      _showCertificate = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = _certKey.currentState;
      if (s != null) {
        action(s);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Certificate not ready yet. Please try again.')),
          );
        }
      }
    });
  }

  Widget _buildProfessionalButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback? onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 1,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: const Size(0, 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Print what we received
    print('=== CertificateDialog Debug ===');
    print('Student Name: ${widget.studentName}');
    print('Course Name: ${widget.courseName}');
    print('Teacher Name: ${widget.teacherName}');
    print('Course Author: ${widget.courseAuthor}');
    print('Completion Date: ${widget.completionDate}');
    print('Allow Digital Signature: ${widget.allowDigitalSignature}');

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate responsive dialog size for landscape certificate
    double dialogWidth = 900; // Wider to accommodate landscape certificate
    double dialogHeight = 700; // Shorter height for landscape

    if (screenWidth < 950) {
      // Scale down for smaller screens
      final scale = screenWidth / 950;
      dialogWidth = 900 * scale;
      dialogHeight = 700 * scale;
    }

    // Ensure dialog doesn't exceed screen bounds
    dialogWidth = dialogWidth.clamp(300.0, screenWidth - 32);
    dialogHeight = dialogHeight.clamp(400.0, screenHeight - 32);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxWidth: screenWidth - 32,
          maxHeight: screenHeight - 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Certificate preview area (always created but conditionally shown)
            if (_showCertificate)
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: CertificateWidget(
                      key: _certKey,
                      studentName: widget.studentName,
                      courseName: widget.courseName,
                      initialTeacherName: widget.teacherName,
                      allowDigitalSignature: widget.allowDigitalSignature,
                      completionDate: widget.completionDate,
                      courseAuthor: widget.courseAuthor,
                    ),
                  ),
                ),
              ),
            // Hidden certificate widget for button functionality
            if (!_showCertificate)
              Opacity(
                opacity: 0.0,
                child: SizedBox(
                  height: 1,
                  child: CertificateWidget(
                    key: _certKey,
                    studentName: widget.studentName,
                    courseName: widget.courseName,
                    initialTeacherName: widget.teacherName,
                    allowDigitalSignature: widget.allowDigitalSignature,
                    completionDate: widget.completionDate,
                    courseAuthor: widget.courseAuthor,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Download Options',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Professional button layout
                LayoutBuilder(
                  builder: (context, constraints) {
                    // If screen is narrow, stack buttons vertically
                    if (constraints.maxWidth < 600) {
                      return Column(
                        children: [
                          _buildProfessionalButton(
                            context,
                            'Preview PDF',
                            Icons.preview,
                            () => _withCertReady(
                              (s) => s.previewPDFCertificate(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildProfessionalButton(
                            context,
                            'Download PDF',
                            Icons.picture_as_pdf,
                            () => _withCertReady(
                              (s) => s.downloadCertificate(context),
                            ),
                          ),
                        ],
                      );
                    } else {
                      // For wider screens, use horizontal layout
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: _buildProfessionalButton(
                              context,
                              'Preview PDF',
                              Icons.preview,
                              () => _withCertReady(
                                (s) => s.previewPDFCertificate(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildProfessionalButton(
                              context,
                              'Download PDF',
                              Icons.picture_as_pdf,
                              () => _withCertReady(
                                (s) => s.downloadCertificate(context),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 24),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
