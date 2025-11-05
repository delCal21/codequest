import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
// For web download
import 'package:universal_html/html.dart' as html;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:codequest/features/admin/presentation/pages/admin_dashboard_page.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({Key? key}) : super(key: key);

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  String? _backupMessage;
  String? _restoreMessage;
  List<String> _collections = [
    'users',
    'courses',
    'challenges',
    'forums',
    'videos',
    'enrollments',
    'forum_posts',
    'comments',
  ];
  Map<String, int> _collectionCounts = {};
  List<String> _history = [];

  Future<void> _fetchCollectionCounts() async {
    final firestore = FirebaseFirestore.instance;
    final Map<String, int> counts = {};
    for (final collection in _collections) {
      final snapshot = await firestore.collection(collection).get();
      counts[collection] = snapshot.docs.length;
    }
    setState(() {
      _collectionCounts = counts;
    });
  }

  /// Recursively converts Firestore Timestamp objects to ISO8601 strings for JSON encoding
  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate().toIso8601String());
      } else if (value is Map) {
        return MapEntry(
            key, _convertTimestamps(Map<String, dynamic>.from(value)));
      } else if (value is List) {
        return MapEntry(
          key,
          value
              .map((item) => item is Map
                  ? _convertTimestamps(Map<String, dynamic>.from(item))
                  : (item is Timestamp
                      ? item.toDate().toIso8601String()
                      : item))
              .toList(),
        );
      }
      return MapEntry(key, value);
    });
  }

  Future<void> _backupData() async {
    setState(() {
      _isBackingUp = true;
      _backupMessage = null;
    });
    try {
      final firestore = FirebaseFirestore.instance;
      final Map<String, List<Map<String, dynamic>>> backup = {};
      for (final collection in _collections) {
        final snapshot = await firestore.collection(collection).get();
        backup[collection] = snapshot.docs.map((doc) {
          final data = {'id': doc.id, ...doc.data()};
          return _convertTimestamps(data);
        }).toList();
      }
      final jsonString = const JsonEncoder.withIndent('  ').convert(backup);
      final fileName =
          'codequest-backup-${DateTime.now().toIso8601String()}.json';
      if (kIsWeb) {
        final bytes = utf8.encode(jsonString);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await FilePicker.platform.getDirectoryPath();
        if (directory != null) {
          final file = File('$directory/$fileName');
          await file.writeAsString(jsonString);
        }
      }
      setState(() {
        _backupMessage = 'Backup completed!';
        _history.insert(0, 'Backup: $fileName');
      });
    } catch (e) {
      setState(() {
        _backupMessage = 'Backup failed: $e';
        _history.insert(0, 'Backup failed: $e');
      });
    } finally {
      setState(() {
        _isBackingUp = false;
      });
    }
  }

  Future<void> _restoreData() async {
    setState(() {
      _restoreMessage = null;
    });
    try {
      FilePickerResult? result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result == null || result.files.isEmpty) return;
      final fileBytes = result.files.first.bytes;
      final fileString = fileBytes != null
          ? utf8.decode(fileBytes)
          : await File(result.files.first.path!).readAsString();
      final Map<String, dynamic> data = json.decode(fileString);
      final collections = data.keys;
      final firestore = FirebaseFirestore.instance;
      // Show summary before restore
      final summary = collections
          .map((c) => '$c: ${(data[c] as List).length} docs')
          .join('\n');
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Restore'),
          content: Text(
              'This will overwrite existing data with the same IDs.\n\nCollections:\n$summary\n\nAre you sure you want to continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      setState(() {
        _isRestoring = true;
      });
      int total = 0;
      for (final collection in collections) {
        final List<dynamic> docs = data[collection];
        for (final doc in docs) {
          final id = doc['id'];
          final docData = Map<String, dynamic>.from(doc)..remove('id');
          await firestore
              .collection(collection)
              .doc(id)
              .set(docData, SetOptions(merge: false));
          total++;
        }
      }
      setState(() {
        _restoreMessage = 'Restore completed! $total documents written.';
        _history.insert(0, 'Restore: $total docs');
      });
    } catch (e) {
      setState(() {
        _restoreMessage = 'Restore failed: $e';
        _history.insert(0, 'Restore failed: $e');
      });
    } finally {
      setState(() {
        _isRestoring = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCollectionCounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.green[700],
        iconTheme: IconThemeData(color: Colors.green[700]),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Navigate',
            icon: const Icon(Icons.menu_rounded),
            onSelected: (index) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => AdminDashboardPage(initialIndex: index),
                ),
              );
            },
            itemBuilder: (context) => const [
              PopupMenuItem<int>(value: 0, child: Text('Dashboard')),
              PopupMenuItem<int>(value: 1, child: Text('Courses')),
              PopupMenuItem<int>(value: 2, child: Text('Challenges')),
              PopupMenuItem<int>(value: 3, child: Text('Videos')),
              PopupMenuItem<int>(value: 4, child: Text('Forums')),
              PopupMenuItem<int>(value: 5, child: Text('Students')),
              PopupMenuItem<int>(value: 6, child: Text('Teachers')),
            ],
          ),
        ],
      ),
      backgroundColor: Colors.green[50],
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.backup,
                                  color: Colors.green[700], size: 32),
                              const SizedBox(width: 12),
                              const Text('Backup Data',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Download a backup of your Firestore collections.',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: _collections.map((c) {
                              final count = _collectionCounts[c];
                              return Chip(
                                label: Text('$c (${count ?? "..."})'),
                                backgroundColor: Colors.green[50],
                                labelStyle: TextStyle(color: Colors.green[700]),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.download),
                            label: const Text('Download Backup'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _isBackingUp ? null : _backupData,
                          ),
                          if (_isBackingUp)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          if (_backupMessage != null)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: MaterialBanner(
                                backgroundColor:
                                    _backupMessage!.contains('failed')
                                        ? Colors.red[50]
                                        : Colors.green[50],
                                content: Text(_backupMessage!,
                                    style: TextStyle(
                                        color:
                                            _backupMessage!.contains('failed')
                                                ? Colors.red
                                                : Colors.green[700],
                                        fontWeight: FontWeight.w600)),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _backupMessage = null),
                                    child: const Text('DISMISS'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    color: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.restore,
                                  color: Colors.green[700], size: 32),
                              const SizedBox(width: 12),
                              const Text('Restore Data',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Restore your Firestore collections from a backup file.',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Select Backup File & Restore'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _isRestoring ? null : _restoreData,
                          ),
                          if (_isRestoring)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          if (_restoreMessage != null)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: MaterialBanner(
                                backgroundColor:
                                    _restoreMessage!.contains('failed')
                                        ? Colors.red[50]
                                        : Colors.green[50],
                                content: Text(_restoreMessage!,
                                    style: TextStyle(
                                        color:
                                            _restoreMessage!.contains('failed')
                                                ? Colors.red
                                                : Colors.green[700],
                                        fontWeight: FontWeight.w600)),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _restoreMessage = null),
                                    child: const Text('DISMISS'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_history.isNotEmpty)
                    Card(
                      color: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.history, color: Colors.green[700]),
                                const SizedBox(width: 8),
                                const Text('Recent Activity',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ..._history.take(5).map((h) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(h,
                                      style: TextStyle(
                                          color: h.contains('failed')
                                              ? Colors.red
                                              : Colors.green[700])),
                                )),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
