// lib/models/test_model.dart
// Models for the UPSC Test System

class TestModel {
  final String id;
  final String title;
  final String? description;
  final String subject;
  final String upscStage;       // 'Prelims' or 'Mains'
  final String stageCategory;   // e.g. 'Indian Polity'
  final int levelNumber;        // 1–100
  final int testNumber;
  final int totalQuestions;
  final int maxDurationMinutes;
  final double marksPerQuestion;
  final String? instructions;
  final bool isPublished;
  final bool isArchived;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TestModel({
    required this.id,
    required this.title,
    this.description,
    required this.subject,
    required this.upscStage,
    required this.stageCategory,
    required this.levelNumber,
    required this.testNumber,
    required this.totalQuestions,
    required this.maxDurationMinutes,
    required this.marksPerQuestion,
    this.instructions,
    required this.isPublished,
    required this.isArchived,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TestModel.fromJson(Map<String, dynamic> j) => TestModel(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        subject: j['subject'] as String,
        upscStage: j['upsc_stage'] as String? ?? 'Prelims',
        stageCategory: j['stage_category'] as String? ?? '',
        levelNumber: (j['level_number'] as num).toInt(),
        testNumber: (j['test_number'] as num? ?? 1).toInt(),
        totalQuestions: (j['total_questions'] as num).toInt(),
        maxDurationMinutes: (j['max_duration_minutes'] as num).toInt(),
        marksPerQuestion: (j['marks_per_question'] as num? ?? 2).toDouble(),
        instructions: j['instructions'] as String?,
        isPublished: j['is_published'] as bool? ?? false,
        isArchived: j['is_archived'] as bool? ?? false,
        createdBy: j['created_by'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'subject': subject,
        'upsc_stage': upscStage,
        'stage_category': stageCategory,
        'level_number': levelNumber,
        'test_number': testNumber,
        'total_questions': totalQuestions,
        'max_duration_minutes': maxDurationMinutes,
        'marks_per_question': marksPerQuestion,
        'instructions': instructions,
        'is_published': isPublished,
        'is_archived': isArchived,
      };

  TestModel copyWith({
    String? title,
    String? description,
    String? subject,
    String? upscStage,
    String? stageCategory,
    int? levelNumber,
    int? testNumber,
    int? totalQuestions,
    int? maxDurationMinutes,
    double? marksPerQuestion,
    String? instructions,
    bool? isPublished,
    bool? isArchived,
  }) =>
      TestModel(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        subject: subject ?? this.subject,
        upscStage: upscStage ?? this.upscStage,
        stageCategory: stageCategory ?? this.stageCategory,
        levelNumber: levelNumber ?? this.levelNumber,
        testNumber: testNumber ?? this.testNumber,
        totalQuestions: totalQuestions ?? this.totalQuestions,
        maxDurationMinutes: maxDurationMinutes ?? this.maxDurationMinutes,
        marksPerQuestion: marksPerQuestion ?? this.marksPerQuestion,
        instructions: instructions ?? this.instructions,
        isPublished: isPublished ?? this.isPublished,
        isArchived: isArchived ?? this.isArchived,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

// ─────────────────────────────────────────────

class TestQuestion {
  final String id;
  final String testId;
  final int questionNumber;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String? correctOption;    // null during active attempt (view hides it)
  final String? explanation;      // null during active attempt
  final double? marks;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TestQuestion({
    required this.id,
    required this.testId,
    required this.questionNumber,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    this.correctOption,
    this.explanation,
    this.marks,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TestQuestion.fromJson(Map<String, dynamic> j) => TestQuestion(
        id: j['id'] as String,
        testId: j['test_id'] as String,
        questionNumber: (j['question_number'] as num).toInt(),
        questionText: j['question_text'] as String,
        optionA: j['option_a'] as String,
        optionB: j['option_b'] as String,
        optionC: j['option_c'] as String,
        optionD: j['option_d'] as String,
        correctOption: j['correct_option'] as String?,
        explanation: j['explanation'] as String?,
        marks: (j['marks'] as num?)?.toDouble(),
        createdAt: DateTime.parse(
            j['created_at'] as String? ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(
            j['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toJson() => {
        'test_id': testId,
        'question_number': questionNumber,
        'question_text': questionText,
        'option_a': optionA,
        'option_b': optionB,
        'option_c': optionC,
        'option_d': optionD,
        'correct_option': correctOption,
        'explanation': explanation ?? '',
        'marks': marks,
      };
}

// ─────────────────────────────────────────────

class TestAttempt {
  final String id;
  final String testId;
  final String studentId;
  final int attemptNumber;
  final int selectedDurationMinutes;
  final DateTime startedAt;
  final DateTime deadlineAt;
  final DateTime? submittedAt;
  final bool isSubmitted;
  final int totalQuestions;
  final int? correctCount;
  final int? incorrectCount;
  final int? unansweredCount;
  final double? marksObtained;
  final double? negativeMarks;
  final double? maxMarks;
  final double? percentage;
  final int starsEarned;
  final DateTime createdAt;

  const TestAttempt({
    required this.id,
    required this.testId,
    required this.studentId,
    required this.attemptNumber,
    required this.selectedDurationMinutes,
    required this.startedAt,
    required this.deadlineAt,
    this.submittedAt,
    required this.isSubmitted,
    required this.totalQuestions,
    this.correctCount,
    this.incorrectCount,
    this.unansweredCount,
    this.marksObtained,
    this.negativeMarks,
    this.maxMarks,
    this.percentage,
    required this.starsEarned,
    required this.createdAt,
  });

  factory TestAttempt.fromJson(Map<String, dynamic> j) => TestAttempt(
        id: j['id'] as String,
        testId: j['test_id'] as String,
        studentId: j['student_id'] as String,
        attemptNumber: (j['attempt_number'] as num).toInt(),
        selectedDurationMinutes: (j['selected_duration_minutes'] as num).toInt(),
        startedAt: DateTime.parse(j['started_at'] as String),
        deadlineAt: DateTime.parse(j['deadline_at'] as String),
        submittedAt: j['submitted_at'] != null
            ? DateTime.parse(j['submitted_at'] as String)
            : null,
        isSubmitted: j['is_submitted'] as bool? ?? false,
        totalQuestions: (j['total_questions'] as num).toInt(),
        correctCount: (j['correct_count'] as num?)?.toInt(),
        incorrectCount: (j['incorrect_count'] as num?)?.toInt(),
        unansweredCount: (j['unanswered_count'] as num?)?.toInt(),
        marksObtained: (j['marks_obtained'] as num?)?.toDouble(),
        negativeMarks: (j['negative_marks'] as num?)?.toDouble(),
        maxMarks: (j['max_marks'] as num?)?.toDouble(),
        percentage: (j['percentage'] as num?)?.toDouble(),
        starsEarned: (j['stars_earned'] as num? ?? 0).toInt(),
        createdAt: j['created_at'] != null
            ? DateTime.parse(j['created_at'] as String)
            : DateTime.now(),
      );
}

// ─────────────────────────────────────────────

class TestAnswer {
  final String id;
  final String attemptId;
  final String questionId;
  final String? selectedOption;
  final bool isMarkedForReview;
  final DateTime updatedAt;

  const TestAnswer({
    required this.id,
    required this.attemptId,
    required this.questionId,
    this.selectedOption,
    required this.isMarkedForReview,
    required this.updatedAt,
  });

  factory TestAnswer.fromJson(Map<String, dynamic> j) => TestAnswer(
        id: j['id'] as String,
        attemptId: j['attempt_id'] as String,
        questionId: j['question_id'] as String,
        selectedOption: j['selected_option'] as String?,
        isMarkedForReview: j['is_marked_for_review'] as bool? ?? false,
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}

// ─────────────────────────────────────────────

class StudentLevelProgress {
  final String id;
  final String studentId;
  final String testId;
  final int levelNumber;
  final bool isUnlocked;
  final bool isCompleted;
  final int bestStars;
  final double? bestScore;
  final String? bestAttemptId;
  final DateTime updatedAt;

  const StudentLevelProgress({
    required this.id,
    required this.studentId,
    required this.testId,
    required this.levelNumber,
    required this.isUnlocked,
    required this.isCompleted,
    required this.bestStars,
    this.bestScore,
    this.bestAttemptId,
    required this.updatedAt,
  });

  factory StudentLevelProgress.fromJson(Map<String, dynamic> j) =>
      StudentLevelProgress(
        id: j['id'] as String,
        studentId: j['student_id'] as String,
        testId: j['test_id'] as String,
        levelNumber: (j['level_number'] as num).toInt(),
        isUnlocked: j['is_unlocked'] as bool? ?? false,
        isCompleted: j['is_completed'] as bool? ?? false,
        bestStars: (j['best_stars'] as num? ?? 0).toInt(),
        bestScore: (j['best_score'] as num?)?.toDouble(),
        bestAttemptId: j['best_attempt_id'] as String?,
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}

// ─────────────────────────────────────────────
// Stage metadata for the Destination map
// ─────────────────────────────────────────────
class StageInfo {
  final int stageNumber;    // 1–10
  final String name;
  final String icon;        // emoji
  final int startLevel;     // 1,11,21,...
  final int endLevel;       // 10,20,30,...

  const StageInfo({
    required this.stageNumber,
    required this.name,
    required this.icon,
    required this.startLevel,
    required this.endLevel,
  });
}

const List<StageInfo> kStages = [
  StageInfo(stageNumber: 1, name: 'Indian Polity', icon: '⚖️', startLevel: 1, endLevel: 10),
  StageInfo(stageNumber: 2, name: 'Indian History', icon: '🏛️', startLevel: 11, endLevel: 20),
  StageInfo(stageNumber: 3, name: 'Indian Geography', icon: '🗺️', startLevel: 21, endLevel: 30),
  StageInfo(stageNumber: 4, name: 'Indian Economy', icon: '📈', startLevel: 31, endLevel: 40),
  StageInfo(stageNumber: 5, name: 'General Science', icon: '🔬', startLevel: 41, endLevel: 50),
  StageInfo(stageNumber: 6, name: 'Environment & Ecology', icon: '🌿', startLevel: 51, endLevel: 60),
  StageInfo(stageNumber: 7, name: 'Current Affairs', icon: '📰', startLevel: 61, endLevel: 70),
  StageInfo(stageNumber: 8, name: 'Art & Culture', icon: '🎨', startLevel: 71, endLevel: 80),
  StageInfo(stageNumber: 9, name: 'International Relations', icon: '🌐', startLevel: 81, endLevel: 90),
  StageInfo(stageNumber: 10, name: 'CSAT & Reasoning', icon: '🧮', startLevel: 91, endLevel: 100),
];

StageInfo stageForLevel(int level) {
  return kStages.firstWhere(
    (s) => level >= s.startLevel && level <= s.endLevel,
    orElse: () => kStages.first,
  );
}
