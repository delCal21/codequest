import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:html' as html;

void downloadPdfForPlatform(
  BuildContext context,
  List<int> pdfBytes,
  DateTime timestamp,
) {
  final Uint8List typedBytes = Uint8List.fromList(pdfBytes);
  final blob = html.Blob([typedBytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = 'users_report_${timestamp.millisecondsSinceEpoch}.pdf'
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Report downloaded successfully!'),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 3),
    ),
  );
}

void openPdfInNewTab(
  BuildContext context,
  List<int> pdfBytes,
  DateTime timestamp,
) {
  final Uint8List typedBytes = Uint8List.fromList(pdfBytes);
  final blob = html.Blob([typedBytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  // Do not revoke immediately; give the new tab time to load the blob
  Future.delayed(const Duration(seconds: 3), () {
    html.Url.revokeObjectUrl(url);
  });
}
