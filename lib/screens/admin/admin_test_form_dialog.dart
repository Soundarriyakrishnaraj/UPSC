// lib/screens/admin/admin_test_form_dialog.dart
// Create / Edit a test

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/test_model.dart';
import '../../services/test_service.dart';

class AdminTestFormDialog extends StatefulWidget {
  final TestModel? existing;
  const AdminTestFormDialog({super.key, this.existing});

  @override
  State<AdminTestFormDialog> createState() => _AdminTestFormDialogState();
}

class _AdminTestFormDialogState extends State<AdminTestFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _svc = TestService();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _subjectCtrl;
  late TextEditingController _levelCtrl;
  late TextEditingController _testNumCtrl;
  late TextEditingController _totalQCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _marksCtrl;
  late TextEditingController _instrCtrl;

  String _upscStage = 'Prelims';
  String _stageCategory = 'Indian Polity';
  bool _isPublished = false;
  bool _saving = false;

  static const List<String> _stages = ['Prelims', 'Mains'];
  static const List<String> _categories = [
    'Indian Polity',
    'Indian History',
    'Indian Geography',
    'Indian Economy',
    'General Science',
    'Environment & Ecology',
    'Current Affairs',
    'Art & Culture',
    'International Relations',
    'CSAT & Reasoning',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl  = TextEditingController(text: e?.title ?? '');
    _descCtrl   = TextEditingController(text: e?.description ?? '');
    _subjectCtrl= TextEditingController(text: e?.subject ?? '');
    _levelCtrl  = TextEditingController(text: e != null ? '${e.levelNumber}' : '');
    _testNumCtrl= TextEditingController(text: e != null ? '${e.testNumber}' : '1');
    _totalQCtrl = TextEditingController(text: e != null ? '${e.totalQuestions}' : '');
    _durationCtrl= TextEditingController(text: e != null ? '${e.maxDurationMinutes}' : '');
    _marksCtrl  = TextEditingController(text: e != null ? '${e.marksPerQuestion}' : '2');
    _instrCtrl  = TextEditingController(text: e?.instructions ?? '');
    _upscStage  = e?.upscStage ?? 'Prelims';
    _stageCategory = e?.stageCategory ?? 'Indian Polity';
    _isPublished = e?.isPublished ?? false;
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _descCtrl, _subjectCtrl, _levelCtrl,
        _testNumCtrl, _totalQCtrl, _durationCtrl, _marksCtrl, _instrCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'subject': _subjectCtrl.text.trim(),
      'upsc_stage': _upscStage,
      'stage_category': _stageCategory,
      'level_number': int.parse(_levelCtrl.text.trim()),
      'test_number': int.parse(_testNumCtrl.text.trim()),
      'total_questions': int.parse(_totalQCtrl.text.trim()),
      'max_duration_minutes': int.parse(_durationCtrl.text.trim()),
      'marks_per_question': double.parse(_marksCtrl.text.trim()),
      'instructions': _instrCtrl.text.trim().isEmpty ? null : _instrCtrl.text.trim(),
      'is_published': _isPublished,
    };

    try {
      if (widget.existing == null) {
        await _svc.createTest(data);
      } else {
        await _svc.updateTest(widget.existing!.id, data);
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
        constraints: const BoxConstraints(maxWidth: 540),
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
                  const Icon(Icons.quiz_rounded, color: AppTheme.winePlum, size: 26),
                  const SizedBox(width: 10),
                  Text(isNew ? 'New Test' : 'Edit Test',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.winePlum)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context, false)),
                ]),
                const SizedBox(height: 20),

                _field(_titleCtrl, 'Test Title *', validator: _required),
                const SizedBox(height: 14),
                _field(_descCtrl, 'Description (optional)', maxLines: 2),
                const SizedBox(height: 14),
                _field(_subjectCtrl, 'Subject *', validator: _required,
                    hint: 'e.g. General Studies Paper I'),
                const SizedBox(height: 14),

                // Stage dropdowns
                Row(children: [
                  Expanded(child: _Dropdown(
                    label: 'UPSC Stage',
                    value: _upscStage,
                    items: _stages,
                    onChanged: (v) => setState(() => _upscStage = v!),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _Dropdown(
                    label: 'Stage Category',
                    value: _stageCategory,
                    items: _categories,
                    onChanged: (v) => setState(() => _stageCategory = v!),
                  )),
                ]),
                const SizedBox(height: 14),

                // Numeric fields row 1
                Row(children: [
                  Expanded(child: _numField(_levelCtrl, 'Level Number *', min: 1, max: 100)),
                  const SizedBox(width: 12),
                  Expanded(child: _numField(_testNumCtrl, 'Test Number', min: 1, max: 999)),
                ]),
                const SizedBox(height: 14),

                // Numeric fields row 2
                Row(children: [
                  Expanded(child: _numField(_totalQCtrl, 'Total Questions *', min: 1, max: 200)),
                  const SizedBox(width: 12),
                  Expanded(child: _numField(_durationCtrl, 'Max Duration (min) *', min: 1, max: 300)),
                ]),
                const SizedBox(height: 14),

                _numField(_marksCtrl, 'Marks per Question *', min: 0.5, max: 10, isDouble: true),
                const SizedBox(height: 14),

                _field(_instrCtrl, 'Instructions (optional)', maxLines: 3),
                const SizedBox(height: 14),

                // Publish toggle
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.softRose,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.cherryBlossom),
                  ),
                  child: SwitchListTile(
                    title: const Text('Publish immediately', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.winePlum)),
                    subtitle: const Text('Students can see published tests', style: TextStyle(color: AppTheme.dustyMauve, fontSize: 12)),
                    value: _isPublished,
                    activeColor: AppTheme.winePlum,
                    onChanged: (v) => setState(() => _isPublished = v),
                  ),
                ),
                const SizedBox(height: 24),

                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isNew ? 'Create Test' : 'Save Changes'),
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

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Widget _field(TextEditingController ctrl, String label,
      {String? Function(String?)? validator, int maxLines = 1, String? hint}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _numField(TextEditingController ctrl, String label,
      {double min = 0, double max = 9999, bool isDouble = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        final n = double.tryParse(v.trim());
        if (n == null) return 'Invalid number';
        if (n < min) return '≥ ${min.toInt()}';
        if (n > max) return '≤ ${max.toInt()}';
        return null;
      },
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _Dropdown({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }
}
