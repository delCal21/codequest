import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class CourseFileViewerPage extends StatefulWidget {
  final String fileUrl;
  final String fileName;
  // Optionally accept a list of files for navigation
  final List<Map<String, dynamic>>? files;
  const CourseFileViewerPage(
      {Key? key, required this.fileUrl, required this.fileName, this.files})
      : super(key: key);

  @override
  State<CourseFileViewerPage> createState() => _CourseFileViewerPageState();
}

class _CourseFileViewerPageState extends State<CourseFileViewerPage> {
  PdfController? _pdfController;
  bool _isLoading = false;
  bool _pdfError = false;
  bool _webViewError = false;

  bool get isPdf => widget.fileName.toLowerCase().endsWith('.pdf');
  bool get isDoc =>
      widget.fileName.toLowerCase().endsWith('.doc') ||
      widget.fileName.toLowerCase().endsWith('.docx');

  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    if (isPdf) {
      _loadPdf();
    } else {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onWebResourceError: (error) {
              setState(() {
                _webViewError = true;
              });
            },
          ),
        )
        ..loadRequest(Uri.parse(
          isDoc
              ? 'https://docs.google.com/gview?url=${Uri.encodeComponent(widget.fileUrl)}&embedded=true'
              : widget.fileUrl,
        ));
    }
  }

  Future<void> _loadPdf() async {
    setState(() {
      _isLoading = true;
      _pdfError = false;
    });
    try {
      final response = await http.get(Uri.parse(widget.fileUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        print('PDF bytes length: ${bytes.length}');
        // Check for valid PDF header and not HTML error page
        final header = String.fromCharCodes(bytes.take(15));
        if (bytes.isEmpty ||
            bytes.length < 5 ||
            !header.startsWith('%PDF-') ||
            header.contains('<!DOCTYPE html') ||
            header.contains('<html')) {
          // PDF is empty, too small, not a PDF, or is an HTML error page
          print('Invalid PDF header: ${header}');
          _pdfError = true;
        } else {
          _pdfController = PdfController(
            document: PdfDocument.openData(bytes),
          );
        }
      } else {
        _pdfError = true;
      }
    } catch (e) {
      print('Error downloading PDF: ${e.toString()}');
      _pdfError = true;
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!isPdf && _webViewController != null) {
          final canGoBack = await _webViewController!.canGoBack();
          if (canGoBack) {
            _webViewController!.goBack();
            return false;
          }
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.fileName),
          actions: widget.files != null && widget.files!.length > 1
              ? [
                  PopupMenuButton<Map<String, dynamic>>(
                    icon: const Icon(Icons.attach_file),
                    onSelected: (file) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => CourseFileViewerPage(
                            fileUrl: file['url'],
                            fileName: file['name'],
                            files: widget.files,
                          ),
                        ),
                      );
                    },
                    itemBuilder: (context) => widget.files!
                        .map((file) => PopupMenuItem(
                              value: file,
                              child: Text(file['name'] ?? ''),
                            ))
                        .toList(),
                  ),
                ]
              : null,
        ),
        body: isPdf
            ? _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pdfError
                    ? const Center(child: Text('Failed to load PDF.'))
                    : PdfView(controller: _pdfController!)
            : _webViewController == null
                ? const Center(child: CircularProgressIndicator())
                : _webViewError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Preview not available.'),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Download & Open'),
                              onPressed: () async {
                                final url = widget.fileUrl;
                                final uri = Uri.parse(url);
                                if (await canLaunchUrl(uri)) {
                                  final launched = await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                  if (!launched && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Could not open file.')),
                                    );
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Could not open file.')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      )
                    : WebViewWidget(controller: _webViewController!),
      ),
    );
  }
}
