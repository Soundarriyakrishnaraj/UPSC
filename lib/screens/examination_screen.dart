// lib/screens/examination_screen.dart
// MCQ examination interface with persistent timer, auto-submit, answer palette

import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/test_model.dart';
import '../services/test_service.dart';
import 'result_screen.dart';

class ExaminationScreen extends StatefulWidget {
  final TestModel test;
  final TestAttempt attempt;

  const ExaminationScreen({super.key, required this.test, required this.attempt});

  @override
  State<ExaminationScreen> createState() => _ExaminationScreenState();
}

class _ExaminationScreenState extends State<ExaminationScreen>
    with WidgetsBindingObserver {
  final _svc = TestService();

  List<TestQuestion> _questions = [];
  final Map<String, String?> _selectedOptions = {}; // questionId → 'A'/'B'/'C'/'D'/null
  final Map<String, bool> _markedForReview = {};    // questionId → bool

  int _currentIndex = 0;
  bool _loading = true;
  bool _submitting = false;
  bool _submitted = false;
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDeadline();
    }
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      // Load questions securely (without correct_option or explanation)
      final qs = await _svc.fetchQuestionsForAttempt(widget.attempt.id);
      // Load any saved answers
      final saved = await _svc.fetchAnswers(widget.attempt.id);

      if (!mounted) return;
      setState(() {
        _questions = qs;
        for (final q in qs) {
          _selectedOptions[q.id] = saved[q.id]?.selectedOption;
          _markedForReview[q.id] = saved[q.id]?.isMarkedForReview ?? false;
        }
        _loading = false;
      });

      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Failed to load questions: $e');
    }
  }

  void _startTimer() {
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateRemaining();
      if (_remaining.isNegative || _remaining == Duration.zero) {
        _timer?.cancel();
        _autoSubmit();
      }
    });
  }

  void _updateRemaining() {
    final now = DateTime.now().toUtc();
    final remaining = widget.attempt.deadlineAt.toUtc().difference(now);
    if (mounted) setState(() => _remaining = remaining);
  }

  void _checkDeadline() {
    final now = DateTime.now().toUtc();
    if (widget.attempt.deadlineAt.toUtc().isBefore(now) && !_submitted) {
      _timer?.cancel();
      _autoSubmit();
    }
  }

  Future<void> _autoSubmit() async {
    if (_submitted || _submitting) return;
    setState(() { _submitting = true; });
    try {
      final result = await _svc.submitAttempt(widget.attempt.id);
      if (!mounted) return;
      _submitted = true;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            test: widget.test,
            attemptId: widget.attempt.id,
            scoreResult: result,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Auto-submit failed. Please submit manually: $e');
    }
  }

  Future<void> _selectOption(String questionId, String option) async {
    setState(() => _selectedOptions[questionId] = option);
    try {
      await _svc.saveAnswer(
        attemptId: widget.attempt.id,
        questionId: questionId,
        selectedOption: option,
        isMarkedForReview: _markedForReview[questionId] ?? false,
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Could not save answer: $e');
    }
  }

  Future<void> _toggleReview(String questionId) async {
    final newValue = !(_markedForReview[questionId] ?? false);
    setState(() => _markedForReview[questionId] = newValue);
    try {
      await _svc.saveAnswer(
        attemptId: widget.attempt.id,
        questionId: questionId,
        selectedOption: _selectedOptions[questionId],
        isMarkedForReview: newValue,
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Could not update review status: $e');
    }
  }

  void _goTo(int index) {
    if (index < 0 || index >= _questions.length) return;
    setState(() => _currentIndex = index);
  }

  Future<void> _confirmSubmit() async {
    final answered = _selectedOptions.values.where((v) => v != null).length;
    final unanswered = _questions.length - answered;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Test?'),
        content: Text(
          'Answered: $answered\nUnanswered: $unanswered\n\n'
          'You cannot change answers after submission.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Go Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit Now'),
          ),
        ],
      ),
    );
    if (confirm == true) _autoSubmit();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.winePlum, duration: const Duration(seconds: 4)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.alabasterGrey,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.alabasterGrey,
        appBar: AppBar(title: const Text('Exam')),
        body: const Center(child: Text('No questions found for this test.')),
      );
    }

    final q = _questions[_currentIndex];
    final isTimeLow = _remaining.inMinutes < 5 && !_remaining.isNegative;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final navigator = Navigator.of(context);
          final leave = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Leave Test?'),
              content: const Text('Your answers are saved. The timer continues running.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
              ],
            ),
          );
          if (leave == true && mounted) navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.alabasterGrey,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              _ExamTopBar(
                test: widget.test,
                currentIndex: _currentIndex,
                total: _questions.length,
                remaining: _remaining,
                isTimeLow: isTimeLow,
                onSubmit: _submitting ? null : _confirmSubmit,
              ),
              // Question area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question text
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.softRose,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.cherryBlossom),
                        ),
                        child: Text(
                          q.questionText,
                          style: const TextStyle(fontSize: 15, color: AppTheme.winePlum, height: 1.6),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Options
                      for (final entry in {
                        'A': q.optionA,
                        'B': q.optionB,
                        'C': q.optionC,
                        'D': q.optionD,
                      }.entries)
                        _OptionTile(
                          letter: entry.key,
                          text: entry.value,
                          isSelected: _selectedOptions[q.id] == entry.key,
                          onTap: _submitting ? null : () => _selectOption(q.id, entry.key),
                        ),

                      const SizedBox(height: 14),

                      // Mark for review toggle
                      Row(children: [
                        Checkbox(
                          value: _markedForReview[q.id] ?? false,
                          activeColor: AppTheme.winePlum,
                          onChanged: _submitting ? null : (_) => _toggleReview(q.id),
                        ),
                        const Text('Mark for Review', style: TextStyle(color: AppTheme.dustyMauve)),
                      ]),

                      const SizedBox(height: 20),

                      // Question navigation palette
                      _QuestionPalette(
                        questions: _questions,
                        selectedOptions: _selectedOptions,
                        markedForReview: _markedForReview,
                        currentIndex: _currentIndex,
                        onTap: _goTo,
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Bottom navigation
              _ExamBottomBar(
                currentIndex: _currentIndex,
                total: _questions.length,
                onPrev: _currentIndex > 0 ? () => _goTo(_currentIndex - 1) : null,
                onNext: _currentIndex < _questions.length - 1 ? () => _goTo(_currentIndex + 1) : null,
                onSubmit: _submitting ? null : _confirmSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────

class _ExamTopBar extends StatelessWidget {
  final TestModel test;
  final int currentIndex;
  final int total;
  final Duration remaining;
  final bool isTimeLow;
  final VoidCallback? onSubmit;

  const _ExamTopBar({
    required this.test,
    required this.currentIndex,
    required this.total,
    required this.remaining,
    required this.isTimeLow,
    this.onSubmit,
  });

  String _fmt(Duration d) {
    if (d.isNegative) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.softRose,
        border: Border(bottom: BorderSide(color: AppTheme.cherryBlossom)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(test.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.winePlum),
                overflow: TextOverflow.ellipsis),
            Text('Q ${currentIndex + 1} of $total',
                style: const TextStyle(fontSize: 11, color: AppTheme.dustyMauve)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isTimeLow ? AppTheme.winePlum : AppTheme.alabasterGrey,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isTimeLow ? AppTheme.winePlum : AppTheme.cherryBlossom),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.timer_outlined, size: 14,
                color: isTimeLow ? Colors.white : AppTheme.winePlum),
            const SizedBox(width: 4),
            Text(_fmt(remaining),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isTimeLow ? Colors.white : AppTheme.winePlum)),
          ]),
        ),
        const SizedBox(width: 10),
        TextButton(
          onPressed: onSubmit,
          style: TextButton.styleFrom(
              backgroundColor: AppTheme.winePlum, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Submit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool isSelected;
  final VoidCallback? onTap;

  const _OptionTile({required this.letter, required this.text, required this.isSelected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.winePlum : AppTheme.softRose,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelected ? AppTheme.winePlum : AppTheme.cherryBlossom,
              width: isSelected ? 2 : 1),
        ),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppTheme.pastelPink,
            ),
            child: Center(
              child: Text(letter,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppTheme.winePlum)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.winePlum,
                    fontSize: 14, height: 1.4)),
          ),
          if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        ]),
      ),
    );
  }
}

class _QuestionPalette extends StatelessWidget {
  final List<TestQuestion> questions;
  final Map<String, String?> selectedOptions;
  final Map<String, bool> markedForReview;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _QuestionPalette({
    required this.questions,
    required this.selectedOptions,
    required this.markedForReview,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Question Navigator',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.winePlum)),
        const SizedBox(height: 8),
        // Legend
        Wrap(spacing: 10, runSpacing: 6, children: [
          _Legend(color: AppTheme.winePlum, label: 'Current'),
          _Legend(color: AppTheme.cherryBlossom, label: 'Answered'),
          _Legend(color: AppTheme.softRose, label: 'Not Answered'),
          _Legend(color: AppTheme.dustyMauve, label: 'Marked'),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: questions.asMap().entries.map((e) {
            final i = e.key;
            final q = e.value;
            final isCurrent = i == currentIndex;
            final isAnswered = selectedOptions[q.id] != null;
            final isMarked = markedForReview[q.id] ?? false;
            Color bg;
            if (isCurrent) {
              bg = AppTheme.winePlum;
            } else if (isMarked) {
              bg = AppTheme.dustyMauve;
            } else if (isAnswered) {
              bg = AppTheme.cherryBlossom;
            } else {
              bg = AppTheme.softRose;
            }
            return GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isCurrent ? AppTheme.winePlum : AppTheme.cherryBlossom, width: 1.5),
                ),
                child: Center(
                  child: Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: (isCurrent || isMarked) ? Colors.white : AppTheme.winePlum)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.dustyMauve)),
    ]);
  }
}

class _ExamBottomBar extends StatelessWidget {
  final int currentIndex;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onSubmit;

  const _ExamBottomBar({
    required this.currentIndex,
    required this.total,
    this.onPrev,
    this.onNext,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.softRose,
        border: Border(top: BorderSide(color: AppTheme.cherryBlossom)),
      ),
      child: Row(children: [
        OutlinedButton.icon(
          onPressed: onPrev,
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
          label: const Text('Prev'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(80, 42)),
        ),
        const Spacer(),
        Text('${currentIndex + 1} / $total',
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.winePlum)),
        const Spacer(),
        if (currentIndex == total - 1)
          ElevatedButton(
            onPressed: onSubmit,
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 42)),
            child: const Text('Submit'),
          )
        else
          ElevatedButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            label: const Text('Next'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 42)),
          ),
      ]),
    );
  }
}
