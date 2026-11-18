// lib/screens/result_screen.dart
// Post-exam result display with stars, stats, and action buttons

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/test_model.dart';
import '../services/test_service.dart';
import '../services/pdf_report_service.dart';
import 'answer_review_screen.dart';
import 'test_detail_screen.dart';
import 'destination_screen.dart';

class ResultScreen extends StatefulWidget {
  final TestModel test;
  final String attemptId;
  final Map<String, dynamic> scoreResult;

  const ResultScreen({
    super.key,
    required this.test,
    required this.attemptId,
    required this.scoreResult,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with TickerProviderStateMixin {
  final _svc = TestService();
  TestAttempt? _attempt;
  bool _loadingAttempt = true;
  bool _generatingPdf = false;

  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _scaleCtrl.forward();
    _loadAttempt();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAttempt() async {
    final a = await _svc.fetchAttempt(widget.attemptId);
    if (mounted) setState(() { _attempt = a; _loadingAttempt = false; });
  }

  Future<void> _downloadPdf() async {
    if (_attempt == null) return;
    setState(() => _generatingPdf = true);
    try {
      final savedPath = await PdfReportService.savePdfToDownloads(
        test: widget.test,
        attempt: _attempt!,
        service: _svc,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Report saved to $savedPath'),
          backgroundColor: AppTheme.winePlum,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF error: $e'), backgroundColor: AppTheme.winePlum));
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.scoreResult;
    final correct = (r['correct'] as num? ?? 0).toInt();
    final incorrect = (r['incorrect'] as num? ?? 0).toInt();
    final unanswered = (r['unanswered'] as num? ?? 0).toInt();
    final marks = (r['marks_obtained'] as num? ?? 0).toDouble();
    final negMarks = (r['negative_marks'] as num? ?? 0).toDouble();
    final maxMarks = (r['max_marks'] as num? ?? 0).toDouble();
    final pct = (r['percentage'] as num? ?? 0).toDouble();
    final stars = (r['stars'] as num? ?? 0).toInt();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.alabasterGrey,
        appBar: AppBar(
          automaticallyImplyLeading: true,
          title: const Text('Test Result'),
          backgroundColor: AppTheme.alabasterGrey,
          foregroundColor: AppTheme.winePlum,
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.home_rounded, size: 18),
              label: const Text('Home'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(children: [
                // Score ring
                ScaleTransition(
                  scale: _scaleAnim,
                  child: _ScoreRing(pct: pct, stars: stars, marks: marks, maxMarks: maxMarks),
                ),
                const SizedBox(height: 24),

                // Stats cards
                _ResultGrid(correct: correct, incorrect: incorrect, unanswered: unanswered,
                    negMarks: negMarks, totalQ: widget.test.totalQuestions),
                const SizedBox(height: 20),

                // Attempt meta
                if (!_loadingAttempt && _attempt != null)
                  _AttemptMetaCard(attempt: _attempt!),
                const SizedBox(height: 24),

                // Action buttons
                _ActionBtn(
                  icon: Icons.list_alt_rounded,
                  label: 'Review Answers',
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AnswerReviewScreen(test: widget.test, attemptId: widget.attemptId),
                  )),
                ),
                const SizedBox(height: 10),
                _ActionBtn(
                  icon: Icons.picture_as_pdf_rounded,
                  label: _generatingPdf ? 'Generating PDF…' : 'Download Report',
                  onTap: _generatingPdf ? null : _downloadPdf,
                  loading: _generatingPdf,
                ),
                const SizedBox(height: 10),
                _ActionBtn(
                  icon: Icons.replay_rounded,
                  label: 'Retake Test',
                  onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(
                    builder: (_) => TestDetailScreen(test: widget.test, levelState: LevelState.completed),
                  )),
                  outlined: true,
                ),
                const SizedBox(height: 10),
                _ActionBtn(
                  icon: Icons.map_outlined,
                  label: 'Back to Destination',
                  onTap: () => Navigator.of(context).pop(),
                  outlined: true,
                ),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────

class _ScoreRing extends StatelessWidget {
  final double pct;
  final int stars;
  final double marks;
  final double maxMarks;

  const _ScoreRing({required this.pct, required this.stars, required this.marks, required this.maxMarks});

  String get _grade {
    if (pct >= 80) return 'Excellent!';
    if (pct >= 60) return 'Good Job!';
    if (pct >= 40) return 'Keep Practising';
    return 'Needs Improvement';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.winePlum, Color(0xFF5D3039)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppTheme.winePlum.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(children: [
        Text(_grade, style: const TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        Text('${pct.toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold, height: 1)),
        const SizedBox(height: 6),
        Text('${marks.toStringAsFixed(2)} / ${maxMarks.toStringAsFixed(0)} marks',
            style: const TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 14),
        // Stars
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            color: i < stars ? AppTheme.pastelPink : Colors.white38,
            size: 32,
          ),
        ))),
      ]),
    );
  }
}

class _ResultGrid extends StatelessWidget {
  final int correct;
  final int incorrect;
  final int unanswered;
  final double negMarks;
  final int totalQ;

  const _ResultGrid({
    required this.correct,
    required this.incorrect,
    required this.unanswered,
    required this.negMarks,
    required this.totalQ,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _ResultCell('Correct', '$correct', Icons.check_circle_outline_rounded, const Color(0xFF2E7D32)),
        _ResultCell('Incorrect', '$incorrect', Icons.cancel_outlined, AppTheme.winePlum),
        _ResultCell('Unanswered', '$unanswered', Icons.radio_button_unchecked_rounded, AppTheme.dustyMauve),
        _ResultCell('Negative Marks', '-${negMarks.toStringAsFixed(2)}', Icons.remove_circle_outline_rounded, AppTheme.dustyMauve),
      ],
    );
  }
}

class _ResultCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _ResultCell(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
            ]),
      ]),
    );
  }
}

class _AttemptMetaCard extends StatelessWidget {
  final TestAttempt attempt;
  const _AttemptMetaCard({required this.attempt});

  @override
  Widget build(BuildContext context) {
    final taken = attempt.submittedAt != null
        ? attempt.submittedAt!.difference(attempt.startedAt)
        : const Duration();
    final m = taken.inMinutes;
    final s = taken.inSeconds.remainder(60);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softRose,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cherryBlossom),
      ),
      child: Column(children: [
        _MetaRow('Attempt Number', '#${attempt.attemptNumber}'),
        const Divider(height: 12),
        _MetaRow('Selected Duration', '${attempt.selectedDurationMinutes} minutes'),
        const Divider(height: 12),
        _MetaRow('Time Taken', '${m}m ${s}s'),
      ]),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: AppTheme.dustyMauve, fontSize: 13))),
      Text(value, style: const TextStyle(color: AppTheme.winePlum, fontWeight: FontWeight.bold, fontSize: 13)),
    ]);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool outlined;
  final bool loading;

  const _ActionBtn({
    required this.icon,
    required this.label,
    this.onTap,
    this.outlined = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (loading)
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
      else
        Icon(icon, size: 18),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    ]);

    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton(onPressed: onTap, child: child),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(onPressed: onTap, child: child),
    );
  }
}
