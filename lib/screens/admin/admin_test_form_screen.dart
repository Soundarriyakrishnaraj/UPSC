// lib/screens/admin/admin_test_form_screen.dart
// Full-page screen for creating, editing, and managing test details and questions

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/test_model.dart';
import '../../services/test_service.dart';
import 'admin_question_form_screen.dart';

class AdminTestFormScreen extends StatefulWidget {
  final TestModel? existing;
  final String? testId;

  const AdminTestFormScreen({super.key, this.existing, this.testId});

  @override
  State<AdminTestFormScreen> createState() => _AdminTestFormScreenState();
}

class _AdminTestFormScreenState extends State<AdminTestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _svc = TestService();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _levelCtrl;
  late final TextEditingController _testNumCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _marksCtrl;
  late final TextEditingController _instrCtrl;

  String _upscStage = 'Prelims';
  String _stageCategory = 'Indian Polity';
  bool _isPublished = false;

  TestModel? _savedTest;
  List<TestQuestion> _questions = [];
  bool _hasAttempts = false;
  bool _loading = true;
  String? _error;
  bool _saving = false;
  bool _publishing = false;

  final List<String> _stages = ['Prelims', 'Mains'];
  final List<String> _categories = [
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
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _subjectCtrl = TextEditingController();
    _levelCtrl = TextEditingController(text: '1');
    _testNumCtrl = TextEditingController(text: '1');
    _durationCtrl = TextEditingController(text: '15');
    _marksCtrl = TextEditingController(text: '2.0');
    _instrCtrl = TextEditingController();

    _initForm();
  }

  Future<void> _initForm() async {
    final targetId = widget.testId ?? widget.existing?.id;

    if (targetId == null) {
      // New test
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _svc.fetchTestById(targetId),
        _svc.fetchQuestions(targetId),
        _svc.hasAttempts(targetId),
      ]);

      if (!mounted) return;

      final test = results[0] as TestModel;
      final questions = results[1] as List<TestQuestion>;
      final hasAttempts = results[2] as bool;

      // Populate text controllers
      _titleCtrl.text = test.title;
      _descCtrl.text = test.description ?? '';
      _subjectCtrl.text = test.subject;
      _levelCtrl.text = '${test.levelNumber}';
      _testNumCtrl.text = '${test.testNumber}';
      _durationCtrl.text = '${test.maxDurationMinutes}';
      _marksCtrl.text = '${test.marksPerQuestion}';
      _instrCtrl.text = test.instructions ?? '';
      _isPublished = test.isPublished;

      // Safely ensure dropdown lists contain existing values to prevent assertion crashes
      if (!_stages.contains(test.upscStage)) {
        _stages.add(test.upscStage);
      }
      _upscStage = test.upscStage;

      if (!_categories.contains(test.stageCategory) && test.stageCategory.isNotEmpty) {
        _categories.add(test.stageCategory);
      }
      _stageCategory = test.stageCategory.isNotEmpty ? test.stageCategory : 'Indian Polity';

      setState(() {
        _savedTest = test;
        _questions = questions;
        _hasAttempts = hasAttempts;
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
  void dispose() {
    for (final c in [
      _titleCtrl,
      _descCtrl,
      _subjectCtrl,
      _levelCtrl,
      _testNumCtrl,
      _durationCtrl,
      _marksCtrl,
      _instrCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    if (_savedTest == null) return;
    try {
      final qs = await _svc.fetchQuestions(_savedTest!.id);
      if (!mounted) return;
      setState(() {
        _questions = qs;
      });
    } catch (_) {}
  }

  Map<String, dynamic> _collectFormData() {
    return {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'subject': _subjectCtrl.text.trim(),
      'upsc_stage': _upscStage,
      'stage_category': _stageCategory,
      'level_number': int.tryParse(_levelCtrl.text.trim()) ?? 1,
      'test_number': int.tryParse(_testNumCtrl.text.trim()) ?? 1,
      'total_questions': _questions.isNotEmpty ? _questions.length : 1,
      'max_duration_minutes': int.tryParse(_durationCtrl.text.trim()) ?? 15,
      'marks_per_question': double.tryParse(_marksCtrl.text.trim()) ?? 2.0,
      'instructions': _instrCtrl.text.trim().isEmpty ? null : _instrCtrl.text.trim(),
      'is_published': _isPublished,
    };
  }

  Future<bool> _saveTestMetadata({bool showFeedback = true}) async {
    if (!_formKey.currentState!.validate()) return false;
    setState(() => _saving = true);

    try {
      final data = _collectFormData();
      if (_savedTest == null) {
        final created = await _svc.createTest(data);
        if (!mounted) return false;
        setState(() {
          _savedTest = created;
          _saving = false;
        });
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test draft saved! You can now add questions below.'),
              backgroundColor: AppTheme.winePlum,
            ),
          );
        }
      } else {
        final updated = await _svc.updateTest(_savedTest!.id, data);
        if (!mounted) return false;
        setState(() {
          _savedTest = updated;
          _saving = false;
        });
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test details updated successfully.'),
              backgroundColor: AppTheme.winePlum,
            ),
          );
        }
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving test: $e'), backgroundColor: AppTheme.winePlum),
      );
      return false;
    }
  }

  Future<void> _publishTest() async {
    if (_savedTest == null) {
      final saved = await _saveTestMetadata(showFeedback: false);
      if (!saved) return;
    }

    if (!mounted) return;

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot publish: Please add at least 1 question to this test first.'),
          backgroundColor: AppTheme.winePlum,
        ),
      );
      return;
    }

    setState(() => _publishing = true);
    try {
      await _svc.setPublished(_savedTest!.id, true);
      if (!mounted) return;
      setState(() {
        _isPublished = true;
        _publishing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Test "${_titleCtrl.text}" published successfully! It is now live on the Destination map.',
          ),
          backgroundColor: AppTheme.winePlum,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not publish: $e'), backgroundColor: AppTheme.winePlum),
      );
    }
  }

  Future<void> _unpublishTest() async {
    if (_savedTest == null) return;
    setState(() => _publishing = true);
    try {
      await _svc.setPublished(_savedTest!.id, false);
      if (!mounted) return;
      setState(() {
        _isPublished = false;
        _publishing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test unpublished and moved back to Drafts.'),
          backgroundColor: AppTheme.winePlum,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.winePlum),
      );
    }
  }

  Future<void> _openQuestionForm({TestQuestion? q}) async {
    if (_hasAttempts && q != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Questions cannot be modified because student attempts already exist for this test.'),
          backgroundColor: AppTheme.winePlum,
        ),
      );
      return;
    }

    if (_savedTest == null) {
      final saved = await _saveTestMetadata(showFeedback: false);
      if (!saved) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill and save test details first.'),
            backgroundColor: AppTheme.winePlum,
          ),
        );
        return;
      }
    }

    if (!mounted) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminQuestionFormScreen(
          testId: _savedTest!.id,
          nextNumber: _questions.length + 1,
          existing: q,
        ),
      ),
    );

    if (saved == true) {
      await _loadQuestions();
    }
  }

  Future<void> _deleteQuestion(TestQuestion q) async {
    if (_hasAttempts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Questions cannot be deleted because student attempts already exist for this test.'),
          backgroundColor: AppTheme.winePlum,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question?'),
        content: Text('Question #${q.questionNumber} will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.winePlum),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _svc.deleteQuestion(q.id, testId: _savedTest!.id);
      await _loadQuestions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting question: $e'), backgroundColor: AppTheme.winePlum),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = _savedTest == null && widget.testId == null;

    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.alabasterGrey,
        appBar: AppBar(
          title: Text(isNew ? 'Create New Test' : 'Loading Test Details...'),
          backgroundColor: AppTheme.alabasterGrey,
          foregroundColor: AppTheme.winePlum,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.winePlum),
              SizedBox(height: 16),
              Text(
                'Loading test data and questions from Supabase...',
                style: TextStyle(color: AppTheme.winePlum, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.alabasterGrey,
        appBar: AppBar(
          title: const Text('Error Loading Test'),
          backgroundColor: AppTheme.alabasterGrey,
          foregroundColor: AppTheme.winePlum,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppTheme.winePlum, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Could not load test details:\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.winePlum, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _initForm,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: const Text('Retry', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.winePlum),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.alabasterGrey,
      appBar: AppBar(
        title: Text(isNew ? 'Create New Test' : 'Edit Test — ${_titleCtrl.text}'),
        backgroundColor: AppTheme.alabasterGrey,
        foregroundColor: AppTheme.winePlum,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isPublished
                  ? AppTheme.winePlum
                  : AppTheme.dustyMauve.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              _isPublished ? '● Published' : '○ Draft',
              style: TextStyle(
                color: _isPublished ? Colors.white : AppTheme.winePlum,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // Historical Protection Banner
            if (_hasAttempts) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.pastelPink.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.winePlum, width: 1.2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppTheme.winePlum, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Student examination attempts exist for this test. Core questions are protected from modification or deletion to preserve examination records.',
                        style: TextStyle(fontSize: 12, color: AppTheme.winePlum, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Section 1: Basic Information ──
            _buildSectionHeader('1. Test Information', Icons.description_outlined),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cherryBlossom.withValues(alpha: 0.4)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Test Title *',
                      hintText: 'e.g. Indian Polity & Governance Mock 1',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Please enter a test title' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _subjectCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Subject *',
                      hintText: 'e.g. Indian Polity / General Studies I',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Please enter the subject' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description / Overview',
                      hintText: 'Brief summary of topics covered in this test...',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Section 2: Classification ──
            _buildSectionHeader('2. UPSC Stage & Category', Icons.category_outlined),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cherryBlossom.withValues(alpha: 0.4)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _upscStage,
                          decoration: const InputDecoration(labelText: 'UPSC Stage'),
                          items: _stages
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _upscStage = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _stageCategory,
                          decoration: const InputDecoration(labelText: 'Category'),
                          isExpanded: true,
                          items: _categories
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _stageCategory = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _levelCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Destination Level *',
                            hintText: '1 to 100',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 1 || n > 100) return '1 to 100';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: _testNumCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Test Number *',
                            hintText: 'e.g. 1',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Section 3: Timing & Scoring ──
            _buildSectionHeader('3. Duration & Marks', Icons.timer_outlined),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cherryBlossom.withValues(alpha: 0.4)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _durationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Max Duration (mins) *',
                            hintText: 'e.g. 15',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 1) return 'Min 1 min';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: _marksCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Marks / Question *',
                            hintText: 'e.g. 2.0',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Positive number';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _instrCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Examination Instructions',
                      hintText:
                          'e.g. Each question carries 2 marks. 1/3 negative marking for wrong answers.',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Section 4: Questions & Answers (Integrated) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(
                  '4. Questions & Answers (${_questions.length})',
                  Icons.quiz_outlined,
                ),
                if (_savedTest != null && !_hasAttempts)
                  ElevatedButton.icon(
                    onPressed: () => _openQuestionForm(),
                    icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'Add Question',
                      style: TextStyle(fontSize: 13, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.winePlum,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_savedTest == null)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cherryBlossom.withValues(alpha: 0.4)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 40, color: AppTheme.dustyMauve),
                    const SizedBox(height: 10),
                    const Text(
                      'Save Test to Start Adding Questions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.winePlum,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Once you tap "Save & Continue" below, you can add and manage all MCQs right here on this screen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.dustyMauve),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : () => _saveTestMetadata(),
                      icon: const Icon(Icons.save_outlined, color: Colors.white),
                      label: Text(
                        _saving ? 'Saving...' : 'Save & Continue',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.winePlum,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              )
            else if (_questions.isEmpty)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cherryBlossom.withValues(alpha: 0.4)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.quiz_outlined, size: 44, color: AppTheme.dustyMauve),
                    const SizedBox(height: 10),
                    const Text(
                      'No questions added yet',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.winePlum,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Add questions with multiple-choice options and correct answers. When you publish, the test will appear on the Destination map.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.dustyMauve),
                    ),
                    const SizedBox(height: 16),
                    if (!_hasAttempts)
                      ElevatedButton.icon(
                        onPressed: () => _openQuestionForm(),
                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                        label: const Text(
                          'Add First Question',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.winePlum,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.pastelPink.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cherryBlossom.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.winePlum),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_questions.length} question(s) loaded. Question count will automatically sync when publishing.',
                            style: const TextStyle(fontSize: 12, color: AppTheme.winePlum),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._questions.map((q) => _buildQuestionCard(q)),
                  if (!_hasAttempts) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: () => _openQuestionForm(),
                        icon: const Icon(Icons.add_rounded, color: AppTheme.winePlum),
                        label: const Text(
                          'Add Another Question',
                          style: TextStyle(
                            color: AppTheme.winePlum,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.winePlum, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Save Draft Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _saveTestMetadata(),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, color: AppTheme.winePlum),
                  label: Text(
                    _saving ? 'Saving...' : 'Save Draft',
                    style: const TextStyle(
                      color: AppTheme.winePlum,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.winePlum, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Publish / Unpublish Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _publishing
                      ? null
                      : (_isPublished ? _unpublishTest : _publishTest),
                  icon: _publishing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Icon(
                          _isPublished
                              ? Icons.file_download_outlined
                              : Icons.publish_rounded,
                          color: Colors.white,
                        ),
                  label: Text(
                    _publishing
                        ? 'Updating...'
                        : (_isPublished ? 'Unpublish' : 'Publish Test'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPublished ? AppTheme.dustyMauve : AppTheme.winePlum,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.winePlum),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.winePlum,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(TestQuestion q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cherryBlossom.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.winePlum,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q${q.questionNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F2E7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF245C35)),
                ),
                child: Text(
                  'Correct: Option ${q.correctOption}',
                  style: const TextStyle(
                    color: Color(0xFF245C35),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (!_hasAttempts) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.winePlum),
                  onPressed: () => _openQuestionForm(q: q),
                  tooltip: 'Edit Question',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.dustyMauve),
                  onPressed: () => _deleteQuestion(q),
                  tooltip: 'Delete Question',
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            q.questionText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A) ${q.optionA}  |  B) ${q.optionB}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppTheme.dustyMauve),
          ),
        ],
      ),
    );
  }
}
