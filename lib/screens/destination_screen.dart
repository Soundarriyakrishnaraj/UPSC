// lib/screens/destination_screen.dart
// Interactive Destination map & subject/category test catalog — educational theme, app palette only

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/test_model.dart';
import '../services/test_service.dart';
import 'test_detail_screen.dart';

class DestinationScreen extends StatefulWidget {
  const DestinationScreen({super.key});

  @override
  State<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends State<DestinationScreen>
    with TickerProviderStateMixin {
  final _svc = TestService();

  List<TestModel> _tests = [];
  Map<String, StudentLevelProgress> _progress = {}; // testId → progress
  Set<String> _submittedTestIds = {};
  bool _loading = true;
  String? _error;

  // Filters & View Mode
  String? _selectedCategory; // null = All
  String? _selectedSubject;  // null = All
  bool _showCatalogView = false; // false = Map, true = Catalog List

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.08).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _load();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _svc.fetchPublishedTests(),
        _svc.fetchMyProgress(),
        _svc.fetchMyAttempts(limit: 100),
      ]);
      if (!mounted) return;

      final tests = results[0] as List<TestModel>;
      final progressList = results[1] as List<StudentLevelProgress>;
      final attempts = results[2] as List<TestAttempt>;

      // Track tests with confirmed submitted attempts
      final submittedIds = attempts
          .where((a) => a.isSubmitted)
          .map((a) => a.testId)
          .toSet();

      setState(() {
        _tests = tests;
        _progress = {for (final p in progressList) p.testId: p};
        _submittedTestIds = submittedIds;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  bool _isTestCompleted(String testId) {
    if (_submittedTestIds.contains(testId)) return true;
    final p = _progress[testId];
    return p != null && p.isCompleted;
  }

  LevelState _levelState(TestModel test) {
    if (_isTestCompleted(test.id)) return LevelState.completed;
    // All published tests are accessible and unlocked to attempt in any order
    return LevelState.unlocked;
  }

  List<TestModel> get _filteredTests {
    return _tests.where((t) {
      if (_selectedCategory != null) {
        final matchesCat = t.stageCategory == _selectedCategory || t.upscStage == _selectedCategory;
        if (!matchesCat) return false;
      }
      if (_selectedSubject != null && t.subject != _selectedSubject) {
        return false;
      }
      return true;
    }).toList();
  }

  List<String> get _availableCategories {
    final cats = <String>{};
    for (final t in _tests) {
      if (t.upscStage.isNotEmpty) cats.add(t.upscStage);
      if (t.stageCategory.isNotEmpty) cats.add(t.stageCategory);
    }
    final sorted = cats.toList()..sort();
    return sorted;
  }

  List<String> get _availableSubjects {
    final subs = _tests.map((t) => t.subject).where((s) => s.isNotEmpty).toSet().toList()..sort();
    return subs;
  }

  Future<void> _onLevelTap(TestModel test) async {
    final state = _levelState(test);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TestDetailScreen(test: test, levelState: state),
      ),
    );
    // Always refresh progression and test completion on return
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.alabasterGrey,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      SliverToBoxAdapter(child: _buildFilterSection()),
                      if (_filteredTests.isEmpty)
                        const SliverFillRemaining(child: _EmptyMapView())
                      else if (_showCatalogView)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) => _TestCatalogCard(
                                test: _filteredTests[i],
                                isCompleted: _isTestCompleted(_filteredTests[i].id),
                                bestStars: _progress[_filteredTests[i].id]?.bestStars ?? 0,
                                onTap: () => _onLevelTap(_filteredTests[i]),
                              ),
                              childCount: _filteredTests.length,
                            ),
                          ),
                        )
                      else
                        SliverToBoxAdapter(child: _buildMap()),
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    final completedCount = _tests.where((t) => _isTestCompleted(t.id)).length;
    final stars = _progress.values.fold(0, (s, p) => s + p.bestStars);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.winePlum, Color(0xFF5D3039)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'UPSC DESTINATION',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your Learning Journey',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Row(children: [
              _HeaderStat(icon: Icons.check_circle_outline_rounded, label: 'Completed', value: '$completedCount'),
              const SizedBox(width: 20),
              _HeaderStat(icon: Icons.star_outline_rounded, label: 'Stars', value: '$stars'),
              const SizedBox(width: 20),
              _HeaderStat(icon: Icons.map_outlined, label: 'Total Tests', value: '${_tests.length}'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    final categories = _availableCategories;
    final subjects = _availableSubjects;
    final hasActiveFilter = _selectedCategory != null || _selectedSubject != null;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // View Mode Switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showCatalogView = false),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_showCatalogView ? AppTheme.winePlum : AppTheme.alabasterGrey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 16, color: !_showCatalogView ? Colors.white : AppTheme.winePlum),
                          const SizedBox(width: 6),
                          Text(
                            'Winding Map',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: !_showCatalogView ? Colors.white : AppTheme.winePlum,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showCatalogView = true),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _showCatalogView ? AppTheme.winePlum : AppTheme.alabasterGrey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.list_alt_rounded, size: 16, color: _showCatalogView ? Colors.white : AppTheme.winePlum),
                          const SizedBox(width: 6),
                          Text(
                            'Test Catalog (${_filteredTests.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _showCatalogView ? Colors.white : AppTheme.winePlum,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Categories Chips
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(
                  label: 'All Categories',
                  isSelected: _selectedCategory == null,
                  onTap: () => setState(() => _selectedCategory = null),
                ),
                ...categories.map((cat) => _buildFilterChip(
                      label: cat,
                      isSelected: _selectedCategory == cat,
                      onTap: () => setState(() => _selectedCategory = cat),
                    )),
              ],
            ),
          ),

          // Subjects Chips (if multiple subjects exist)
          if (subjects.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterChip(
                    label: 'All Subjects',
                    isSelected: _selectedSubject == null,
                    onTap: () => setState(() => _selectedSubject = null),
                  ),
                  ...subjects.map((sub) => _buildFilterChip(
                        label: sub,
                        isSelected: _selectedSubject == sub,
                        onTap: () => setState(() => _selectedSubject = sub),
                      )),
                ],
              ),
            ),
          ],

          // Active Filter Reset
          if (hasActiveFilter) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Showing ${_filteredTests.length} tests matching filters',
                    style: const TextStyle(fontSize: 11, color: AppTheme.dustyMauve, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => setState(() {
                      _selectedCategory = null;
                      _selectedSubject = null;
                    }),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                      child: Text(
                        'Clear Filters',
                        style: TextStyle(fontSize: 11, color: AppTheme.winePlum, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppTheme.winePlum,
        backgroundColor: AppTheme.pastelPink.withValues(alpha: 0.35),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.winePlum,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? AppTheme.winePlum : AppTheme.cherryBlossom.withValues(alpha: 0.5),
        ),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildMap() {
    final tests = _filteredTests;
    final List<Widget> stageWidgets = [];

    for (final stage in kStages) {
      final stageLevels = tests
          .where((t) => t.levelNumber >= stage.startLevel && t.levelNumber <= stage.endLevel)
          .toList();
      if (stageLevels.isEmpty) continue;

      stageWidgets.add(_StageSection(
        stage: stage,
        tests: stageLevels,
        progress: _progress,
        submittedTestIds: _submittedTestIds,
        pulseAnim: _pulseAnim,
        levelState: _levelState,
        onTap: _onLevelTap,
      ));
    }
    return Column(children: stageWidgets);
  }
}

// ─────────────────────────────────────────────
enum LevelState { locked, unlocked, completed }

// ─────────────────────────────────────────────
class _StageSection extends StatelessWidget {
  final StageInfo stage;
  final List<TestModel> tests;
  final Map<String, StudentLevelProgress> progress;
  final Set<String> submittedTestIds;
  final Animation<double> pulseAnim;
  final LevelState Function(TestModel) levelState;
  final void Function(TestModel) onTap;

  const _StageSection({
    required this.stage,
    required this.tests,
    required this.progress,
    required this.submittedTestIds,
    required this.pulseAnim,
    required this.levelState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(stage.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stage ${stage.stageNumber}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.dustyMauve, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    Text(stage.name,
                        style: const TextStyle(fontSize: 16, color: AppTheme.winePlum, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              _StageSummary(
                tests: tests,
                progress: progress,
                submittedTestIds: submittedTestIds,
              ),
            ],
          ),
        ),
        _WindingLevelRow(
          tests: tests,
          progress: progress,
          pulseAnim: pulseAnim,
          levelState: levelState,
          onTap: onTap,
        ),
        const Divider(indent: 20, endIndent: 20, height: 1),
      ],
    );
  }
}

class _StageSummary extends StatelessWidget {
  final List<TestModel> tests;
  final Map<String, StudentLevelProgress> progress;
  final Set<String> submittedTestIds;

  const _StageSummary({
    required this.tests,
    required this.progress,
    required this.submittedTestIds,
  });

  @override
  Widget build(BuildContext context) {
    final done = tests.where((t) => submittedTestIds.contains(t.id) || progress[t.id]?.isCompleted == true).length;
    final totalStars = tests.fold(0, (s, t) => s + (progress[t.id]?.bestStars ?? 0));

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('$done/${tests.length}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.winePlum)),
      Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, size: 13, color: AppTheme.cherryBlossom),
        const SizedBox(width: 2),
        Text('$totalStars', style: const TextStyle(fontSize: 11, color: AppTheme.dustyMauve)),
      ]),
    ]);
  }
}

class _WindingLevelRow extends StatelessWidget {
  final List<TestModel> tests;
  final Map<String, StudentLevelProgress> progress;
  final Animation<double> pulseAnim;
  final LevelState Function(TestModel) levelState;
  final void Function(TestModel) onTap;

  const _WindingLevelRow({
    required this.tests,
    required this.progress,
    required this.pulseAnim,
    required this.levelState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 14,
        alignment: WrapAlignment.center,
        children: tests.map((test) {
          final state = levelState(test);
          final p = progress[test.id];
          return _LevelNode(
            test: test,
            state: state,
            bestStars: p?.bestStars ?? 0,
            pulseAnim: pulseAnim,
            onTap: () => onTap(test),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Test Box with High-Contrast Completed Styling
// ─────────────────────────────────────────────

class _LevelNode extends StatelessWidget {
  final TestModel test;
  final LevelState state;
  final int bestStars;
  final Animation<double> pulseAnim;
  final VoidCallback onTap;

  const _LevelNode({
    required this.test,
    required this.state,
    required this.bestStars,
    required this.pulseAnim,
    required this.onTap,
  });

  bool get _isCompleted => state == LevelState.completed;

  // Strict Palette Colors: Completed is bold #723D46 (Wine Plum), Available is #EAD9DE (Soft Rose)
  Color get _bgColor => _isCompleted ? AppTheme.winePlum : AppTheme.softRose;
  Color get _borderColor => _isCompleted ? AppTheme.cherryBlossom : AppTheme.cherryBlossom.withValues(alpha: 0.7);

  @override
  Widget build(BuildContext context) {
    Widget node = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor, width: _isCompleted ? 2.0 : 1.2),
          boxShadow: [
            BoxShadow(
              color: _isCompleted
                  ? AppTheme.winePlum.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: _isCompleted ? 8 : 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Level number badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _isCompleted ? Colors.white.withValues(alpha: 0.22) : AppTheme.winePlum.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Lvl ${test.levelNumber}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _isCompleted ? Colors.white : AppTheme.winePlum,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Icon
            Icon(
              _isCompleted ? Icons.check_circle_rounded : Icons.menu_book_rounded,
              size: 24,
              color: _isCompleted ? Colors.white : AppTheme.winePlum,
            ),
            const SizedBox(height: 4),

            // Completed Stars or Start Label
            if (_isCompleted)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => Icon(
                    i < bestStars ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 13,
                    color: Colors.amber.shade300,
                  ),
                ),
              )
            else
              const Text(
                'Start',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.winePlum,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );

    // Pulse uncompleted tests to invite students to begin
    if (!_isCompleted) {
      node = ScaleTransition(scale: pulseAnim, child: node);
    }
    return node;
  }
}

// ─────────────────────────────────────────────
// Direct Test Catalog Card (Subject & Category List View)
// ─────────────────────────────────────────────

class _TestCatalogCard extends StatelessWidget {
  final TestModel test;
  final bool isCompleted;
  final int bestStars;
  final VoidCallback onTap;

  const _TestCatalogCard({
    required this.test,
    required this.isCompleted,
    required this.bestStars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCompleted ? AppTheme.softRose.withValues(alpha: 0.4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? AppTheme.winePlum : AppTheme.cherryBlossom.withValues(alpha: 0.5),
          width: isCompleted ? 1.5 : 1.0,
        ),
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
                  color: isCompleted ? AppTheme.winePlum : AppTheme.pastelPink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Level ${test.levelNumber}',
                  style: TextStyle(
                    color: isCompleted ? Colors.white : AppTheme.winePlum,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.alabasterGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  test.upscStage,
                  style: const TextStyle(color: AppTheme.winePlum, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              if (isCompleted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.winePlum,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '✓ COMPLETED',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ...List.generate(
                      3,
                      (i) => Icon(
                        i < bestStars ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 14,
                        color: AppTheme.winePlum,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            test.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.winePlum,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${test.stageCategory}  •  ${test.subject}',
            style: const TextStyle(fontSize: 12, color: AppTheme.dustyMauve),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${test.totalQuestions} Questions  •  ${test.maxDurationMinutes} mins  •  ${(test.totalQuestions * test.marksPerQuestion).toStringAsFixed(0)} Marks',
                style: const TextStyle(fontSize: 11, color: AppTheme.dustyMauve),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.winePlum,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(0, 34),
                ),
                child: Text(
                  isCompleted ? 'Retake' : 'Start',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _HeaderStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: Colors.white70),
      const SizedBox(width: 4),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
      ]),
    ]);
  }
}

class _EmptyMapView extends StatelessWidget {
  const _EmptyMapView();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.quiz_outlined, size: 54, color: AppTheme.cherryBlossom),
            SizedBox(height: 14),
            Text('No tests match the selected filter',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.winePlum)),
            SizedBox(height: 6),
            Text('Try selecting "All Categories" or "All Subjects" above.',
                textAlign: TextAlign.center, style: TextStyle(color: AppTheme.dustyMauve, fontSize: 13)),
          ]),
        ),
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
            ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry')),
          ]),
        ),
      );
}
