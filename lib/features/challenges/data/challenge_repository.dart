import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/challenges/domain/models/challenge_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:convert';
import 'package:codequest/services/jdoodle_service.dart';
import 'package:codequest/services/notification_service.dart';

class ChallengeRepository {
  final FirebaseFirestore _firestore;
  ChallengeRepository(this._firestore);

  // Get all published challenges (for students)
  Future<List<ChallengeModel>> getPublishedChallenges() async {
    try {
      print('Fetching all challenges for student view...');
      final snapshot = await _firestore.collection('challenges').get();

      print('Found ${snapshot.docs.length} challenges in Firestore query.');

      final challenges = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Add the document ID to the data
        final challenge = ChallengeModel.fromJson(data);
        print(
            'Fetched challenge: ${challenge.title}, ID: ${challenge.id}, isPublished: ${challenge.isPublished}');

        return challenge;
      }).toList();

      // Sort the challenges in memory instead of in the query
      challenges.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('Returning ${challenges.length} challenges after in-memory sort.');
      return challenges;
    } catch (e) {
      print('Error fetching published challenges: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      rethrow;
    }
  }

  // Get challenges by teacher (for teachers)
  Future<List<ChallengeModel>> getTeacherChallenges(String teacherId) async {
    final snapshot = await _firestore
        .collection('challenges')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => ChallengeModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  // Get all challenges (for admin)
  Future<List<ChallengeModel>> getAllChallenges() async {
    final snapshot = await _firestore
        .collection('challenges')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => ChallengeModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  // Create new challenge (for admin/teacher)
  Future<String> createChallenge(ChallengeModel challenge) async {
    try {
      print('Attempting to create challenge in Firestore...');
      print('Challenge ID for creation: ${challenge.id}');
      print('Challenge data to be sent: ${challenge.toJson()}');

      await _firestore
          .collection('challenges')
          .doc(challenge.id)
          .set(challenge.toJson());
      print('Challenge created successfully in Firestore: ${challenge.id}');

      // Create admin notification
      await NotificationService.notifyChallengeEvent(
        type: 'created',
        challengeId: challenge.id,
        challengeTitle: challenge.title,
        userId: challenge.teacherId,
        userName: challenge.teacherName,
        challengeData: challenge.toJson(),
      );

      return challenge.id;
    } catch (e) {
      print('Error creating challenge in Firestore: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      rethrow;
    }
  }

  // Update challenge (for admin/teacher)
  Future<void> updateChallenge(
      String challengeId, ChallengeModel challenge) async {
    try {
      print('Attempting to update challenge in Firestore...');
      print('Challenge ID for update: $challengeId');
      print('Challenge data to be sent: ${challenge.toJson()}');

      await _firestore
          .collection('challenges')
          .doc(challengeId)
          .update(challenge.toJson());
      print('Challenge updated successfully in Firestore: $challengeId');

      // Create admin notification
      await NotificationService.notifyChallengeEvent(
        type: 'updated',
        challengeId: challengeId,
        challengeTitle: challenge.title,
        userId: challenge.teacherId,
        userName: challenge.teacherName,
        challengeData: challenge.toJson(),
      );
    } catch (e) {
      print('Error updating challenge in Firestore: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      rethrow;
    }
  }

  // Delete challenge (for admin)
  Future<void> deleteChallenge(String challengeId) async {
    // Get challenge data before deletion for notification
    final challengeDoc =
        await _firestore.collection('challenges').doc(challengeId).get();
    final challengeData = challengeDoc.data();

    await _firestore.collection('challenges').doc(challengeId).delete();

    // Create admin notification
    if (challengeData != null) {
      await NotificationService.notifyChallengeEvent(
        type: 'deleted',
        challengeId: challengeId,
        challengeTitle: challengeData['title'] ?? 'Unknown Challenge',
        userId: challengeData['teacherId'] ?? 'unknown',
        userName: challengeData['teacherName'] ?? 'Unknown User',
        challengeData: challengeData,
      );
    }
  }

  // Toggle challenge publish status
  Future<void> toggleChallengePublish(
      String challengeId, bool isPublished) async {
    try {
      print(
          'Toggling publish status for challenge ID: $challengeId to $isPublished');
      await _firestore
          .collection('challenges')
          .doc(challengeId)
          .update({'isPublished': isPublished});
      print(
          'Successfully toggled publish status for challenge ID: $challengeId');
    } catch (e) {
      print(
          'Error toggling publish status for challenge ID: $challengeId - $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      rethrow;
    }
  }

  // Get submitted challenges (for students)
  Future<List<ChallengeModel>> getSubmittedChallenges(String studentId) async {
    final submissionsSnapshot = await _firestore
        .collection('challenge_submissions')
        .where('studentId', isEqualTo: studentId)
        .get();

    final challengeIds = submissionsSnapshot.docs
        .map((doc) => doc.data()['challengeId'] as String)
        .toList();

    if (challengeIds.isEmpty) return [];

    final challengesSnapshot = await _firestore
        .collection('challenges')
        .where(FieldPath.documentId, whereIn: challengeIds)
        .get();

    return challengesSnapshot.docs
        .map((doc) => ChallengeModel.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  // Submit challenge (for students)
  Future<void> submitChallenge(
    String challengeId,
    String solution, {
    String? fileUrl,
    String? language,
    Function()? onChallengeCompleted,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('=== SUBMIT CHALLENGE START ===');
      print('Challenge ID: $challengeId');
      print('User ID: ${user.uid}');
      print('Language: $language');
      print('Solution length: ${solution.length}');
      print(
          'Solution preview: ${solution.substring(0, solution.length > 200 ? 200 : solution.length)}...');

      // Get challenge details
      final challengeDoc =
          await _firestore.collection('challenges').doc(challengeId).get();
      if (!challengeDoc.exists) {
        throw Exception('Challenge not found');
      }

      final challengeData = challengeDoc.data()!;
      print('Challenge Data:');
      print('- Type: ${challengeData['type']}');
      print('- Title: ${challengeData['title']}');
      print('- Test Cases: ${challengeData['testCases']}');
      print('- Passing Score: ${challengeData['passingScore']}');
      print('=== END CHALLENGE DATA ===');

      // Get user role
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        throw Exception('User document not found');
      }
      final userRole = userDoc.data()?['role']?.toString().toLowerCase();
      print('User role: $userRole');

      final submission = {
        'studentId': user.uid,
        'challengeId': challengeId,
        'solution': solution,
        'fileUrl': fileUrl,
        'language': language,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'score': 0.0,
        'challengeTitle': challengeData['title'] ?? 'Unknown Challenge',
        'challengeType': challengeData['type'] ?? 'unknown',
        'challengeLesson': challengeData['lesson'] ?? 1,
        'userRole': userRole, // Add user role for debugging
      };

      print('Creating submission document with data:');
      print(submission);

      final submissionRef =
          await _firestore.collection('challenge_submissions').add(submission);
      print('Submission document created with ID: ${submissionRef.id}');

      double score = 0.0;
      String status = 'pending';
      int passedCount = 0;
      int totalCount = 0;
      List<String> testCases = [];
      double passingScore = 70.0;
      if ((challengeData['type'] == 'coding' ||
          challengeData['type'] == ChallengeType.coding.name)) {
        print('=== CODING CHALLENGE DETECTED ===');
        print('Challenge type value: "${challengeData['type']}"');
        print('ChallengeType.coding.name: "${ChallengeType.coding.name}"');
        print('Is coding challenge: true');

        testCases = List<String>.from(challengeData['testCases'] ?? []);
        passingScore =
            (challengeData['passingScore'] as num?)?.toDouble() ?? 70.0;
        final jdoodle = JDoodleService();

        print('=== CHALLENGE EVALUATION SETUP ===');
        print('Challenge ID: $challengeId');
        print('Challenge Type: ${challengeData['type']}');
        print('Test Cases Count: ${testCases.length}');
        print('Test Cases: $testCases');
        print('Test Cases Details:');
        for (int i = 0; i < testCases.length; i++) {
          print(
              '  Test Case $i: "${testCases[i]}" (length: ${testCases[i].length})');
        }
        print('Passing Score: $passingScore');
        print('=== END SETUP ===');

        // Filter out empty or whitespace-only test cases
        final validTestCases =
            testCases.where((testCase) => testCase.trim().isNotEmpty).toList();
        print('Valid Test Cases Count: ${validTestCases.length}');
        print('Valid Test Cases: $validTestCases');

        totalCount = validTestCases.length;
        print('Total Count: $totalCount');

        if (validTestCases.isNotEmpty) {
          // Test cases provided: Run all test cases and check output matches expected
          print(
              'Running ${validTestCases.length} test cases for evaluation...');
          for (final testCase in validTestCases) {
            // Assume testCase is a JSON string: {"input": ..., "expectedOutput": ...}
            try {
              final testCaseMap = testCase.contains('{')
                  ? Map<String, dynamic>.from(jsonDecode(testCase))
                  : null;
              final input = testCaseMap != null
                  ? testCaseMap['input']?.toString() ?? ''
                  : '';
              final expectedOutput = testCaseMap != null
                  ? testCaseMap['expectedOutput']?.toString().trim() ?? ''
                  : '';
              final result = await jdoodle.executeCode(
                script: solution,
                language: language ?? 'python3',
                stdin: input,
                versionIndex: '0',
              );

              print('JDoodle execution completed. Raw result: $result');

              // Enhanced error checking for JDoodle response
              final hasError = result['error'] != null &&
                  result['error'].toString().isNotEmpty &&
                  result['error'].toString().toLowerCase() != 'null';

              // Check for compilation and runtime errors in output
              final output = result['output']?.toString() ?? '';
              final statusCode = result['statusCode']?.toString() ?? '';
              final isCompiled = result['isCompiled'] as bool? ?? true;
              final isExecutionSuccess =
                  result['isExecutionSuccess'] as bool? ?? true;

              // Check for empty solution
              final hasEmptySolution = solution.trim().isEmpty;

              // Comprehensive error detection in output
              final hasCompilationError =
                  output.toLowerCase().contains('error') ||
                      output.toLowerCase().contains('exception') ||
                      output.toLowerCase().contains('traceback') ||
                      output.toLowerCase().contains('syntaxerror') ||
                      output.toLowerCase().contains('nameerror') ||
                      output.toLowerCase().contains('typeerror') ||
                      output.toLowerCase().contains('indentationerror') ||
                      output.toLowerCase().contains('zerodivisionerror') ||
                      output.toLowerCase().contains('filenotfounderror') ||
                      output.toLowerCase().contains('permissionerror') ||
                      output.toLowerCase().contains('timeout') ||
                      output.toLowerCase().contains('memory') ||
                      output.toLowerCase().contains('segmentation fault') ||
                      output.toLowerCase().contains('killed') ||
                      output.toLowerCase().contains('aborted') ||
                      output.toLowerCase().contains('core dumped') ||
                      output.toLowerCase().contains('syntax error') ||
                      output.toLowerCase().contains('indentation') ||
                      output.toLowerCase().contains('valueerror') ||
                      output.toLowerCase().contains('indexerror') ||
                      output.toLowerCase().contains('keyerror') ||
                      output.toLowerCase().contains('attributeerror') ||
                      output.toLowerCase().contains('failed') ||
                      output.toLowerCase().contains('invalid') ||
                      output.toLowerCase().contains('unexpected');

              // Check for API errors
              final hasApiError = statusCode != '200' ||
                  result['error'] != null ||
                  result['error']?.toString().isNotEmpty == true;

              // Check for compilation failure
              final hasCompilationFailure = isCompiled == false;

              // Check for execution failure
              final hasExecutionFailure = isExecutionSuccess == false;

              // For basic execution check, we don't fail on empty output
              // Empty output is valid for code that doesn't print anything
              final finalHasError = hasError ||
                  hasCompilationError ||
                  hasApiError ||
                  hasEmptySolution ||
                  hasCompilationFailure ||
                  hasExecutionFailure;

              print('=== DETAILED ERROR ANALYSIS (Basic Execution Check) ===');
              print('Full JDoodle result: $result');
              print('- hasError (API error): $hasError');
              print(
                  '- hasCompilationError (output contains errors): $hasCompilationError');
              print('- hasApiError (status/API issues): $hasApiError');
              print('- hasEmptySolution (empty code): $hasEmptySolution');
              print(
                  '- hasCompilationFailure (isCompiled: false): $hasCompilationFailure');
              print(
                  '- hasExecutionFailure (isExecutionSuccess: false): $hasExecutionFailure');
              print('- finalHasError (any error detected): $finalHasError');
              print('- Output: "${output}"');
              print('- Error: "${result['error']}"');
              print('- StatusCode: $statusCode');
              print('- isCompiled: $isCompiled');
              print('- isExecutionSuccess: $isExecutionSuccess');
              print('- Memory: ${result['memory']}');
              print('- CpuTime: ${result['cpuTime']}');
              print('- Result keys: ${result.keys.toList()}');
              print('=== END ERROR ANALYSIS ===');

              // STRICT error detection - if ANY error indicator is found, fail
              if (finalHasError) {
                final errorMessage = hasEmptySolution
                    ? 'Empty solution submitted'
                    : hasError
                        ? 'API Error: ${result['error']}'
                        : hasCompilationError
                            ? 'Code contains errors: ${output.substring(0, output.length > 100 ? 100 : output.length)}'
                            : hasCompilationFailure
                                ? 'Code compilation failed'
                                : hasExecutionFailure
                                    ? 'Code execution failed'
                                    : hasApiError
                                        ? 'API/Execution error detected'
                                        : 'Execution error detected';
                print('Code execution failed: $errorMessage. Status: failed');
                // Don't increment passedCount - this test case failed
              } else {
                // Check if output matches expected output (for test cases)
                if (expectedOutput.isNotEmpty) {
                  final actualOutput = output.trim();
                  if (actualOutput == expectedOutput) {
                    passedCount++;
                    print(
                        'Test case passed: Expected "$expectedOutput", Got "$actualOutput"');
                  } else {
                    print(
                        'Test case failed: Expected "$expectedOutput", Got "$actualOutput"');
                  }
                } else {
                  // No expected output specified, just check for no errors
                  passedCount++;
                  print(
                      'Code executed successfully without errors. Test case passed.');
                }
              }
            } catch (e) {
              print('Error running test case: $e');
            }
          }
          if (validTestCases.isNotEmpty) {
            score = (passedCount / validTestCases.length) * 100.0;
          }
          status = score >= passingScore ? 'passed' : 'failed';
          print(
              'Test case evaluation complete. Passed: $passedCount/$totalCount, Score: $score, Status: $status');
        } else {
          // No test cases provided: Fail the submission and require at least one test case
          print(
              'No test cases provided for coding challenge. Failing submission.');
          score = 0.0;
          status = 'failed';
        }
      } else {
        // If not coding, fallback to previous logic (random score)
        print('=== NON-CODING CHALLENGE ===');
        print('Challenge type value: "${challengeData['type']}"');
        print('ChallengeType.coding.name: "${ChallengeType.coding.name}"');
        print('Is coding challenge: false');
        print('Using random score fallback logic');
        score = (Random().nextDouble() * 100).roundToDouble();
        passingScore = 70.0;
        status = score >= passingScore ? 'passed' : 'failed';
        print('Random score generated: $score, Status: $status');
      }

      // Update submission with actual score and status
      print('=== FINAL STATUS DETERMINATION ===');
      print('Initial Score: $score');
      print('Initial Status: $status');
      print('Passing Score: $passingScore');
      print('Score >= Passing Score: ${score >= passingScore}');

      // Final verification - if score is 0, status should be failed
      if (score == 0.0 && status != 'failed') {
        print(
            'WARNING: Score is 0 but status is not failed. Forcing status to failed.');
        status = 'failed';
      }

      // Final verification - if status is passed, score should be > 0
      if (status == 'passed' && score <= 0.0) {
        print(
            'WARNING: Status is passed but score is <= 0. Forcing status to failed.');
        status = 'failed';
        score = 0.0;
      }

      print('Final Score: $score');
      print('Final Status: $status');
      print('=== END FINAL STATUS DETERMINATION ===');

      await submissionRef.update({
        'score': score,
        'status': status,
        'gradedAt': FieldValue.serverTimestamp(),
      });
      print(
          'Submission updated successfully with final status: $status, score: $score');

      // If passed, update user's progress
      if (status == 'passed') {
        print('Challenge passed, updating user progress...');
        final challenge = ChallengeModel.fromJson({
          'id': challengeDoc.id,
          ...challengeDoc.data() as Map<String, dynamic>,
        });

        // Get course ID from the challenge
        final courseId = challenge.courseId;
        if (courseId == null) {
          print('Challenge has no courseId, skipping progress update');
          return;
        }

        // Update course-specific progress
        final courseProgressDocId = '${user.uid}_$courseId';
        final courseProgressDoc = await _firestore
            .collection('progress')
            .doc(courseProgressDocId)
            .get();

        if (!courseProgressDoc.exists) {
          print('Creating new course progress document...');
          // Create new course progress document
          await _firestore.collection('progress').doc(courseProgressDocId).set({
            'userId': user.uid,
            'courseId': courseId,
            'currentLesson': challenge.lesson,
            'highestLesson': challenge.lesson,
            'completedChallenges': [challengeId],
            'lastUpdated': FieldValue.serverTimestamp(),
            'totalScore': score,
            'challengesCompleted': 1,
          });
          print('Course progress document created');
        } else {
          print('Updating existing course progress document...');
          // Update existing course progress
          final currentLesson = courseProgressDoc.data()?['currentLesson'] ?? 0;
          final highestLesson = courseProgressDoc.data()?['highestLesson'] ?? 0;
          final completedChallenges = List<String>.from(
              courseProgressDoc.data()?['completedChallenges'] ?? []);
          final totalScore =
              (courseProgressDoc.data()?['totalScore'] ?? 0.0) + score;
          final challengesCompleted =
              (courseProgressDoc.data()?['challengesCompleted'] ?? 0) + 1;

          if (!completedChallenges.contains(challengeId)) {
            completedChallenges.add(challengeId);
          }

          await courseProgressDoc.reference.update({
            'currentLesson': max(currentLesson, challenge.lesson),
            'highestLesson': max(highestLesson, challenge.lesson),
            'completedChallenges': completedChallenges,
            'lastUpdated': FieldValue.serverTimestamp(),
            'totalScore': totalScore,
            'challengesCompleted': challengesCompleted,
            'averageScore': totalScore / challengesCompleted,
          });
          print('Course progress document updated');
        }
      }

      print('Challenge submission completed successfully');

      if (onChallengeCompleted != null) {
        onChallengeCompleted();
      }
    } catch (e) {
      print('Error submitting challenge: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
        print('Firebase error details: ${e.plugin}');
      }
      throw Exception('Failed to submit challenge: $e');
    }
  }

  Stream<Map<String, dynamic>> getUserProgress(String userId) {
    return _firestore
        .collection('progress')
        .doc(userId)
        .snapshots()
        .map((doc) =>
            doc.data() ??
            {
              'currentLesson': 1,
              'highestLesson': 1,
              'completedChallenges': [],
            });
  }

  Future<List<ChallengeModel>> getNextChallenges(String userId) async {
    try {
      final progressDoc =
          await _firestore.collection('progress').doc(userId).get();

      final currentLesson = progressDoc.data()?['currentLesson'] ?? 1;
      final completedChallenges =
          List<String>.from(progressDoc.data()?['completedChallenges'] ?? []);

      final challenges = await _firestore
          .collection('challenges')
          .where('lesson', isEqualTo: currentLesson)
          .get();

      return challenges.docs
          .map((doc) => ChallengeModel.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .where((challenge) => !completedChallenges.contains(challenge.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get next challenges: $e');
    }
  }

  // Get challenge details
  Future<ChallengeModel?> getChallengeById(String challengeId) async {
    final doc =
        await _firestore.collection('challenges').doc(challengeId).get();
    if (!doc.exists) return null;
    return ChallengeModel.fromJson(doc.data()!..['id'] = doc.id);
  }

  // Get submission details
  Future<Map<String, dynamic>?> getSubmissionDetails(
      String studentId, String challengeId) async {
    final submission = await _firestore
        .collection('challenge_submissions')
        .where('studentId', isEqualTo: studentId)
        .where('challengeId', isEqualTo: challengeId)
        .get();

    if (submission.docs.isEmpty) return null;
    return submission.docs.first.data();
  }

  Stream<List<ChallengeModel>> getChallengesByLevel(int level) {
    return _firestore
        .collection('challenges')
        .where('lesson', isEqualTo: level)
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id; // Add the document ID to the data
              return ChallengeModel.fromJson(data);
            }).toList());
  }

  Future<void> submitChallengeResult({
    required String challengeId,
    required bool passed,
    required double grade,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Save submission result
    final submission = {
      'userId': user.uid,
      'challengeId': challengeId,
      'submittedAt': FieldValue.serverTimestamp(),
      'passed': passed,
      'grade': grade,
    };
    await _firestore.collection('challenge_submissions').add(submission);

    // If passed, update user's progress
    if (passed) {
      final challengeDoc =
          await _firestore.collection('challenges').doc(challengeId).get();
      if (challengeDoc.exists) {
        final challenge = ChallengeModel.fromJson({
          'id': challengeDoc.id,
          ...challengeDoc.data() as Map<String, dynamic>,
        });

        // Get course ID from the challenge
        final courseId = challenge.courseId;
        if (courseId == null) {
          print('Challenge has no courseId, skipping progress update');
          return;
        }

        // Update course-specific progress
        final courseProgressDocId = '${user.uid}_$courseId';
        final courseProgressDoc = await _firestore
            .collection('progress')
            .doc(courseProgressDocId)
            .get();

        if (!courseProgressDoc.exists) {
          await _firestore.collection('progress').doc(courseProgressDocId).set({
            'userId': user.uid,
            'courseId': courseId,
            'currentLesson': challenge.lesson,
            'highestLesson': challenge.lesson,
            'completedChallenges': [challengeId],
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          final currentLesson = courseProgressDoc.data()?['currentLesson'] ?? 0;
          final highestLesson = courseProgressDoc.data()?['highestLesson'] ?? 0;
          final completedChallenges = List<String>.from(
              courseProgressDoc.data()?['completedChallenges'] ?? []);
          if (!completedChallenges.contains(challengeId)) {
            completedChallenges.add(challengeId);
          }
          await courseProgressDoc.reference.update({
            'currentLesson': max(currentLesson, challenge.lesson),
            'highestLesson': max(highestLesson, challenge.lesson),
            'completedChallenges': completedChallenges,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      }
    }
  }

  // Create test challenges
  Future<void> createTestChallenges() async {
    try {
      print('Starting to create test challenges...');

      final challenges = [
        {
          'title': 'Basic Python Quiz',
          'description': 'Test your knowledge of Python basics',
          'type': 'quiz',
          'difficulty': 'beginner',
          'lesson': 1,
          'isPublished': true,
          'createdAt': FieldValue.serverTimestamp(),
          'questions': [
            {
              'question': 'What is Python?',
              'options': [
                'A programming language',
                'A snake',
                'A game',
                'A database'
              ],
              'correctAnswer': 0
            },
            {
              'question':
                  'What is the correct way to create a variable in Python?',
              'options': ['var x = 5', 'x = 5', 'let x = 5', 'const x = 5'],
              'correctAnswer': 1
            }
          ],
          'passingScore': 70
        },
        {
          'title': 'JavaScript Coding Challenge',
          'description': 'Create a function that reverses a string',
          'type': 'coding',
          'difficulty': 'intermediate',
          'lesson': 2,
          'isPublished': true,
          'createdAt': FieldValue.serverTimestamp(),
          'instructions':
              'Write a function that takes a string as input and returns the reversed string.',
          'testCases': [
            {'input': '"hello"', 'expectedOutput': '"olleh"'},
            {'input': '"world"', 'expectedOutput': '"dlrow"'}
          ],
          'passingScore': 80
        },
        {
          'title': 'Build a Todo App',
          'description': 'Create a simple todo application using Flutter',
          'type': 'project',
          'difficulty': 'advanced',
          'lesson': 3,
          'isPublished': true,
          'createdAt': FieldValue.serverTimestamp(),
          'requirements': [
            'Create a new Flutter project',
            'Implement a todo list with add/delete functionality',
            'Add state management',
            'Include basic styling'
          ],
          'passingScore': 85
        }
      ];

      print('Attempting to create ${challenges.length} challenges...');

      for (var challenge in challenges) {
        try {
          print('Creating challenge: ${challenge['title']}');
          final docRef = _firestore.collection('challenges').doc();
          await docRef.set(challenge);
          print(
              'Successfully created challenge: ${challenge['title']} with ID: ${docRef.id}');
        } catch (e) {
          print('Error creating challenge ${challenge['title']}: $e');
          if (e is FirebaseException) {
            print('Firebase error code: ${e.code}');
            print('Firebase error message: ${e.message}');
          }
        }
      }

      print('Finished creating test challenges');
    } catch (e) {
      print('Error in createTestChallenges: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      rethrow;
    }
  }

  // Create test quiz challenge for debugging
  Future<void> createTestQuizChallenge() async {
    try {
      final testQuiz = {
        'id': 'test-quiz-${DateTime.now().millisecondsSinceEpoch}',
        'title': 'Test Quiz Challenge',
        'description': 'A test quiz to debug the quiz functionality',
        'teacherId': 'admin',
        'teacherName': 'Admin',
        'instructions': 'Answer all questions correctly',
        'testCases': [],
        'type': 'quiz',
        'difficulty': 'easy',
        'questions': ['What is 2+2?', 'What is the capital of France?'],
        'correctAnswers': ['4', 'Paris'],
        'createdBy': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isCompleted': false,
        'score': 0.0,
        'fileUrl': '',
        'fileName': '',
        'lesson': 1,
        'passingScore': 70.0,
        'deadline': null,
        'grade': null,
        'options': ['4', '5', '6', '7', 'Paris', 'London', 'Berlin', 'Madrid'],
        'blanks': [],
        'codeSnippet': '',
        'errorExplanation': '',
        'timeLimit': null,
        'isPublished': true,
        'courseId': null,
        'language': null,
        'quizQuestions': [
          {
            'question': 'What is 2+2?',
            'options': ['4', '5', '6', '7'],
            'correctAnswer': 0
          },
          {
            'question': 'What is the capital of France?',
            'options': ['Paris', 'London', 'Berlin', 'Madrid'],
            'correctAnswer': 0
          }
        ]
      };

      await _firestore
          .collection('challenges')
          .doc(testQuiz['id'] as String)
          .set(testQuiz);
      print('Test quiz challenge created with ID: ${testQuiz['id']}');
    } catch (e) {
      print('Error creating test quiz: $e');
    }
  }

  // Test function to debug error detection
  Future<void> testErrorDetection() async {
    print('=== TESTING ERROR DETECTION ===');

    final jdoodle = JDoodleService();

    // Test 1: Code with syntax error
    print('\n--- Test 1: Syntax Error ---');
    final syntaxErrorCode = '''
print("Hello World"
''';

    final result1 = await jdoodle.executeCode(
      script: syntaxErrorCode,
      language: 'python3',
      stdin: '',
      versionIndex: '0',
    );

    print('Syntax Error Result: $result1');

    // Test 2: Code with runtime error
    print('\n--- Test 2: Runtime Error ---');
    final runtimeErrorCode = '''
x = 10 / 0
print(x)
''';

    final result2 = await jdoodle.executeCode(
      script: runtimeErrorCode,
      language: 'python3',
      stdin: '',
      versionIndex: '0',
    );

    print('Runtime Error Result: $result2');

    // Test 3: Valid code
    print('\n--- Test 3: Valid Code ---');
    final validCode = '''
print("Hello World")
''';

    final result3 = await jdoodle.executeCode(
      script: validCode,
      language: 'python3',
      stdin: '',
      versionIndex: '0',
    );

    print('Valid Code Result: $result3');

    print('=== END ERROR DETECTION TEST ===');
  }

  Future<void> _updateProgress(String userId, String challengeId) async {
    try {
      // Get the challenge to find its course
      final challengeDoc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(challengeId)
          .get();

      if (!challengeDoc.exists) {
        print('Challenge not found for progress update');
        return;
      }

      final challengeData = challengeDoc.data()!;
      final courseId = challengeData['courseId'] as String?;

      if (courseId == null) {
        print('No courseId found for challenge');
        return;
      }

      // Update user progress
      final progressRef = FirebaseFirestore.instance
          .collection('user_progress')
          .doc('${userId}_$courseId');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final progressDoc = await transaction.get(progressRef);

        if (progressDoc.exists) {
          final currentData = progressDoc.data()!;
          final completedChallenges =
              List<String>.from(currentData['completedChallenges'] ?? []);

          if (!completedChallenges.contains(challengeId)) {
            completedChallenges.add(challengeId);
            transaction.update(progressRef, {
              'completedChallenges': completedChallenges,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
            print(
                'Progress updated: added challenge $challengeId to completed list');
          }
        } else {
          transaction.set(progressRef, {
            'userId': userId,
            'courseId': courseId,
            'completedChallenges': [challengeId],
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          print(
              'Progress created: new progress record with challenge $challengeId');
        }
      });
    } catch (e) {
      print('Error updating progress: $e');
    }
  }
}
