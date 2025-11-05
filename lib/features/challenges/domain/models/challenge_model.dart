import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ChallengeType { coding, quiz, fillInTheBlank, summative }

enum ChallengeDifficulty { easy, medium, hard }

class ChallengeModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final String teacherId;
  final String teacherName;
  final String instructions;
  final List<String>
      testCases; // Optional: If empty, code will be evaluated based on execution (pass if no errors, fail if errors)
  final ChallengeType type;
  final ChallengeDifficulty difficulty;
  final int? difficultyLevel; // 1-5 numeric difficulty level for UI
  final List<String> questions;
  final List<String> correctAnswers;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isCompleted;
  final double score;
  final String? fileUrl;
  final String? fileName;
  final int lesson;
  final double passingScore;
  final DateTime? deadline;
  final double? grade;
  final List<String>? options;
  final List<String>? blanks;
  final String? codeSnippet;
  final String? errorExplanation;
  final int? timeLimit; // in minutes
  final bool isPublished;
  final String? courseId;
  final String? language;
  final List<Map<String, dynamic>>? quizQuestions; // For structured quiz data
  final List<Map<String, dynamic>>?
      fillBlankQuestions; // For structured fill-in-the-blank data
  final List<Map<String, dynamic>>?
      codingProblems; // For structured coding problems data

  const ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.teacherId,
    required this.teacherName,
    required this.instructions,
    required this.testCases,
    required this.type,
    required this.difficulty,
    this.difficultyLevel,
    required this.questions,
    required this.correctAnswers,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.isCompleted = false,
    this.score = 0.0,
    this.fileUrl,
    this.fileName,
    this.lesson = 1,
    this.passingScore = 70.0,
    this.deadline,
    this.grade,
    this.options,
    this.blanks,
    this.codeSnippet,
    this.errorExplanation,
    this.timeLimit,
    this.isPublished = true,
    this.courseId,
    this.language,
    this.quizQuestions,
    this.fillBlankQuestions,
    this.codingProblems,
  });

  // Helper getter to check if challenge is summative
  bool get isSummative => type == ChallengeType.summative;

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        teacherId,
        teacherName,
        instructions,
        testCases,
        type,
        difficulty,
        difficultyLevel,
        questions,
        correctAnswers,
        createdBy,
        createdAt,
        updatedAt,
        isCompleted,
        score,
        fileUrl,
        fileName,
        lesson,
        passingScore,
        deadline,
        grade,
        options,
        blanks,
        codeSnippet,
        errorExplanation,
        timeLimit,
        isPublished,
        courseId,
        language,
        quizQuestions,
        fillBlankQuestions,
        codingProblems,
      ];

  Map<String, dynamic> toJson() {
    final json = {
      'title': title,
      'description': description,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'instructions': instructions,
      'testCases': testCases,
      'type': type.toString().split('.').last,
      'difficulty': difficulty.toString().split('.').last,
      'difficultyLevel': difficultyLevel,
      'questions': questions,
      'correctAnswers': correctAnswers,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isCompleted': isCompleted,
      'score': score,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'lesson': lesson,
      'passingScore': passingScore,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'grade': grade,
      'options': options,
      'blanks': blanks,
      'codeSnippet': codeSnippet,
      'errorExplanation': errorExplanation,
      'timeLimit': timeLimit,
      'isPublished': isPublished,
      'courseId': courseId,
      'language': language,
      'quizQuestions': quizQuestions,
      'fillBlankQuestions': fillBlankQuestions,
      'codingProblems': codingProblems,
    };

    print('Converting challenge to JSON:');
    print('Original challenge: $this');
    print('JSON data: $json');

    return json;
  }

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    return ChallengeModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      teacherId: json['teacherId'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
      testCases: (json['testCases'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      type: json['type'] != null &&
              ChallengeType.values
                  .any((e) => e.toString() == 'ChallengeType.${json['type']}')
          ? ChallengeType.values.firstWhere(
              (e) => e.toString() == 'ChallengeType.${json['type']}')
          : ChallengeType.coding,
      difficulty: json['difficulty'] != null &&
              ChallengeDifficulty.values.any((e) =>
                  e.toString() == 'ChallengeDifficulty.${json['difficulty']}')
          ? ChallengeDifficulty.values.firstWhere((e) =>
              e.toString() == 'ChallengeDifficulty.${json['difficulty']}')
          : ChallengeDifficulty.easy,
      difficultyLevel: (json['difficultyLevel'] as num?)?.toInt(),
      questions: (json['questions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      correctAnswers: (json['correctAnswers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : (json['createdAt'] is String && json['createdAt'] != ''
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now()),
      updatedAt: json['updatedAt'] == null
          ? null
          : (json['updatedAt'] is Timestamp
              ? (json['updatedAt'] as Timestamp).toDate()
              : (json['updatedAt'] is String && json['updatedAt'] != ''
                  ? DateTime.parse(json['updatedAt'] as String)
                  : null)),
      isCompleted: json['isCompleted'] as bool? ?? false,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      fileUrl: json['fileUrl'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      lesson: (() {
        final value = json['lesson'];
        if (value == null) return 1;
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) return int.tryParse(value) ?? 1;
        return 1;
      })(),
      passingScore: (json['passingScore'] as num?)?.toDouble() ?? 70.0,
      deadline: json['deadline'] == null
          ? null
          : (json['deadline'] is Timestamp
              ? (json['deadline'] as Timestamp).toDate()
              : (json['deadline'] is String && json['deadline'] != ''
                  ? DateTime.parse(json['deadline'] as String)
                  : null)),
      grade: (json['grade'] as num?)?.toDouble(),
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      blanks: (json['blanks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      codeSnippet: json['codeSnippet'] as String? ?? '',
      errorExplanation: json['errorExplanation'] as String? ?? '',
      timeLimit: json['timeLimit'] as int?,
      isPublished: json['isPublished'] as bool? ?? true,
      courseId: json['courseId'] as String?,
      language: json['language'] as String?,
      quizQuestions: (json['quizQuestions'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          null,
      fillBlankQuestions: (json['fillBlankQuestions'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          null,
      codingProblems: (json['codingProblems'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          null,
    );
  }

  ChallengeModel copyWith({
    String? id,
    String? title,
    String? description,
    String? teacherId,
    String? teacherName,
    String? instructions,
    List<String>? testCases,
    ChallengeType? type,
    ChallengeDifficulty? difficulty,
    int? difficultyLevel,
    List<String>? questions,
    List<String>? correctAnswers,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCompleted,
    double? score,
    String? fileUrl,
    String? fileName,
    int? lesson,
    double? passingScore,
    DateTime? deadline,
    double? grade,
    List<String>? options,
    List<String>? blanks,
    String? codeSnippet,
    String? errorExplanation,
    int? timeLimit,
    bool? isPublished,
    String? courseId,
    String? language,
    List<Map<String, dynamic>>? quizQuestions,
    List<Map<String, dynamic>>? fillBlankQuestions,
    List<Map<String, dynamic>>? codingProblems,
  }) {
    return ChallengeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      instructions: instructions ?? this.instructions,
      testCases: testCases ?? this.testCases,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      questions: questions ?? this.questions,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      score: score ?? this.score,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      lesson: lesson ?? this.lesson,
      passingScore: passingScore ?? this.passingScore,
      deadline: deadline ?? this.deadline,
      grade: grade ?? this.grade,
      options: options ?? this.options,
      blanks: blanks ?? this.blanks,
      codeSnippet: codeSnippet ?? this.codeSnippet,
      errorExplanation: errorExplanation ?? this.errorExplanation,
      timeLimit: timeLimit ?? this.timeLimit,
      isPublished: isPublished ?? this.isPublished,
      courseId: courseId ?? this.courseId,
      language: language ?? this.language,
      quizQuestions: quizQuestions ?? this.quizQuestions,
      fillBlankQuestions: fillBlankQuestions ?? this.fillBlankQuestions,
      codingProblems: codingProblems ?? this.codingProblems,
    );
  }
}
