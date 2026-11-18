// lib/screens/answer_review_screen.dart
// Full post-exam question review with correct answers, explanations

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/test_model.dart';
import '../services/test_service.dart';

class AnswerReviewScreen extends StatefulWidget {
  final TestModel test;
  final String attemptId;

  const AnswerReviewScreen({super.key, required this.test, required this.attemptId});

  @override
  State<AnswerReviewScreen> createState() => _AnswerReviewScreenState();
}

class _AnswerReviewScreenState extends State<AnswerReviewScreen> {
  final _svc = TestService();

  List<TestQuestion> _questions = [];
  Map<String, TestAnswer> _answers = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _svc.fetchQuestionsForReview(widget.test.id),
        _svc.fetchAnswers(widget.attemptId),
      ]);
      if (!mounted) return;
      setState(() {
        _questions = results[0] as List<TestQuestion>;
        _answers = results[1] as Map<String, TestAnswer>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.alabasterGrey,
      appBar: AppBar(
        title: Text('Review — ${widget.test.title}', overflow: TextOverflow.ellipsis),
        backgroundColor: AppTheme.alabasterGrey,
        foregroundColor: AppTheme.winePlum,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _questions.isEmpty
                  ? const Center(child: Text('No questions found.'))
                  : Column(
                      children: [
                        _SummaryBar(test: widget.test, questions: _questions, answers: _answers),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _questions.length,
                            itemBuilder: (ctx, i) {
                              final q = _questions[i];
                              final a = _answers[q.id];
                              return _ReviewCard(
                                question: q,
                                studentAnswer: a?.selectedOption,
                                marksPerQ: widget.test.marksPerQuestion,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}

// ─────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final TestModel test;
  final List<TestQuestion> questions;
  final Map<String, TestAnswer> answers;

  const _SummaryBar({required this.test, required this.questions, required this.answers});

  @override
  Widget build(BuildContext context) {
    int correct = 0, incorrect = 0, unanswered = 0;
    for (final q in questions) {
      final a = answers[q.id];
      if (a?.selectedOption == null) {
        unanswered++;
      } else if (a?.selectedOption == q.correctOption) {
        correct++;
      } else {
        incorrect++;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.softRose,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _Pill(label: 'Correct', value: '$correct', color: const Color(0xFF2E7D32)),
        _Pill(label: 'Incorrect', value: '$incorrect', color: AppTheme.winePlum),
        _Pill(label: 'Skipped', value: '$unanswered', color: AppTheme.dustyMauve),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Pill({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
    ]);
  }
}

class _ReviewCard extends StatelessWidget {
  final TestQuestion question;
  final String? studentAnswer;
  final double marksPerQ;

  const _ReviewCard({
    required this.question,
    this.studentAnswer,
    required this.marksPerQ,
  });

  @override
  Widget build(BuildContext context) {
    final correct = question.correctOption ?? '';
    final isCorrect = studentAnswer != null && studentAnswer == correct;
    final isUnanswered = studentAnswer == null;
    final isIncorrect = !isCorrect && !isUnanswered;

    // Marks computation
    double marks;
    String marksLabel;
    Color headerColor;
    IconData headerIcon;
    if (isCorrect) {
      marks = marksPerQ;
      marksLabel = '+${marks.toStringAsFixed(2)}';
      headerColor = const Color(0xFF2E7D32);
      headerIcon = Icons.check_circle_rounded;
    } else if (isIncorrect) {
      marks = -(marksPerQ / 3);
      marksLabel = marks.toStringAsFixed(2);
      headerColor = AppTheme.winePlum;
      headerIcon = Icons.cancel_rounded;
    } else {
      marks = 0;
      marksLabel = '0';
      headerColor = AppTheme.dustyMauve;
      headerIcon = Icons.radio_button_unchecked_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Icon(headerIcon, color: headerColor, size: 20),
              const SizedBox(width: 8),
              Text('Q ${question.questionNumber}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: headerColor, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: headerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: headerColor.withValues(alpha: 0.3)),
                ),
                child: Text(marksLabel,
                    style: TextStyle(fontWeight: FontWeight.bold, color: headerColor, fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 10),

            // Question text
            Text(question.questionText,
                style: const TextStyle(fontSize: 14, color: AppTheme.winePlum, height: 1.5)),
            const SizedBox(height: 12),

            // Options
            for (final entry in {
              'A': question.optionA,
              'B': question.optionB,
              'C': question.optionC,
              'D': question.optionD,
            }.entries)
              _ReviewOption(
                letter: entry.key,
                text: entry.value,
                isCorrect: entry.key == correct,
                isStudentAnswer: entry.key == studentAnswer,
              ),

            const SizedBox(height: 10),

            // Explanation
            if (question.explanation != null && question.explanation!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.alabasterGrey,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cherryBlossom),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppTheme.dustyMauve),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        question.explanation!,
                        style: const TextStyle(fontSize: 12, color: AppTheme.dustyMauve, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewOption extends StatelessWidget {
  final String letter;
  final String text;
  final bool isCorrect;
  final bool isStudentAnswer;

  const _ReviewOption({
    required this.letter,
    required this.text,
    required this.isCorrect,
    required this.isStudentAnswer,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color textColor;
    Widget? trailing;

    if (isCorrect && isStudentAnswer) {
      bg = const Color(0xFFE8F5E9);
      border = const Color(0xFF4CAF50);
      textColor = const Color(0xFF2E7D32);
      trailing = const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 18);
    } else if (isCorrect) {
      bg = const Color(0xFFE8F5E9);
      border = const Color(0xFF4CAF50);
      textColor = const Color(0xFF2E7D32);
      trailing = const Icon(Icons.check_rounded, color: Color(0xFF4CAF50), size: 18);
    } else if (isStudentAnswer) {
      bg = AppTheme.pastelPink;
      border = AppTheme.winePlum;
      textColor = AppTheme.winePlum;
      trailing = const Icon(Icons.close_rounded, color: AppTheme.winePlum, size: 18);
    } else {
      bg = AppTheme.softRose;
      border = AppTheme.cherryBlossom.withValues(alpha: 0.5);
      textColor = AppTheme.dustyMauve;
      trailing = null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(children: [
          Text(letter, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: textColor))),
          ?trailing,
        ]),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.winePlum),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.winePlum)),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ]),
        ),
      );
}
