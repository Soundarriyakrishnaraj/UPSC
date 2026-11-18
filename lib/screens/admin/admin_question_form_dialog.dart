// lib/screens/admin/admin_question_form_dialog.dart
// Add or edit a single MCQ question

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/test_model.dart';
import '../../services/test_service.dart';

class AdminQuestionFormDialog extends StatefulWidget {
  final String testId;
  final int nextNumber;
  final TestQuestion? existing;

  const AdminQuestionFormDialog({
    super.key,
    required this.testId,
    required this.nextNumber,
    this.existing,
  });

  @override
  State<AdminQuestionFormDialog> createState() => _AdminQuestionFormDialogState();
}

class _AdminQuestionFormDialogState extends State<AdminQuestionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _svc = TestService();

  late TextEditingController _questionCtrl;
  late TextEditingController _optACtrl;
  late TextEditingController _optBCtrl;
  late TextEditingController _optCCtrl;
  late TextEditingController _optDCtrl;
  late TextEditingController _explCtrl;

  String? _correct;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _questionCtrl = TextEditingController(text: e?.questionText ?? '');
    _optACtrl = TextEditingController(text: e?.optionA ?? '');
    _optBCtrl = TextEditingController(text: e?.optionB ?? '');
    _optCCtrl = TextEditingController(text: e?.optionC ?? '');
    _optDCtrl = TextEditingController(text: e?.optionD ?? '');
    _explCtrl = TextEditingController(text: e?.explanation ?? '');
    _correct = e?.correctOption;
  }

  @override
  void dispose() {
    for (final c in [_questionCtrl, _optACtrl, _optBCtrl, _optCCtrl, _optDCtrl, _explCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_correct == null || !['A', 'B', 'C', 'D'].contains(_correct)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select which option (A, B, C, or D) is the correct answer.'),
          backgroundColor: AppTheme.winePlum,
        ),
      );
      return;
    }
    setState(() => _saving = true);

    final data = {
      'test_id': widget.testId,
      'question_number': widget.existing?.questionNumber ?? widget.nextNumber,
      'question_text': _questionCtrl.text.trim(),
      'option_a': _optACtrl.text.trim(),
      'option_b': _optBCtrl.text.trim(),
      'option_c': _optCCtrl.text.trim(),
      'option_d': _optDCtrl.text.trim(),
      'correct_option': _correct!,
      'explanation': _explCtrl.text.trim(),
    };

    try {
      if (widget.existing == null) {
        await _svc.createQuestion(data);
      } else {
        await _svc.updateQuestion(widget.existing!.id, data);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.winePlum));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.alabasterGrey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  const Icon(Icons.help_outline_rounded, color: AppTheme.winePlum, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    isNew
                        ? 'Question ${widget.nextNumber}'
                        : 'Edit Question ${widget.existing?.questionNumber}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.winePlum),
                  ),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context, false)),
                ]),
                const SizedBox(height: 20),

                // Question text
                TextFormField(
                  controller: _questionCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'Question Text *',
                      alignLabelWithHint: true),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),

                // Options
                const Text('Answer Options *',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.winePlum)),
                const SizedBox(height: 10),
                _OptionField(label: 'Option A', ctrl: _optACtrl, letter: 'A',
                    isCorrect: _correct == 'A', onSelect: () => setState(() => _correct = 'A')),
                const SizedBox(height: 10),
                _OptionField(label: 'Option B', ctrl: _optBCtrl, letter: 'B',
                    isCorrect: _correct == 'B', onSelect: () => setState(() => _correct = 'B')),
                const SizedBox(height: 10),
                _OptionField(label: 'Option C', ctrl: _optCCtrl, letter: 'C',
                    isCorrect: _correct == 'C', onSelect: () => setState(() => _correct = 'C')),
                const SizedBox(height: 10),
                _OptionField(label: 'Option D', ctrl: _optDCtrl, letter: 'D',
                    isCorrect: _correct == 'D', onSelect: () => setState(() => _correct = 'D')),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('Tap the radio button beside the correct option',
                      style: const TextStyle(fontSize: 12, color: AppTheme.dustyMauve)),
                ),
                const SizedBox(height: 20),

                // Explanation
                TextFormField(
                  controller: _explCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Explanation *',
                      hintText: 'Why is this answer correct?',
                      alignLabelWithHint: true),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isNew ? 'Add Question' : 'Save Changes'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String letter;
  final bool isCorrect;
  final VoidCallback onSelect;

  const _OptionField({
    required this.label,
    required this.ctrl,
    required this.letter,
    required this.isCorrect,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCorrect ? const Color(0xFF4CAF50) : AppTheme.cherryBlossom,
          width: isCorrect ? 2 : 1,
        ),
        color: isCorrect ? const Color(0xFFE8F5E9) : AppTheme.softRose,
      ),
      child: Row(
        children: [
          Radio<String>(
            value: letter,
            groupValue: isCorrect ? letter : '',
            onChanged: (_) => onSelect(),
            activeColor: const Color(0xFF2E7D32),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextFormField(
                controller: ctrl,
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: label,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
