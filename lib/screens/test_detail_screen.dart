// lib/screens/test_detail_screen.dart
// Clean, professional test information + duration selector + start/resume flow

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/test_model.dart';
import '../services/test_service.dart';
import 'destination_screen.dart';
import 'examination_screen.dart';

class TestDetailScreen extends StatefulWidget {
  final TestModel test;
  final LevelState levelState;

  const TestDetailScreen({super.key, required this.test, required this.levelState});

  @override
  State<TestDetailScreen> createState() => _TestDetailScreenState();
}

class _TestDetailScreenState extends State<TestDetailScreen> {
  final _svc = TestService();

  List<TestAttempt> _prevAttempts = [];
  TestAttempt? _activeAttempt;
  bool _loading = true;
  int _selectedDuration = 0;

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.test.maxDurationMinutes;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final attempts = await _svc.fetchMyAttempts(limit: 50);
      if (!mounted) return;
      final testAttempts = attempts.where((a) => a.testId == widget.test.id).toList();

      // Check for active unsubmitted attempt that has not expired
      final now = DateTime.now().toUtc();
      TestAttempt? active;
      for (final a in testAttempts) {
        if (!a.isSubmitted && a.deadlineAt.toUtc().isAfter(now)) {
          active = a;
          break;
        }
      }

      setState(() {
        _prevAttempts = testAttempts;
        _activeAttempt = active;
        if (active != null) {
          _selectedDuration = active.selectedDurationMinutes;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startOrResumeTest() async {
    // If there is an active ongoing attempt, resume it directly
    if (_activeAttempt != null) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ExaminationScreen(test: widget.test, attempt: _activeAttempt!),
        ),
      );
      return;
    }

    // Otherwise start fresh with selected duration (clamped to admin maximum)
    final duration = _selectedDuration.clamp(1, widget.test.maxDurationMinutes);

    try {
      final attempt = await _svc.startAttempt(widget.test.id, duration);
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ExaminationScreen(test: widget.test, attempt: attempt),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start test: $e'), backgroundColor: AppTheme.winePlum),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final test = widget.test;
    final maxMarks = test.totalQuestions * test.marksPerQuestion;
    final negMark = test.marksPerQuestion / 3;
    final isCompleted = widget.levelState == LevelState.completed;
    final isResuming = _activeAttempt != null;

    return Scaffold(
      backgroundColor: AppTheme.alabasterGrey,
      appBar: AppBar(
        title: Text(test.title, overflow: TextOverflow.ellipsis),
        backgroundColor: AppTheme.alabasterGrey,
        foregroundColor: AppTheme.winePlum,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Clean Hero Card ──
                      _HeroCard(
                        test: test,
                        isCompleted: isCompleted,
                        isActive: isResuming,
                      ),
                      const SizedBox(height: 16),

                      // ── Active Attempt Banner ──
                      if (isResuming) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.pastelPink.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.winePlum, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: AppTheme.winePlum, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Test in progress (${_activeAttempt!.selectedDurationMinutes} min attempt). Tap below to resume.',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.winePlum,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Clean 4-Item Test Details Grid (No Overflow) ──
                      const Text(
                        'Test Overview',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.winePlum),
                      ),
                      const SizedBox(height: 8),
                      _OverviewGrid(
                        questions: '${test.totalQuestions}',
                        duration: '${test.maxDurationMinutes} min',
                        marks: maxMarks.toStringAsFixed(0),
                        marking: '+${test.marksPerQuestion.toStringAsFixed(1)} / -${negMark.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 16),

                      // ── Duration Selector ──
                      if (!isResuming) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Select Duration',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.winePlum),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.winePlum,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_selectedDuration min',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _DurationSelector(
                          max: test.maxDurationMinutes,
                          selected: _selectedDuration,
                          onChanged: (v) => setState(() => _selectedDuration = v),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Instructions (Compact if present) ──
                      if (test.instructions != null && test.instructions!.trim().isNotEmpty) ...[
                        const Text(
                          'Instructions',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.winePlum),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.cherryBlossom.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            test.instructions!.trim(),
                            style: const TextStyle(fontSize: 13, color: AppTheme.winePlum, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Previous Attempts ──
                      if (_prevAttempts.isNotEmpty) ...[
                        Text(
                          'Previous Attempts (${_prevAttempts.length})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.winePlum),
                        ),
                        const SizedBox(height: 6),
                        ..._prevAttempts.take(3).map((a) => _AttemptTile(attempt: a, test: test)),
                        const SizedBox(height: 16),
                      ],

                      // ── Start / Resume Action Button ──
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _startOrResumeTest,
                          icon: Icon(
                            isResuming
                                ? Icons.play_arrow_rounded
                                : (isCompleted ? Icons.replay_rounded : Icons.play_arrow_rounded),
                            size: 22,
                            color: Colors.white,
                          ),
                          label: Text(
                            isResuming
                                ? 'Resume Examination'
                                : (isCompleted ? 'Retake Test' : 'Start Test'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.winePlum,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── Concise Marking Scheme Note ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cherryBlossom.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: AppTheme.dustyMauve, size: 15),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Marking: +${test.marksPerQuestion.toStringAsFixed(1)} correct, -${negMark.toStringAsFixed(2)} incorrect, 0 unanswered.',
                                style: const TextStyle(fontSize: 11, color: AppTheme.dustyMauve),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────
// Clean Hero Card
// ─────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final TestModel test;
  final bool isCompleted;
  final bool isActive;

  const _HeroCard({
    required this.test,
    required this.isCompleted,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final stage = stageForLevel(test.levelNumber);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.winePlum, Color(0xFF5D3039)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.winePlum.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(stage.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                'Level ${test.levelNumber}  •  ${test.upscStage}',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'IN PROGRESS',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              else if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'COMPLETED',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            test.title,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  test.stageCategory,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  test.subject,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Robust 4-Item Overview Grid (Zero Overflow)
// ─────────────────────────────────────────────

class _OverviewGrid extends StatelessWidget {
  final String questions;
  final String duration;
  final String marks;
  final String marking;

  const _OverviewGrid({
    required this.questions,
    required this.duration,
    required this.marks,
    required this.marking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cherryBlossom.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(child: _OverviewItem(icon: Icons.quiz_outlined, label: 'Questions', value: questions)),
          Container(height: 36, width: 1, color: AppTheme.cherryBlossom.withValues(alpha: 0.4)),
          Expanded(child: _OverviewItem(icon: Icons.timer_outlined, label: 'Max Time', value: duration)),
          Container(height: 36, width: 1, color: AppTheme.cherryBlossom.withValues(alpha: 0.4)),
          Expanded(child: _OverviewItem(icon: Icons.star_outline_rounded, label: 'Total Marks', value: marks)),
          Container(height: 36, width: 1, color: AppTheme.cherryBlossom.withValues(alpha: 0.4)),
          Expanded(child: _OverviewItem(icon: Icons.rule_rounded, label: 'Marking', value: marking)),
        ],
      ),
    );
  }
}

class _OverviewItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _OverviewItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppTheme.winePlum),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.winePlum,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.dustyMauve),
          textAlign: TextAlign.center,
          maxLines: 1,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Interactive Duration Selector (Chips + Slider)
// ─────────────────────────────────────────────

class _DurationSelector extends StatelessWidget {
  final int max;
  final int selected;
  final ValueChanged<int> onChanged;

  const _DurationSelector({
    required this.max,
    required this.selected,
    required this.onChanged,
  });

  List<int> get _options {
    if (max <= 1) return [1];
    if (max <= 5) {
      return List.generate(max, (i) => i + 1); // 1, 2, 3, 4, 5
    }
    if (max <= 15) {
      return <int>{3, 5, 10, max}.toList()..sort();
    }
    if (max <= 30) {
      return <int>{5, 10, 15, 20, max}.toList()..sort();
    }
    if (max <= 60) {
      return <int>{15, 30, 45, max}.toList()..sort();
    }
    return <int>{30, 60, 90, max}.where((v) => v <= max).toSet().toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final opts = _options;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cherryBlossom.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preset chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: opts.map((opt) {
              final isSel = opt == selected;
              return InkWell(
                onTap: () => onChanged(opt),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? AppTheme.winePlum : AppTheme.pastelPink.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel ? AppTheme.winePlum : AppTheme.cherryBlossom.withValues(alpha: 0.6),
                      width: isSel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    '$opt min',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSel ? Colors.white : AppTheme.winePlum,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Slider for fine-grained selection if max > 3
          if (max > 3) ...[
            const SizedBox(height: 10),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.winePlum,
                inactiveTrackColor: AppTheme.pastelPink,
                thumbColor: AppTheme.winePlum,
                overlayColor: AppTheme.winePlum.withValues(alpha: 0.2),
                valueIndicatorColor: AppTheme.winePlum,
                valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              child: Slider(
                value: selected.clamp(1, max).toDouble(),
                min: 1,
                max: max.toDouble(),
                divisions: max > 1 ? max - 1 : 1,
                label: '$selected min',
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Attempt Tile
// ─────────────────────────────────────────────

class _AttemptTile extends StatelessWidget {
  final TestAttempt attempt;
  final TestModel test;
  const _AttemptTile({required this.attempt, required this.test});

  @override
  Widget build(BuildContext context) {
    final pct = attempt.percentage?.toStringAsFixed(1) ?? '--';
    final marks = attempt.marksObtained?.toStringAsFixed(2) ?? '--';
    final date = attempt.submittedAt ?? attempt.startedAt;
    final maxM = (test.totalQuestions * test.marksPerQuestion).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cherryBlossom.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.pastelPink,
            child: Text(
              '#${attempt.attemptNumber}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.winePlum),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attempt ${attempt.attemptNumber}  •  $pct%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.winePlum),
                ),
                Text(
                  '$marks / $maxM marks  •  ${_fmtDate(date)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.dustyMauve),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (i) => Icon(
                i < attempt.starsEarned ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 16,
                color: AppTheme.winePlum,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final local = d.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}
