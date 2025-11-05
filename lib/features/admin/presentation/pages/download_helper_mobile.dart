import 'package:flutter/material.dart';

void downloadPdfForPlatform(
  BuildContext context,
  List<int> pdfBytes,
  DateTime timestamp,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('PDF download is available on web only.'),
      backgroundColor: Colors.orange,
    ),
  );
}

void openPdfInNewTab(
  BuildContext context,
  List<int> pdfBytes,
  DateTime timestamp,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Opening new tab is supported on web only.'),
      backgroundColor: Colors.orange,
    ),
  );
}
