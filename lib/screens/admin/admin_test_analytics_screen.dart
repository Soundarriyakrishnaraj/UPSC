// lib/screens/admin/admin_test_analytics_screen.dart
// Admin analytics for an individual test: attempts, scores, and question-wise stats

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/test_model.dart';
import '../../services/test_service.dart';

class AdminTestAnalyticsScreen extends StatefulWidget {
  final TestModel test;
  const AdminTestAnalyticsScreen({super.key, required this.test});

  @override
  State<AdminTestAnalyticsScreen> createState() =>
      _AdminTestAnalyticsScreenState();
}

class _AdminTestAnalyticsScreenState extends State<AdminTestAnalyticsScreen> {
  final _svc = TestService();
  Map<String, dynamic>? _analytics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _svc.fetchTestAnalytics(widget.test.id);
      if (!mounted) return;
      setState(() {
        _analytics = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.alabasterGrey,
      appBar: AppBar(
        title: Text('Analytics — ${widget.test.title}',
            overflow: TextOverflow.ellipsis),
        backgroundColor: AppTheme.alabasterGrey,
        foregroundColor: AppTheme.winePlum,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: AppTheme.winePlum),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.winePlum)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final a = _analytics ?? {};
    final totalAttempts = (a['totalAttempts'] as num? ?? 0).toInt();
    final uniqueStudents = (a['uniqueStudents'] as num? ?? 0).toInt();
    final completionRate =
        (a['completionRate'] as num? ?? 0.0).toDouble();
    final avgScore = (a['avgScore'] as num? ?? 0.0).toDouble();
    final highestScore = (a['highestScore'] as num? ?? 0.0).toDouble();
    final lowestScore = (a['lowestScore'] as num? ?? 0.0).toDouble();
    final correctPct = (a['correctPct'] as num? ?? 0.0).toDouble();
    final incorrectPct = (a['incorrectPct'] as num? ?? 0.0).toDouble();
    final unansweredPct = (a['unansweredPct'] as num? ?? 0.0).toDouble();
    final questions =
        (a['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (totalAttempts == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.analytics_outlined,
                  size: 60, color: AppTheme.cherryBlossom),
              const SizedBox(height: 16),
              const Text(
                'No attempts yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.winePlum),
              ),
              const SizedBox(height: 8),
              Text(
                'Once students attempt "${widget.test.title}", performance analytics will appear here.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.dustyMauve),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
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
                Text(
                  'Level ${widget.test.levelNumber} · ${widget.test.upscStage} · ${widget.test.stageCategory}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.test.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _headerMetric('Students', '$uniqueStudents'),
                    const SizedBox(width: 24),
                    _headerMetric('Attempts', '$totalAttempts'),
                    const SizedBox(width: 24),
                    _headerMetric('Completion',
                        '${completionRate.toStringAsFixed(0)}%'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Score Overview
          const Text('Score Overview',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.winePlum)),
          const SizedBox(height: 10),
          Row(
            children: [
              _scoreCard(
                  'Average Score', '${avgScore.toStringAsFixed(1)}%', AppTheme.winePlum),
              const SizedBox(width: 10),
              _scoreCard('Highest', '${highestScore.toStringAsFixed(1)}%',
                  const Color(0xFF2E7D32)),
              const SizedBox(width: 10),
              _scoreCard(
                  'Lowest', '${lowestScore.toStringAsFixed(1)}%', AppTheme.dustyMauve),
            ],
          ),
          const SizedBox(height: 20),

          // Answers Breakdown
          const Text('Answer Accuracy Distribution',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.winePlum)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.softRose,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cherryBlossom),
            ),
            child: Column(
              children: [
                _accuracyBar('Correct Answers', correctPct, const Color(0xFF2E7D32)),
                const SizedBox(height: 12),
                _accuracyBar('Incorrect Answers', incorrectPct, AppTheme.winePlum),
                const SizedBox(height: 12),
                _accuracyBar('Unanswered / Skipped', unansweredPct, AppTheme.dustyMauve),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Question-wise Breakdown
          if (questions.isNotEmpty) ...[
            Text('Question Performance (${questions.length})',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.winePlum)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questions.length,
              itemBuilder: (ctx, i) {
                final q = questions[i];
                final qNum = q['questionNumber'] as int? ?? (i + 1);
                final qText = q['questionText'] as String? ?? '';
                final accuracy = (q['accuracy'] as num? ?? 0.0).toDouble();
                final correct = (q['correct'] as num? ?? 0).toInt();
                final incorrect = (q['incorrect'] as num? ?? 0).toInt();
                final skipped = (q['skipped'] as num? ?? 0).toInt();

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: AppTheme.winePlum,
                              child: Text('$qNum',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                qText,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.winePlum,
                                    fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accuracy >= 60
                                    ? const Color(0xFFE8F5E9)
                                    : AppTheme.pastelPink,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${accuracy.toStringAsFixed(0)}% correct',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: accuracy >= 60
                                      ? const Color(0xFF2E7D32)
                                      : AppTheme.winePlum,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: accuracy / 100,
                            minHeight: 6,
                            backgroundColor: AppTheme.pastelPink,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              accuracy >= 60
                                  ? const Color(0xFF2E7D32)
                                  : AppTheme.winePlum,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _miniStat('✓ Correct', '$correct', const Color(0xFF2E7D32)),
                            const SizedBox(width: 14),
                            _miniStat('✗ Wrong', '$incorrect', AppTheme.winePlum),
                            const SizedBox(width: 14),
                            _miniStat('— Skipped', '$skipped', AppTheme.dustyMauve),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _headerMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _scoreCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _accuracyBar(String label, double pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.winePlum,
                    fontWeight: FontWeight.w600)),
            Text('${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 8,
            backgroundColor: AppTheme.pastelPink,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Text(
      '$label: $value',
      style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600),
    );
  }
}
