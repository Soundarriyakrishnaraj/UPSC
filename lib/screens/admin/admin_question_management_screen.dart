// lib/screens/admin/admin_question_management_screen.dart
// Add, edit, delete, reorder questions for a test

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/test_model.dart';
import '../../services/test_service.dart';
import 'admin_question_form_screen.dart';

class AdminQuestionManagementScreen extends StatefulWidget {
  final TestModel test;
  const AdminQuestionManagementScreen({super.key, required this.test});

  @override
  State<AdminQuestionManagementScreen> createState() =>
      _AdminQuestionManagementScreenState();
}

class _AdminQuestionManagementScreenState
    extends State<AdminQuestionManagementScreen> {
  final _svc = TestService();
  List<TestQuestion> _questions = [];
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
      final qs = await _svc.fetchQuestions(widget.test.id);
      if (!mounted) return;
      setState(() { _questions = qs; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openForm({TestQuestion? q}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminQuestionFormScreen(
          testId: widget.test.id,
          nextNumber: _questions.length + 1,
          existing: q,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(TestQuestion q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question?'),
        content: Text('Question ${q.questionNumber} will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.winePlum),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _svc.deleteQuestion(q.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.winePlum));
    }
  }

  @override
  Widget build(BuildContext context) {
    final test = widget.test;
    return Scaffold(
      backgroundColor: AppTheme.alabasterGrey,
      appBar: AppBar(
        title: Text('Questions — ${test.title}', overflow: TextOverflow.ellipsis),
        backgroundColor: AppTheme.alabasterGrey,
        foregroundColor: AppTheme.winePlum,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Question'),
        backgroundColor: AppTheme.winePlum,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _TestSummaryBar(test: test, count: _questions.length),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(error: _error!, onRetry: _load)
                    : _questions.isEmpty
                        ? const _EmptyView()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: _questions.length,
                            itemBuilder: (ctx, i) => _QuestionCard(
                              question: _questions[i],
                              index: i,
                              onEdit: () => _openForm(q: _questions[i]),
                              onDelete: () => _delete(_questions[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────

class _TestSummaryBar extends StatelessWidget {
  final TestModel test;
  final int count;
  const _TestSummaryBar({required this.test, required this.count});

  @override
  Widget build(BuildContext context) {
    final needed = test.totalQuestions - count;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.softRose,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count / ${test.totalQuestions} questions added'
                  '${needed > 0 ? " · $needed more needed" : " · Complete!"}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.winePlum),
            ),
          ),
          if (count >= test.totalQuestions)
            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF2E7D32), size: 20),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final TestQuestion question;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionCard({
    required this.question,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  static const _optionColors = {
    'A': Color(0xFFE3F2FD),
    'B': Color(0xFFE8F5E9),
    'C': Color(0xFFFFF3E0),
    'D': Color(0xFFFCE4EC),
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: AppTheme.winePlum,
                  child: Text('${question.questionNumber}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(question.questionText,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.winePlum)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final entry in {'A': question.optionA, 'B': question.optionB,
                'C': question.optionC, 'D': question.optionD}.entries)
              _OptionRow(
                letter: entry.key,
                text: entry.value,
                isCorrect: entry.key == question.correctOption,
                color: _optionColors[entry.key]!,
              ),
            if (question.explanation != null && question.explanation!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.alabasterGrey,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cherryBlossom),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 15, color: AppTheme.dustyMauve),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(question.explanation!,
                          style: const TextStyle(fontSize: 12, color: AppTheme.dustyMauve)),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.winePlum),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String letter;
  final String text;
  final bool isCorrect;
  final Color color;

  const _OptionRow({required this.letter, required this.text, required this.isCorrect, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isCorrect ? const Color(0xFFE8F5E9) : color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isCorrect ? const Color(0xFF4CAF50) : AppTheme.cherryBlossom.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          children: [
            Text(letter,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCorrect ? const Color(0xFF2E7D32) : AppTheme.dustyMauve,
                    fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.winePlum))),
            if (isCorrect) const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2E7D32)),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.help_outline_rounded, size: 56, color: AppTheme.cherryBlossom),
          SizedBox(height: 14),
          Text('No questions yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.winePlum)),
          SizedBox(height: 6),
          Text('Tap + to add questions', style: TextStyle(color: AppTheme.dustyMauve)),
        ]),
      );
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
