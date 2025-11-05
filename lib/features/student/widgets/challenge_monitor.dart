import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:screenshot_callback/screenshot_callback.dart';

class ChallengeMonitor extends StatefulWidget {
  final String challengeId;
  final String challengeTitle;
  final String? courseId;
  final String? courseTitle;
  final String? challengeType;
  final String? challengeDifficulty;
  final Widget child;

  const ChallengeMonitor({
    Key? key,
    required this.challengeId,
    required this.challengeTitle,
    this.courseId,
    this.courseTitle,
    this.challengeType,
    this.challengeDifficulty,
    required this.child,
  }) : super(key: key);

  @override
  State<ChallengeMonitor> createState() => _ChallengeMonitorState();
}

class _ChallengeMonitorState extends State<ChallengeMonitor>
    with WidgetsBindingObserver {
  StreamSubscription? _visibilitySubscription;
  ScreenshotCallback? _screenshotCallback;
  Timer? _timer;
  int _secondsLeft = 0;
  int? _timeLimit;
  bool _timeUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Load challenge time limit
    _loadChallengeTimeLimit();

    // Block screenshots and screen recording using screen_protector
    ScreenProtector.preventScreenshotOn();

    // Listen to screenshot attempts (mobile platforms only)
    if (!kIsWeb) {
      _screenshotCallback = ScreenshotCallback();
      _screenshotCallback!.addListener(() {
        _logCheatingEvent('screenshot_taken');
      });
    }

    // For Android: Set secure flags using platform channels
    if (!kIsWeb) {
      _setSecureFlags();
    }

    // For web: listen to tab visibility changes (only if running on web)
    if (kIsWeb) {
      _setupWebVisibilityListener();
    }
  }

  Future<void> _setSecureFlags() async {
    try {
      // Use platform channels to set secure flags
      const platform = MethodChannel('com.example.codequest/security');
      await platform.invokeMethod('setSecureFlags');
    } catch (e) {
      // Ignore errors if platform channel is not implemented
      debugPrint('Secure flags not available: $e');
    }
  }

  void _setupWebVisibilityListener() {
    // This method will only be called on web
    if (kIsWeb) {
      // Web-specific code using conditional compilation
      // Note: This code will only compile and run on web platforms
      // For mobile platforms, this method will do nothing
      debugPrint('Web visibility listener setup (web only)');
      // Periodic activity checks for web
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          _logCheatingEvent('web_activity_check');
        } else {
          timer.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _visibilitySubscription?.cancel();
    _timer?.cancel();
    try {
      _screenshotCallback?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _logCheatingEvent('app_paused');
    } else if (state == AppLifecycleState.resumed) {
      _logCheatingEvent('app_resumed');
    }
  }

  Future<void> _logCheatingEvent(String eventType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Fetch student name from Firestore
    String studentName = '';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        studentName = data['name'] ?? data['fullName'] ?? user.email ?? '';
      } else {
        studentName = user.email ?? '';
      }
    } catch (e) {
      studentName = user.email ?? '';
    }
    await FirebaseFirestore.instance.collection('challenge_cheat_logs').add({
      'studentId': user.uid,
      'studentName': studentName,
      'challengeId': widget.challengeId,
      'challengeTitle': widget.challengeTitle,
      'courseId': widget.courseId,
      'courseTitle': widget.courseTitle,
      'challengeType': widget.challengeType,
      'challengeDifficulty': widget.challengeDifficulty,
      'eventType': eventType,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Show warning for serious cheating events
    if (eventType == 'screenshot_taken' ||
        eventType == 'screen_recording_started') {
      _showCheatingWarning(eventType);
    }
  }

  void _showCheatingWarning(String eventType) {
    String message = '';
    switch (eventType) {
      case 'screenshot_taken':
        message = 'Screenshot detected! This may be considered cheating.';
        break;
      case 'screen_recording_started':
        message =
            'Screen recording detected! This is not allowed during challenges.';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _loadChallengeTimeLimit() async {
    try {
      final challengeDoc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeId)
          .get();

      if (challengeDoc.exists) {
        final data = challengeDoc.data() as Map<String, dynamic>;
        final timeLimit = data['timeLimit'] as int?;

        if (timeLimit != null && timeLimit > 0) {
          setState(() {
            _timeLimit = timeLimit;
            _secondsLeft = timeLimit * 60;
          });
          _startTimer();
        }
      }
    } catch (e) {
      print('Error loading challenge time limit: $e');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        if (!mounted) return;
        setState(() {
          _secondsLeft--;
        });
      } else {
        timer.cancel();
        if (!mounted) return;
        setState(() {
          _timeUp = true;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange[300]!, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.security,
                  color: Colors.orange[700],
                  size: 12,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'You are being monitored while taking this challenge',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_timeLimit != null && !_timeUp) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _secondsLeft <= 60
                          ? Colors.red[100]
                          : Colors.blue[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _secondsLeft <= 60
                            ? Colors.red[300]!
                            : Colors.blue[300]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer,
                          color: _secondsLeft <= 60
                              ? Colors.red[700]
                              : Colors.blue[700],
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(_secondsLeft),
                          style: TextStyle(
                            color: _secondsLeft <= 60
                                ? Colors.red[800]
                                : Colors.blue[800],
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_timeUp) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red[300]!, width: 1),
                    ),
                    child: Text(
                      'TIME UP!',
                      style: TextStyle(
                        color: Colors.red[800],
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
