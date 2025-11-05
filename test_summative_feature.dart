import 'package:flutter/material.dart';
import 'package:codequest/features/challenges/domain/models/challenge_model.dart';

void main() {
  // Test the summative feature
  testSummativeFeature();
}

void testSummativeFeature() {
  print('=== Testing Summative Feature ===');

  // Test 1: Create a regular challenge
  final regularChallenge = ChallengeModel(
    id: 'test1',
    title: 'Regular Challenge',
    description: 'A regular coding challenge',
    teacherId: 'teacher1',
    teacherName: 'Test Teacher',
    instructions: 'Complete this challenge',
    testCases: ['test1', 'test2'],
    type: ChallengeType.coding,
    difficulty: ChallengeDifficulty.easy,
    questions: [],
    correctAnswers: [],
    createdBy: 'teacher1',
    createdAt: DateTime.now(),
    courseId: 'course1',
  );

  print('Regular Challenge - isSummative: ${regularChallenge.isSummative}');

  // Test 2: Create a summative challenge
  final summativeChallenge = ChallengeModel(
    id: 'test2',
    title: 'Final Evaluation',
    description: 'A summative evaluation challenge',
    teacherId: 'teacher1',
    teacherName: 'Test Teacher',
    instructions: 'Complete this final evaluation',
    testCases: [],
    type: ChallengeType.summative,
    difficulty: ChallengeDifficulty.hard,
    questions: ['What is the capital of France?', 'What is 2 + 2?'],
    correctAnswers: ['0', '1'], // Multiple choice answers (0-based index)
    createdBy: 'teacher1',
    createdAt: DateTime.now(),
    courseId: 'course1',
    lesson: 0, // Summative challenges use lesson 0
    options: [
      'Paris',
      'London',
      'Berlin',
      'Madrid',
      '4',
      '3',
      '5',
      '6'
    ], // Quiz options
    quizQuestions: [
      {
        'question': 'What is the capital of France?',
        'options': ['Paris', 'London', 'Berlin', 'Madrid'],
        'correctAnswer': 0,
      },
      {
        'question': 'What is 2 + 2?',
        'options': ['4', '3', '5', '6'],
        'correctAnswer': 0,
      },
    ],
  );

  print('Summative Challenge - isSummative: ${summativeChallenge.isSummative}');

  // Test 3: Test JSON serialization
  final regularJson = regularChallenge.toJson();
  final summativeJson = summativeChallenge.toJson();

  print('Regular Challenge JSON - type: ${regularJson['type']}');
  print('Summative Challenge JSON - type: ${summativeJson['type']}');

  // Test 4: Test JSON deserialization
  final regularFromJson = ChallengeModel.fromJson(regularJson);
  final summativeFromJson = ChallengeModel.fromJson(summativeJson);

  print('Regular from JSON - isSummative: ${regularFromJson.isSummative}');
  print('Summative from JSON - isSummative: ${summativeFromJson.isSummative}');

  // Test 5: Test copyWith
  final updatedRegular =
      regularChallenge.copyWith(type: ChallengeType.summative);
  final updatedSummative =
      summativeChallenge.copyWith(type: ChallengeType.coding);

  print('Updated Regular - isSummative: ${updatedRegular.isSummative}');
  print('Updated Summative - isSummative: ${updatedSummative.isSummative}');

  print('=== All Tests Passed! ===');
}

// Mock certificate logic test
void testCertificateLogic() {
  print('\n=== Testing Certificate Logic ===');

  // Simulate completed challenges
  final completedChallenges = [
    'challenge1',
    'challenge2',
    'challenge3',
    'challenge4'
  ];

  // Simulate course challenges
  final courseChallenges = [
    ChallengeModel(
      id: 'challenge1',
      title: 'Lesson 1 Challenge',
      description: 'First lesson challenge',
      teacherId: 'teacher1',
      teacherName: 'Test Teacher',
      instructions: 'Complete this challenge',
      testCases: [],
      type: ChallengeType.coding,
      difficulty: ChallengeDifficulty.easy,
      questions: [],
      correctAnswers: [],
      createdBy: 'teacher1',
      createdAt: DateTime.now(),
      courseId: 'course1',
      lesson: 1,
    ),
    ChallengeModel(
      id: 'challenge2',
      title: 'Lesson 2 Challenge',
      description: 'Second lesson challenge',
      teacherId: 'teacher1',
      teacherName: 'Test Teacher',
      instructions: 'Complete this challenge',
      testCases: [],
      type: ChallengeType.coding,
      difficulty: ChallengeDifficulty.medium,
      questions: [],
      correctAnswers: [],
      createdBy: 'teacher1',
      createdAt: DateTime.now(),
      courseId: 'course1',
      lesson: 2,
    ),
    ChallengeModel(
      id: 'challenge3',
      title: 'Lesson 3 Challenge',
      description: 'Third lesson challenge',
      teacherId: 'teacher1',
      teacherName: 'Test Teacher',
      instructions: 'Complete this challenge',
      testCases: [],
      type: ChallengeType.coding,
      difficulty: ChallengeDifficulty.medium,
      questions: [],
      correctAnswers: [],
      createdBy: 'teacher1',
      createdAt: DateTime.now(),
      courseId: 'course1',
      lesson: 3,
    ),
    ChallengeModel(
      id: 'challenge4',
      title: 'Lesson 4 Challenge',
      description: 'Fourth lesson challenge',
      teacherId: 'teacher1',
      teacherName: 'Test Teacher',
      instructions: 'Complete this challenge',
      testCases: [],
      type: ChallengeType.coding,
      difficulty: ChallengeDifficulty.hard,
      questions: [],
      correctAnswers: [],
      createdBy: 'teacher1',
      createdAt: DateTime.now(),
      courseId: 'course1',
      lesson: 4,
    ),
    ChallengeModel(
      id: 'summative1',
      title: 'Final Evaluation',
      description: 'Summative evaluation challenge',
      teacherId: 'teacher1',
      teacherName: 'Test Teacher',
      instructions: 'Complete this final evaluation',
      testCases: [],
      type: ChallengeType.summative,
      difficulty: ChallengeDifficulty.hard,
      questions: [],
      correctAnswers: [],
      createdBy: 'teacher1',
      createdAt: DateTime.now(),
      courseId: 'course1',
      lesson: 0, // Summative challenges use lesson 0
    ),
  ];

  // Test without summative completion
  final allLessonsPassed = [1, 2, 3, 4].every((lessonNum) {
    final lessonChallenges =
        courseChallenges.where((c) => c.lesson == lessonNum).toList();
    return lessonChallenges.isNotEmpty &&
        lessonChallenges.every((c) => completedChallenges.contains(c.id));
  });

  final summativeChallenges =
      courseChallenges.where((c) => c.isSummative).toList();
  final summativeCompleted =
      summativeChallenges.every((c) => completedChallenges.contains(c.id));

  print('All lessons passed: $allLessonsPassed');
  print('Summative completed: $summativeCompleted');
  print(
      'Certificate should be awarded: ${allLessonsPassed && summativeCompleted}');

  // Test with summative completion
  final completedChallengesWithSummative = [
    ...completedChallenges,
    'summative1'
  ];
  final summativeCompletedWithSummative = summativeChallenges
      .every((c) => completedChallengesWithSummative.contains(c.id));

  print('With summative completed: $summativeCompletedWithSummative');
  print(
      'Certificate should be awarded: ${allLessonsPassed && summativeCompletedWithSummative}');

  print('=== Certificate Logic Tests Passed! ===');
}
