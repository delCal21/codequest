import 'package:flutter/material.dart';
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart'
    if (dart.library.io) 'download_helper_mobile.dart' as impl;

void downloadPdfForPlatform(
  BuildContext context,
  List<int> pdfBytes,
  DateTime timestamp,
) {
  impl.downloadPdfForPlatform(context, pdfBytes, timestamp);
}

void openPdfInNewTab(
  BuildContext context,
  List<int> pdfBytes,
  DateTime timestamp,
) {
  impl.openPdfInNewTab(context, pdfBytes, timestamp);
}
