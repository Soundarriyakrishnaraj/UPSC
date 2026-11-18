// lib/screens/admin/admin_test_management_screen.dart
// Admin Test Management – list, stats, search, filter, publish/unpublish/archive

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/test_model.dart';
import '../../services/test_service.dart';
import 'admin_test_form_screen.dart';
import 'admin_question_management_screen.dart';
import 'admin_test_analytics_screen.dart';

class AdminTestManagementScreen extends StatefulWidget {
  const AdminTestManagementScreen({super.key});

  @override
  State<AdminTestManagementScreen> createState() =>
      _AdminTestManagementScreenState();
}

class _AdminTestManagementScreenState
    extends State<AdminTestManagementScreen> {
  final _svc = TestService();
  final _searchCtrl = TextEditingController();

  List<TestModel> _tests = [];
  Map<String, int> _stats = {};
  bool _loading = true;
  String? _error;

  String? _filterStage;    // 'Prelims' | 'Mains'
  bool? _filterPublished;  // true | false | null = all

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _svc.fetchAllTests(
          searchQuery: _searchCtrl.text,
          upscStage: _filterStage,
          isPublished: _filterPublished,
        ),
        _svc.fetchAdminStats(),
      ]);
      if (!mounted) return;
      setState(() {
        _tests = results[0] as List<TestModel>;
        _stats = results[1] as Map<String, int>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _togglePublish(TestModel t) async {
    try {
      final willPublish = !t.isPublished;
      await _svc.setPublished(t.id, willPublish);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(willPublish
            ? 'Test "${t.title}" published! It is now live on the Destination map.'
            : 'Test "${t.title}" unpublished and moved to drafts.'),
        backgroundColor: AppTheme.winePlum,
      ));
      _load();
    } catch (e) {
      if (!mounted) return;
      _showError('Could not update: $e');
    }
  }

  Future<void> _archive(TestModel t) async {
    final confirm = await _confirmDialog(
      'Archive "${t.title}"?',
      'The test will be hidden from students and cannot be published again. Questions are preserved.',
    );
    if (!confirm) return;
    try {
      await _svc.archiveTest(t.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      _showError('Could not archive: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.winePlum));
  }

  Future<bool> _confirmDialog(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.winePlum),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openForm({TestModel? test}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminTestFormScreen(existing: test, testId: test?.id),
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.alabasterGrey,
      appBar: AppBar(
        title: const Text('Test Management'),
        backgroundColor: AppTheme.alabasterGrey,
        foregroundColor: AppTheme.winePlum,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load, tooltip: 'Refresh'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Test'),
        backgroundColor: AppTheme.winePlum,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildStats()),
                      SliverToBoxAdapter(child: _buildFilters()),
                      _tests.isEmpty
                          ? const SliverFillRemaining(child: _EmptyView())
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => _TestCard(
                                  test: _tests[i],
                                  onEdit: () => _openForm(test: _tests[i]),
                                  onTogglePublish: () => _togglePublish(_tests[i]),
                                  onManageQuestions: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminQuestionManagementScreen(test: _tests[i]),
                                    ),
                                  ).then((_) => _load()),
                                  onViewAnalytics: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminTestAnalyticsScreen(test: _tests[i]),
                                    ),
                                  ),
                                  onArchive: () => _archive(_tests[i]),
                                ),
                                childCount: _tests.length,
                              ),
                            ),
                      const SliverToBoxAdapter(child: SizedBox(height: 90)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStats() {
    final total = _stats['total'] ?? 0;
    final pub = _stats['published'] ?? 0;
    final unpub = _stats['unpublished'] ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _StatChip(label: 'Total', value: '$total', color: AppTheme.winePlum),
          const SizedBox(width: 10),
          _StatChip(label: 'Published', value: '$pub', color: const Color(0xFF2E7D32)),
          const SizedBox(width: 10),
          _StatChip(label: 'Drafts', value: '$unpub', color: AppTheme.dustyMauve),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search tests…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () { _searchCtrl.clear(); _load(); })
                  : null,
            ),
            onChanged: (_) => _load(),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filterPublished == null && _filterStage == null,
                  onTap: () { setState(() { _filterPublished = null; _filterStage = null; }); _load(); },
                ),
                const SizedBox(width: 8),
                _FilterChip(label: 'Prelims', selected: _filterStage == 'Prelims',
                    onTap: () { setState(() { _filterStage = _filterStage == 'Prelims' ? null : 'Prelims'; }); _load(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Mains', selected: _filterStage == 'Mains',
                    onTap: () { setState(() { _filterStage = _filterStage == 'Mains' ? null : 'Mains'; }); _load(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Published', selected: _filterPublished == true,
                    onTap: () { setState(() { _filterPublished = _filterPublished == true ? null : true; }); _load(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Drafts', selected: _filterPublished == false,
                    onTap: () { setState(() { _filterPublished = _filterPublished == false ? null : false; }); _load(); }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────

class _TestCard extends StatelessWidget {
  final TestModel test;
  final VoidCallback onEdit;
  final VoidCallback onTogglePublish;
  final VoidCallback onManageQuestions;
  final VoidCallback onViewAnalytics;
  final VoidCallback onArchive;

  const _TestCard({
    required this.test,
    required this.onEdit,
    required this.onTogglePublish,
    required this.onManageQuestions,
    required this.onViewAnalytics,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final stage = stageForLevel(test.levelNumber);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(stage.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(test.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.winePlum)),
                      const SizedBox(height: 2),
                      Text('Level ${test.levelNumber} · ${test.upscStage} · ${test.stageCategory}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.dustyMauve)),
                    ],
                  ),
                ),
                _StatusBadge(isPublished: test.isPublished),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoPill(Icons.quiz_outlined, '${test.totalQuestions} Qs'),
                _InfoPill(Icons.timer_outlined, '${test.maxDurationMinutes} min'),
                _InfoPill(Icons.star_outline_rounded, '${test.marksPerQuestion} marks/Q'),
                _InfoPill(Icons.subject_rounded, test.subject),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                _ActionBtn(icon: Icons.edit_outlined, label: 'Edit', onTap: onEdit),
                _ActionBtn(
                  icon: test.isPublished ? Icons.unpublished_outlined : Icons.publish_rounded,
                  label: test.isPublished ? 'Unpublish' : 'Publish',
                  onTap: onTogglePublish,
                  color: test.isPublished ? AppTheme.dustyMauve : const Color(0xFF2E7D32),
                ),
                _ActionBtn(
                    icon: Icons.help_outline_rounded, label: 'Questions', onTap: onManageQuestions),
                _ActionBtn(
                    icon: Icons.analytics_outlined, label: 'Analytics', onTap: onViewAnalytics),
                _ActionBtn(icon: Icons.archive_outlined, label: 'Archive', onTap: onArchive,
                    color: AppTheme.dustyMauve),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isPublished;
  const _StatusBadge({required this.isPublished});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPublished ? const Color(0xFFE8F5E9) : AppTheme.pastelPink,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isPublished ? const Color(0xFF2E7D32) : AppTheme.dustyMauve, width: 0.8),
      ),
      child: Text(
        isPublished ? 'Published' : 'Draft',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isPublished ? const Color(0xFF2E7D32) : AppTheme.dustyMauve),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: AppTheme.dustyMauve),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.dustyMauve)),
    ]);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppTheme.winePlum,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ]),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.winePlum : AppTheme.pastelPink,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.winePlum : AppTheme.cherryBlossom),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.winePlum)),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.quiz_outlined, size: 60, color: AppTheme.cherryBlossom),
          const SizedBox(height: 14),
          const Text('No tests yet', style: TextStyle(fontSize: 18, color: AppTheme.winePlum, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Tap + to create your first test', style: TextStyle(color: AppTheme.dustyMauve)),
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
