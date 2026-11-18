import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import '../models/paper_model.dart';
import '../services/papers_service.dart';

class StudentPapersScreen extends StatefulWidget {
  const StudentPapersScreen({super.key});

  @override
  State<StudentPapersScreen> createState() => _StudentPapersScreenState();
}

class _StudentPapersScreenState extends State<StudentPapersScreen> {
  final PapersService _papersService = PapersService();
  final TextEditingController _searchController = TextEditingController();

  List<Paper> _papers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _loadingSignedUrlPaperId;
  String _loadingActionType = ''; // 'view' or 'download'

  int? _selectedYear;
  String _selectedStage = 'All'; // 'All', 'Prelims', 'Mains'
  String _selectedType = 'All'; // 'All', 'Question Paper', 'Answer Key', etc.
  String _selectedSubject = 'All'; // 'All' or subject name

  // Standard recent exam years for quick pill selection
  final List<int> _quickYears = [
    2026,
    2025,
    2024,
    2023,
    2022,
    2021,
    2020,
    2019,
    2018,
    2017,
    2016,
    2015,
  ];

  @override
  void initState() {
    super.initState();
    _loadPapers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPapers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final papers = await _papersService.fetchPublishedPapers(
        year: _selectedYear,
        stage: _selectedStage,
        subject: _selectedSubject,
        paperType: _selectedType,
        searchQuery: _searchController.text,
      );

      if (!mounted) return;
      setState(() {
        _papers = papers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load papers. Please check your internet connection and try again.';
        _isLoading = false;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedYear = null;
      _selectedStage = 'All';
      _selectedType = 'All';
      _selectedSubject = 'All';
      _searchController.clear();
    });
    _loadPapers();
  }

  Future<void> _openOrDownloadPdf(Paper paper, {required bool isDownload}) async {
    if (paper.filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No PDF file attached to this paper.')),
      );
      return;
    }

    setState(() {
      _loadingSignedUrlPaperId = paper.id;
      _loadingActionType = isDownload ? 'download' : 'view';
    });

    try {
      // Always generate a fresh temporary signed URL to handle any expired links
      final signedUrl = await _papersService.getSignedPdfUrl(
        paper.filePath,
        expiresInSeconds: 3600, // 1 hour validity
      );

      final uri = Uri.parse(signedUrl);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch external PDF viewer.')),
        );
      } else if (isDownload && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Opening download link in your browser/viewer.'),
            action: SnackBarAction(
              label: 'Copy Link',
              textColor: AppTheme.pastelPink,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: signedUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Secure download link copied to clipboard.')),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to access private document: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingSignedUrlPaperId = null;
          _loadingActionType = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group papers by examination year, newest year first
    final groupedPapers = PapersService.groupPapersByYear(_papers);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.winePlum,
          onRefresh: _loadPapers,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header & Filters Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.pastelPink,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: AppTheme.winePlum,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Previous Year Papers',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.winePlum,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Official UPSC CSE question papers, answer keys & syllabus',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.dustyMauve,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Search Bar (Title, Subject, Year)
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.softRose,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.cherryBlossom),
                            ),
                            child: TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _loadPapers(),
                              decoration: InputDecoration(
                                hintText: 'Search by paper title, subject or year...',
                                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.winePlum),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, color: AppTheme.dustyMauve),
                                        onPressed: () {
                                          _searchController.clear();
                                          _loadPapers();
                                        },
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.winePlum),
                                        onPressed: _loadPapers,
                                      ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Stage Filter (Prelims vs Mains)
                          const Text(
                            'Exam Stage',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.winePlum,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: ['All', 'Prelims', 'Mains'].map((stage) {
                                final isSelected = _selectedStage == stage;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(stage),
                                    selected: isSelected,
                                    selectedColor: AppTheme.cherryBlossom,
                                    backgroundColor: AppTheme.softRose,
                                    labelStyle: TextStyle(
                                      color: AppTheme.winePlum,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                    side: BorderSide(
                                      color: isSelected ? AppTheme.winePlum : AppTheme.cherryBlossom,
                                    ),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => _selectedStage = stage);
                                        _loadPapers();
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Paper Type Filter
                          const Text(
                            'Document Type',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.winePlum,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: PapersService.standardPaperTypes.map((type) {
                                final isSelected = _selectedType == type;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(type),
                                    selected: isSelected,
                                    selectedColor: AppTheme.cherryBlossom,
                                    backgroundColor: AppTheme.softRose,
                                    labelStyle: TextStyle(
                                      color: AppTheme.winePlum,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                    side: BorderSide(
                                      color: isSelected ? AppTheme.winePlum : AppTheme.cherryBlossom,
                                    ),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => _selectedType = type);
                                        _loadPapers();
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Examination Year Filter
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Browse by Examination Year',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.winePlum,
                                ),
                              ),
                              if (_selectedYear != null)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    setState(() => _selectedYear = null);
                                    _loadPapers();
                                  },
                                  child: const Text('Show All Years', style: TextStyle(fontSize: 12)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: const Text('All Years'),
                                    selected: _selectedYear == null,
                                    selectedColor: AppTheme.cherryBlossom,
                                    backgroundColor: AppTheme.softRose,
                                    labelStyle: TextStyle(
                                      color: AppTheme.winePlum,
                                      fontWeight: _selectedYear == null ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                    side: BorderSide(
                                      color: _selectedYear == null ? AppTheme.winePlum : AppTheme.cherryBlossom,
                                    ),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => _selectedYear = null);
                                        _loadPapers();
                                      }
                                    },
                                  ),
                                ),
                                ..._quickYears.map((year) {
                                  final isSelected = _selectedYear == year;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text('$year'),
                                      selected: isSelected,
                                      selectedColor: AppTheme.cherryBlossom,
                                      backgroundColor: AppTheme.softRose,
                                      labelStyle: TextStyle(
                                        color: AppTheme.winePlum,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                      side: BorderSide(
                                        color: isSelected ? AppTheme.winePlum : AppTheme.cherryBlossom,
                                      ),
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() => _selectedYear = year);
                                          _loadPapers();
                                        }
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Subject Filter Dropdown
                          Row(
                            children: [
                              const Text(
                                'Subject:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.winePlum,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.softRose,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.cherryBlossom),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedSubject,
                                      isExpanded: true,
                                      dropdownColor: AppTheme.softRose,
                                      style: const TextStyle(
                                        color: AppTheme.winePlum,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      items: PapersService.standardSubjects.map((sub) {
                                        return DropdownMenuItem<String>(
                                          value: sub,
                                          child: Text(sub),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _selectedSubject = val);
                                          _loadPapers();
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Filter Summary & Results Count
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Row(
                        children: [
                          Text(
                            _isLoading ? 'Loading papers...' : '${_papers.length} published papers found',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.winePlum,
                            ),
                          ),
                          const Spacer(),
                          if (_selectedYear != null ||
                              _selectedStage != 'All' ||
                              _selectedType != 'All' ||
                              _selectedSubject != 'All' ||
                              _searchController.text.isNotEmpty)
                            TextButton.icon(
                              onPressed: _resetFilters,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Reset filters', style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Body content
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.winePlum),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.errorColor),
                          const SizedBox(height: 14),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.winePlum, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadPapers,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_papers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppTheme.pastelPink.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.folder_open_rounded,
                              size: 46,
                              color: AppTheme.winePlum,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No published papers found',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.winePlum,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try adjusting your search query, year, stage, or subject filter.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppTheme.dustyMauve),
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            onPressed: _resetFilters,
                            icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                            label: const Text('Show All Papers'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                // Papers organized clearly by year, newest year first
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final yearKey = groupedPapers.keys.elementAt(index);
                        final papersInYear = groupedPapers[yearKey]!;

                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1000),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Year Section Header
                                Container(
                                  margin: const EdgeInsets.only(top: 14, bottom: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.alabasterGrey,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.cherryBlossom),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.winePlum),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Examination Year $yearKey',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppTheme.winePlum,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${papersInYear.length} ${papersInYear.length == 1 ? 'paper' : 'papers'}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.dustyMauve,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // List of papers in this year
                                ...papersInYear.map((paper) {
                                  final isBusy = _loadingSignedUrlPaperId == paper.id;
                                  final isViewing = isBusy && _loadingActionType == 'view';
                                  final isDownloading = isBusy && _loadingActionType == 'download';

                                  return _StudentPaperCard(
                                    paper: paper,
                                    isViewing: isViewing,
                                    isDownloading: isDownloading,
                                    isBusy: isBusy,
                                    onOpen: () => _openOrDownloadPdf(paper, isDownload: false),
                                    onDownload: () => _openOrDownloadPdf(paper, isDownload: true),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: groupedPapers.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentPaperCard extends StatelessWidget {
  final Paper paper;
  final bool isViewing;
  final bool isDownloading;
  final bool isBusy;
  final VoidCallback onOpen;
  final VoidCallback onDownload;

  const _StudentPaperCard({
    required this.paper,
    required this.isViewing,
    required this.isDownloading,
    required this.isBusy,
    required this.onOpen,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.softRose,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cherryBlossom),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Year, Stage, Type Badges
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Badge(
                  label: '${paper.year}',
                  backgroundColor: AppTheme.winePlum,
                  textColor: Colors.white,
                ),
                _Badge(
                  label: paper.stage,
                  backgroundColor: AppTheme.pastelPink,
                  textColor: AppTheme.winePlum,
                ),
                _Badge(
                  label: paper.paperType,
                  backgroundColor: AppTheme.cherryBlossom,
                  textColor: AppTheme.winePlum,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              paper.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.winePlum,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),

            // Subject and Exam
            Row(
              children: [
                const Icon(Icons.school_outlined, size: 15, color: AppTheme.dustyMauve),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${paper.subject} • ${paper.exam}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.dustyMauve,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            const Divider(height: 1, color: AppTheme.cherryBlossom),
            const SizedBox(height: 12),

            // Action Buttons: View PDF & Download
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isBusy ? null : onOpen,
                    icon: isViewing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.visibility_outlined, size: 18),
                    label: Text(isViewing ? 'Opening...' : 'View PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.winePlum,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onDownload,
                    icon: isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.winePlum,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text(isDownloading ? 'Downloading...' : 'Download'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.winePlum,
                      backgroundColor: AppTheme.pastelPink,
                      side: const BorderSide(color: AppTheme.winePlum),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _Badge({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
