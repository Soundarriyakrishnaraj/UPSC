// lib/screens/admin/admin_question_form_screen.dart
// Full-page screen for adding or editing an MCQ question with independent correct answer selection

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/test_model.dart';
import '../../services/test_service.dart';

class AdminQuestionFormScreen extends StatefulWidget {
  final String testId;
  final int nextNumber;
  final TestQuestion? existing;

  const AdminQuestionFormScreen({
    super.key,
    required this.testId,
    required this.nextNumber,
    this.existing,
  });

  @override
  State<AdminQuestionFormScreen> createState() => _AdminQuestionFormScreenState();
}

class _AdminQuestionFormScreenState extends State<AdminQuestionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _svc = TestService();

  late TextEditingController _questionCtrl;
  late TextEditingController _optACtrl;
  late TextEditingController _optBCtrl;
  late TextEditingController _optCCtrl;
  late TextEditingController _optDCtrl;
  late TextEditingController _explCtrl;

  // Never default to 'A'. Require explicit selection when creating new questions.
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
    // Load previously saved correct option when editing, or null if creating new
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

    // Validate that the administrator explicitly selected a correct option
    if (_correct == null || !['A', 'B', 'C', 'D'].contains(_correct)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the correct answer (Option A, B, C, or D) before saving.'),
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
      'explanation': _explCtrl.text.trim().isEmpty ? null : _explCtrl.text.trim(),
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
        SnackBar(content: Text('Error saving question: $e'), backgroundColor: AppTheme.winePlum),
      );
    }
  }

  Widget _buildOptionTile({
    required String optionKey,
    required TextEditingController controller,
    required String label,
  }) {
    final isSelected = _correct == optionKey;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFE4F2E7) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? const Color(0xFF245C35) : AppTheme.cherryBlossom.withValues(alpha: 0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _correct = optionKey),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Radio<String>(
                    value: optionKey,
                    groupValue: _correct,
                    activeColor: const Color(0xFF245C35),
                    onChanged: (v) {
                      if (v != null) setState(() => _correct = v);
                    },
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected ? const Color(0xFF245C35) : AppTheme.winePlum,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF245C35) : AppTheme.pastelPink.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF245C35) : AppTheme.cherryBlossom,
                      ),
                    ),
                    child: Text(
                      isSelected ? '✓ CORRECT ANSWER' : 'Tap to mark correct',
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.dustyMauve,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter text for Option $optionKey...',
              filled: true,
              fillColor: isSelected ? Colors.white : AppTheme.alabasterGrey.withValues(alpha: 0.4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.cherryBlossom.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.cherryBlossom.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.winePlum, width: 1.5),
              ),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Option $optionKey is required' : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    final qNum = widget.existing?.questionNumber ?? widget.nextNumber;

    return Scaffold(
      backgroundColor: AppTheme.alabasterGrey,
      appBar: AppBar(
        title: Text(isNew ? 'Add Question #$qNum' : 'Edit Question #$qNum'),
        backgroundColor: AppTheme.alabasterGrey,
        foregroundColor: AppTheme.winePlum,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Question Text Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cherryBlossom.withValues(alpha: 0.4)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.winePlum,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Q$qNum',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Question Text *',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.winePlum,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _questionCtrl,
                    minLines: 3,
                    maxLines: 8,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type or paste the complete UPSC MCQ question text here...',
                      filled: true,
                      fillColor: AppTheme.alabasterGrey.withValues(alpha: 0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.cherryBlossom.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.winePlum, width: 1.5),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Please enter the question text' : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Quick Correct Option Selector Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _correct != null ? const Color(0xFF245C35) : AppTheme.winePlum,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _correct != null ? Icons.check_circle_rounded : Icons.radio_button_checked,
                        color: _correct != null ? const Color(0xFF245C35) : AppTheme.winePlum,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _correct != null
                            ? 'Selected Correct Answer: Option $_correct'
                            : 'Select Correct Answer * (Required)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _correct != null ? const Color(0xFF245C35) : AppTheme.winePlum,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: ['A', 'B', 'C', 'D'].map((opt) {
                      final isSel = _correct == opt;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () => setState(() => _correct = opt),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFF245C35) : AppTheme.pastelPink.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? const Color(0xFF245C35) : AppTheme.cherryBlossom,
                                  width: isSel ? 2 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Option $opt',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isSel ? Colors.white : AppTheme.winePlum,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            _buildOptionTile(optionKey: 'A', controller: _optACtrl, label: 'Option A'),
            _buildOptionTile(optionKey: 'B', controller: _optBCtrl, label: 'Option B'),
            _buildOptionTile(optionKey: 'C', controller: _optCCtrl, label: 'Option C'),
            _buildOptionTile(optionKey: 'D', controller: _optDCtrl, label: 'Option D'),

            const SizedBox(height: 12),

            // Explanation Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cherryBlossom.withValues(alpha: 0.4)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detailed Explanation / Solution (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.winePlum,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Students will see this solution in their results review after completing the test.',
                    style: TextStyle(fontSize: 12, color: AppTheme.dustyMauve),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _explCtrl,
                    minLines: 3,
                    maxLines: 6,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Explain why the chosen option is correct and provide relevant UPSC context...',
                      filled: true,
                      fillColor: AppTheme.alabasterGrey.withValues(alpha: 0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.cherryBlossom.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.winePlum, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Save Button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                label: Text(
                  _saving ? 'Saving Question...' : 'Save Question',
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
          ],
        ),
      ),
    );
  }
}
