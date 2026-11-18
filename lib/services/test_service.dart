import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../models/test_model.dart';
import 'streak_service.dart';

class TestService {
  final _db = Supabase.instance.client;

  // ──────────────────────────────────────────
  // ADMIN: Tests CRUD
  // ──────────────────────────────────────────

  Future<List<TestModel>> fetchAllTests({
    String? searchQuery,
    String? upscStage,
    String? subject,
    String? stageCategory,
    bool? isPublished,
  }) async {
    var query = _db.from('tests').select().eq('is_archived', false);

    if (upscStage != null && upscStage.isNotEmpty) {
      query = query.eq('upsc_stage', upscStage);
    }
    if (subject != null && subject.isNotEmpty) {
      query = query.eq('subject', subject);
    }
    if (stageCategory != null && stageCategory.isNotEmpty) {
      query = query.eq('stage_category', stageCategory);
    }
    if (isPublished != null) {
      query = query.eq('is_published', isPublished);
    }

    final raw = await query.order('level_number').order('test_number');
    var list = (raw as List)
        .map((j) => TestModel.fromJson(j as Map<String, dynamic>))
        .toList();

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list
          .where(
            (t) =>
                t.title.toLowerCase().contains(q) ||
                t.subject.toLowerCase().contains(q) ||
                t.stageCategory.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  Future<TestModel> createTest(Map<String, dynamic> data) async {
    final userId = _db.auth.currentUser?.id;
    final row = await _db
        .from('tests')
        .insert({
          ...data,
          'created_by': userId,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return TestModel.fromJson(row);
  }

  Future<TestModel> updateTest(String testId, Map<String, dynamic> data) async {
    final row = await _db
        .from('tests')
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', testId)
        .select()
        .single();
    return TestModel.fromJson(row);
  }

  Future<TestModel> fetchTestById(String testId) async {
    final row = await _db.from('tests').select().eq('id', testId).single();
    return TestModel.fromJson(row);
  }

  Future<bool> hasAttempts(String testId) async {
    try {
      final rows = await _db
          .from('test_attempts')
          .select('id')
          .eq('test_id', testId)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> setPublished(String testId, bool published) async {
    try {
      if (published) {
        final qs = await _db
            .from('test_questions')
            .select('id')
            .eq('test_id', testId);
        final count = (qs as List).length;
        if (count == 0) {
          throw Exception(
            'Cannot publish: This test has 0 questions. Please add at least 1 question first.',
          );
        }

        await _db
            .from('tests')
            .update({
              'total_questions': count,
              'is_published': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', testId);
      } else {
        await _db
            .from('tests')
            .update({
              'is_published': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', testId);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> archiveTest(String testId) async {
    await _db
        .from('tests')
        .update({
          'is_archived': true,
          'is_published': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', testId);
  }

  // ──────────────────────────────────────────
  // ADMIN: Questions CRUD
  // ──────────────────────────────────────────

  Future<List<TestQuestion>> fetchQuestions(String testId) async {
    final raw = await _db
        .from('test_questions')
        .select()
        .eq('test_id', testId)
        .order('question_number');
    return (raw as List)
        .map((j) => TestQuestion.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<TestQuestion> createQuestion(Map<String, dynamic> data) async {
    final row = await _db
        .from('test_questions')
        .insert({...data, 'updated_at': DateTime.now().toIso8601String()})
        .select()
        .single();

    final testId = data['test_id']?.toString();
    if (testId != null) {
      try {
        final qs = await _db
            .from('test_questions')
            .select('id')
            .eq('test_id', testId);
        final count = (qs as List).length;
        await _db
            .from('tests')
            .update({
              'total_questions': count,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', testId);
      } catch (_) {}
    }

    return TestQuestion.fromJson(row);
  }

  Future<TestQuestion> updateQuestion(
    String questionId,
    Map<String, dynamic> data,
  ) async {
    final row = await _db
        .from('test_questions')
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', questionId)
        .select()
        .single();
    return TestQuestion.fromJson(row);
  }

  Future<void> deleteQuestion(String questionId, {String? testId}) async {
    String? tId = testId;
    if (tId == null) {
      try {
        final qRow = await _db
            .from('test_questions')
            .select('test_id')
            .eq('id', questionId)
            .maybeSingle();
        if (qRow != null) {
          tId = qRow['test_id']?.toString();
        }
      } catch (_) {}
    }

    await _db.from('test_questions').delete().eq('id', questionId);

    if (tId != null) {
      try {
        final qs = await _db
            .from('test_questions')
            .select('id')
            .eq('test_id', tId);
        final count = (qs as List).length;
        await _db
            .from('tests')
            .update({
              'total_questions': count > 0 ? count : 1,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', tId);
      } catch (_) {}
    }
  }

  Future<void> reorderQuestions(String testId, List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await _db
          .from('test_questions')
          .update({
            'question_number': i + 1,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderedIds[i]);
    }
  }

  // ──────────────────────────────────────────
  // ADMIN: Stats
  // ──────────────────────────────────────────

  Future<Map<String, int>> fetchAdminStats() async {
    final total = await _db.from('tests').select('id').eq('is_archived', false);
    final published = await _db
        .from('tests')
        .select('id')
        .eq('is_archived', false)
        .eq('is_published', true);
    final unpublished = await _db
        .from('tests')
        .select('id')
        .eq('is_archived', false)
        .eq('is_published', false);
    return {
      'total': (total as List).length,
      'published': (published as List).length,
      'unpublished': (unpublished as List).length,
    };
  }

  Future<Map<String, dynamic>> fetchTestAnalytics(String testId) async {
    final rawAttempts = await _db
        .from('test_attempts')
        .select(
          'id, student_id, percentage, marks_obtained, max_marks, correct_count, incorrect_count, unanswered_count, is_submitted, submitted_at, total_questions',
        )
        .eq('test_id', testId);

    final attempts = (rawAttempts as List).cast<Map<String, dynamic>>();
    if (attempts.isEmpty) {
      return {
        'totalAttempts': 0,
        'uniqueStudents': 0,
        'completionRate': 0.0,
        'avgScore': 0.0,
        'highestScore': 0.0,
        'lowestScore': 0.0,
        'correctPct': 0.0,
        'incorrectPct': 0.0,
        'unansweredPct': 0.0,
        'questions': <Map<String, dynamic>>[],
      };
    }

    final uniqueStudents = attempts
        .map((a) => a['student_id']?.toString())
        .whereType<String>()
        .toSet()
        .length;
    final submitted = attempts.where((a) => a['is_submitted'] == true).toList();
    final completionRate = attempts.isNotEmpty
        ? (submitted.length / attempts.length) * 100
        : 0.0;

    double avgScore = 0.0;
    double highestScore = 0.0;
    double lowestScore = 0.0;
    double correctPct = 0.0;
    double incorrectPct = 0.0;
    double unansweredPct = 0.0;

    if (submitted.isNotEmpty) {
      final percentages = submitted
          .map((a) => (a['percentage'] as num?)?.toDouble() ?? 0.0)
          .toList();
      highestScore = percentages.reduce((a, b) => a > b ? a : b);
      lowestScore = percentages.reduce((a, b) => a < b ? a : b);
      avgScore = percentages.reduce((a, b) => a + b) / percentages.length;

      int totalC = 0;
      int totalI = 0;
      int totalU = 0;
      int totalQ = 0;

      for (final a in submitted) {
        final c = (a['correct_count'] as num?)?.toInt() ?? 0;
        final i = (a['incorrect_count'] as num?)?.toInt() ?? 0;
        final u = (a['unanswered_count'] as num?)?.toInt() ?? 0;
        totalC += c;
        totalI += i;
        totalU += u;
        totalQ += c + i + u;
      }

      if (totalQ > 0) {
        correctPct = (totalC / totalQ) * 100;
        incorrectPct = (totalI / totalQ) * 100;
        unansweredPct = (totalU / totalQ) * 100;
      }
    }

    final questions = await fetchQuestions(testId);
    final questionStats = <Map<String, dynamic>>[];

    if (submitted.isNotEmpty && questions.isNotEmpty) {
      final attemptIds = submitted
          .map((a) => a['id']?.toString())
          .whereType<String>()
          .toList();
      final rawAnswers = await _db
          .from('test_answers')
          .select('question_id, selected_option')
          .inFilter('attempt_id', attemptIds);

      final answersList = (rawAnswers as List).cast<Map<String, dynamic>>();

      for (final q in questions) {
        final qAnswers = answersList
            .where((ans) => ans['question_id'] == q.id)
            .toList();
        int qCorrect = 0;
        int qIncorrect = 0;
        int qSkipped = 0;

        for (final ans in qAnswers) {
          final opt = ans['selected_option']?.toString();
          if (opt == null || opt.isEmpty) {
            qSkipped++;
          } else if (opt == q.correctOption) {
            qCorrect++;
          } else {
            qIncorrect++;
          }
        }

        final unrecorded = submitted.length - qAnswers.length;
        if (unrecorded > 0) {
          qSkipped += unrecorded;
        }

        final totalResponses = submitted.length;
        final qAccuracy = totalResponses > 0
            ? (qCorrect / totalResponses) * 100
            : 0.0;

        questionStats.add({
          'questionNumber': q.questionNumber,
          'questionText': q.questionText,
          'correct': qCorrect,
          'incorrect': qIncorrect,
          'skipped': qSkipped,
          'accuracy': qAccuracy,
        });
      }
    }

    return {
      'totalAttempts': attempts.length,
      'submittedAttempts': submitted.length,
      'uniqueStudents': uniqueStudents,
      'completionRate': completionRate,
      'avgScore': avgScore,
      'highestScore': highestScore,
      'lowestScore': lowestScore,
      'correctPct': correctPct,
      'incorrectPct': incorrectPct,
      'unansweredPct': unansweredPct,
      'questions': questionStats,
    };
  }

  // ──────────────────────────────────────────
  // STUDENT: Published tests
  // ──────────────────────────────────────────

  Future<List<TestModel>> fetchPublishedTests() async {
    final raw = await _db
        .from('tests')
        .select()
        .eq('is_published', true)
        .eq('is_archived', false)
        .order('level_number')
        .order('test_number');
    return (raw as List)
        .map((j) => TestModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ──────────────────────────────────────────
  // STUDENT: Level progress
  // ──────────────────────────────────────────

  Future<List<StudentLevelProgress>> fetchMyProgress() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];
    final raw = await _db
        .from('student_level_progress')
        .select()
        .eq('student_id', userId);
    return (raw as List)
        .map((j) => StudentLevelProgress.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ──────────────────────────────────────────
  // STUDENT: Start attempt
  // ──────────────────────────────────────────

  Future<TestAttempt> startAttempt(String testId, int durationMinutes) async {
    try {
      final row = await _db.rpc(
        'start_test_attempt',
        params: {'p_test_id': testId, 'p_duration_minutes': durationMinutes},
      );
      return TestAttempt.fromJson(row as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Could not start examination: $e');
    }
  }

  // ──────────────────────────────────────────
  // STUDENT: Fetch questions during active attempt
  // ──────────────────────────────────────────

  Future<List<TestQuestion>> fetchQuestionsForAttempt(String attemptId) async {
    try {
      final raw = await _db.rpc(
        'get_active_attempt_questions',
        params: {'p_attempt_id': attemptId},
      );
      return (raw as List)
          .map((j) => TestQuestion.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Could not load examination questions: $e');
    }
  }

  // ──────────────────────────────────────────
  // STUDENT: Save/update a single answer
  // ──────────────────────────────────────────

  Future<void> saveAnswer({
    required String attemptId,
    required String questionId,
    String? selectedOption,
    bool isMarkedForReview = false,
  }) async {
    try {
      await _db.rpc(
        'save_test_answer',
        params: {
          'p_attempt_id': attemptId,
          'p_question_id': questionId,
          'p_selected_option': selectedOption,
          'p_is_marked_for_review': isMarkedForReview,
        },
      );
    } catch (e) {
      throw Exception('Could not save answer: $e');
    }
  }

  // ──────────────────────────────────────────
  // STUDENT: Fetch existing answers
  // ──────────────────────────────────────────

  Future<Map<String, TestAnswer>> fetchAnswers(String attemptId) async {
    final raw = await _db
        .from('test_answers')
        .select()
        .eq('attempt_id', attemptId);
    return {
      for (final j in (raw as List))
        (j['question_id'] as String): TestAnswer.fromJson(
          j as Map<String, dynamic>,
        ),
    };
  }

  // ──────────────────────────────────────────
  // STUDENT: Submit
  // ──────────────────────────────────────────

  Future<Map<String, dynamic>> submitAttempt(String attemptId) async {
    try {
      final result = await _db.rpc(
        'submit_test_attempt',
        params: {'p_attempt_id': attemptId},
      );

      // Record study activity only after successful submission.
      try {
        final streakService = StreakService();
        await streakService.recordActivity();
        await streakService.updateWidgetCache();
      } catch (streakError) {
        // A streak error must not invalidate a successful test submission.
        debugPrint('Streak update failed: $streakError');
      }

      return result as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Could not submit examination: $e');
    }
  }

  // ──────────────────────────────────────────
  // STUDENT: Fetch attempt details
  // ──────────────────────────────────────────

  Future<TestAttempt?> fetchAttempt(String attemptId) async {
    try {
      final row = await _db
          .from('test_attempts')
          .select()
          .eq('id', attemptId)
          .single();
      return TestAttempt.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  Future<List<TestAttempt>> fetchMyAttempts({int limit = 20}) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];
    final raw = await _db
        .from('test_attempts')
        .select()
        .eq('student_id', userId)
        .eq('is_submitted', true)
        .order('submitted_at', ascending: false)
        .limit(limit);
    return (raw as List)
        .map((j) => TestAttempt.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ──────────────────────────────────────────
  // STUDENT: Fetch questions WITH answers after submission
  // ──────────────────────────────────────────

  Future<List<TestQuestion>> fetchQuestionsForReview(String testId) async {
    final raw = await _db
        .from('test_questions')
        .select()
        .eq('test_id', testId)
        .order('question_number');
    return (raw as List)
        .map((j) => TestQuestion.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ──────────────────────────────────────────
  // STUDENT: Home stats
  // ──────────────────────────────────────────

  Future<Map<String, dynamic>> fetchHomeStats() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return {};
    try {
      final raw = await _db
          .from('test_attempts')
          .select('percentage, stars_earned, submitted_at')
          .eq('student_id', userId)
          .eq('is_submitted', true)
          .order('submitted_at', ascending: false);
      final list = raw as List;
      if (list.isEmpty) {
        return {'count': 0, 'bestScore': 0.0, 'avgScore': 0.0};
      }
      final percentages = list
          .map((r) => (r['percentage'] as num?)?.toDouble() ?? 0.0)
          .toList();
      final best = percentages.reduce((a, b) => a > b ? a : b);
      final avg = percentages.fold(0.0, (s, v) => s + v) / percentages.length;
      return {'count': list.length, 'bestScore': best, 'avgScore': avg};
    } catch (_) {
      return {'count': 0, 'bestScore': 0.0, 'avgScore': 0.0};
    }
  }
}
