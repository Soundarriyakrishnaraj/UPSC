import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../models/paper_model.dart';
import '../../services/papers_service.dart';
import 'admin_paper_form_dialog.dart';
import 'admin_test_management_screen.dart';

class AdminPapersScreen extends StatefulWidget {
  const AdminPapersScreen({super.key});

  @override
  State<AdminPapersScreen> createState() => _AdminPapersScreenState();
}

class _AdminPapersScreenState extends State<AdminPapersScreen> {
  final PapersService _papersService = PapersService();
  final TextEditingController _searchController = TextEditingController();

  bool _isCheckingAuth = true;
  bool _isAdmin = false;

  List<Paper> _papers = [];
  bool _isLoadingPapers = false;
  String? _errorMessage;

  String _statusFilter = 'All'; // 'All', 'Published', 'Draft'
  String _stageFilter = 'All'; // 'All', 'Prelims', 'Mains'
  String _subjectFilter = 'All'; // 'All' or subject name
  String _typeFilter = 'All'; // 'All', 'Question Paper', 'Answer Key', etc.
  int? _yearFilter;

  String? _operatingPaperId;
  String _operationMessage = '';

  @override
  void initState() {
    super.initState();
    _verifyAdminAccess();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _verifyAdminAccess() async {
    setState(() {
      _isCheckingAuth = true;
    });

    try {
      final hasAdminAccess = await _papersService.checkIsAdmin();

      if (!mounted) return;
      setState(() {
        _isAdmin = hasAdminAccess;
        _isCheckingAuth = false;
      });

      if (hasAdminAccess) {
        _loadPapers();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
        _isCheckingAuth = false;
      });
    }
  }

  Future<void> _loadPapers() async {
    if (!_isAdmin) return;

    setState(() {
      _isLoadingPapers = true;
      _errorMessage = null;
    });

    try {
      bool? isPublished;
      if (_statusFilter == 'Published') isPublished = true;
      if (_statusFilter == 'Draft') isPublished = false;

      final papers = await _papersService.fetchAllPapers(
        year: _yearFilter,
        stage: _stageFilter,
        subject: _subjectFilter,
        paperType: _typeFilter,
        isPublished: isPublished,
        searchQuery: _searchController.text,
      );

      if (!mounted) return;
      setState(() {
        _papers = papers;
        _isLoadingPapers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load papers. Please check your connection and try again.';
        _isLoadingPapers = false;
      });
    }
  }

  Future<void> _openAddPaperDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AdminPaperFormDialog(),
    );

    if (result == true) {
      _loadPapers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paper saved successfully.')),
        );
      }
    }
  }

  Future<void> _openEditPaperDialog(Paper paper) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdminPaperFormDialog(paperToEdit: paper),
    );

    if (result == true) {
      _loadPapers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paper updated successfully.')),
        );
      }
    }
  }

  /// Replace PDF directly from list item
  Future<void> _replacePdf(Paper paper) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (files.isEmpty) return;

      final file = files.first;
      final bytes = await file.xFile.readAsBytes();

      setState(() {
        _operatingPaperId = paper.id;
        _operationMessage = 'Replacing PDF safely...';
      });

      final updated = await _papersService.replacePaperPdf(
        paper: paper,
        newPdfBytes: bytes,
        newFileName: file.name,
      );

      if (!mounted) return;
      setState(() {
        final idx = _papers.indexWhere((p) => p.id == paper.id);
        if (idx != -1) {
          _papers[idx] = updated;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF document replaced successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not replace PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _operatingPaperId = null;
          _operationMessage = '';
        });
      }
    }
  }

  Future<void> _togglePublishStatus(Paper paper) async {
    final newStatus = !paper.isPublished;
    setState(() {
      _operatingPaperId = paper.id;
      _operationMessage = newStatus ? 'Publishing...' : 'Unpublishing...';
    });

    try {
      await _papersService.togglePublishStatus(paper.id, newStatus);
      if (!mounted) return;

      setState(() {
        final index = _papers.indexWhere((p) => p.id == paper.id);
        if (index != -1) {
          _papers[index] = paper.copyWith(isPublished: newStatus);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus ? 'Paper published to students.' : 'Paper moved to drafts (unpublished).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update status: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _operatingPaperId = null;
          _operationMessage = '';
        });
      }
    }
  }

  Future<void> _confirmDeletePaper(Paper paper) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text(
          'Delete Paper?',
          style: TextStyle(
            color: AppTheme.winePlum,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to permanently delete "${paper.title}"?'),
            const SizedBox(height: 10),
            const Text(
              'This will delete the paper record and permanently delete the associated PDF from storage.',
              style: TextStyle(fontSize: 12, color: AppTheme.errorColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _operatingPaperId = paper.id;
        _operationMessage = 'Deleting paper and file...';
      });

      try {
        await _papersService.deletePaperSafely(paper);
        if (!mounted) return;

        setState(() {
          _papers.removeWhere((p) => p.id == paper.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paper and file deleted successfully.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting paper: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _operatingPaperId = null;
            _operationMessage = '';
          });
        }
      }
    }
  }

  Future<void> _previewPdf(Paper paper) async {
    if (paper.filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No PDF file attached to this paper.')),
      );
      return;
    }

    setState(() {
      _operatingPaperId = paper.id;
      _operationMessage = 'Generating signed URL...';
    });

    try {
      final signedUrl = await _papersService.getSignedPdfUrl(paper.filePath);
      final uri = Uri.parse(signedUrl);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open preview in external viewer.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _operatingPaperId = null;
          _operationMessage = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Admin Panel'),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.winePlum),
        ),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Admin Panel'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.gpp_bad_rounded,
                      size: 64,
                      color: AppTheme.errorColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Access Restricted',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.winePlum,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'You do not have administrative privileges to access this area. Only verified administrator accounts registered in public.admin_users can manage papers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppTheme.dustyMauve, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Return to App'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final totalPapers = _papers.length;
    final publishedCount = _papers.where((p) => p.isPublished).length;
    final draftCount = totalPapers - publishedCount;
    final groupedByYear = PapersService.groupPapersByYear(_papers);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Papers Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.quiz_rounded),
            tooltip: 'Test Management',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminTestManagementScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadPapers,
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Paper',
            onPressed: _openAddPaperDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPaperDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Paper'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.winePlum,
          onRefresh: _loadPapers,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Stat Cards (Total, Published, Unpublished)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isSmall = constraints.maxWidth < 600;
                        return Row(
                          children: [
                            Expanded(
                              child: _AdminStatBox(
                                title: 'Total Papers',
                                value: '$totalPapers',
                                icon: Icons.folder_copy_rounded,
                                color: AppTheme.winePlum,
                              ),
                            ),
                            SizedBox(width: isSmall ? 8 : 16),
                            Expanded(
                              child: _AdminStatBox(
                                title: 'Published',
                                value: '$publishedCount',
                                icon: Icons.check_circle_rounded,
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                            SizedBox(width: isSmall ? 8 : 16),
                            Expanded(
                              child: _AdminStatBox(
                                title: 'Unpublished (Drafts)',
                                value: '$draftCount',
                                icon: Icons.edit_document,
                                color: const Color(0xFFC25E00),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),

                    // Papers Grouped by Year Dashboard Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.softRose,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.cherryBlossom),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.winePlum),
                              const SizedBox(width: 8),
                              const Text(
                                'Papers Grouped by Year',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.winePlum,
                                ),
                              ),
                              const Spacer(),
                              if (_yearFilter != null)
                                TextButton(
                                  onPressed: () {
                                    setState(() => _yearFilter = null);
                                    _loadPapers();
                                  },
                                  child: const Text('Clear Year Filter', style: TextStyle(fontSize: 12)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (groupedByYear.isEmpty)
                            const Text(
                              'No papers available yet.',
                              style: TextStyle(fontSize: 12, color: AppTheme.dustyMauve),
                            )
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: groupedByYear.entries.map((entry) {
                                  final year = entry.key;
                                  final papersInYear = entry.value;
                                  final isSelected = _yearFilter == year;
                                  final pub = papersInYear.where((p) => p.isPublished).length;
                                  final draft = papersInYear.length - pub;

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        setState(() {
                                          _yearFilter = isSelected ? null : year;
                                        });
                                        _loadPapers();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppTheme.winePlum : AppTheme.alabasterGrey,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected ? AppTheme.winePlum : AppTheme.cherryBlossom,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$year',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: isSelected ? Colors.white : AppTheme.winePlum,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${papersInYear.length} papers ($pub pub, $draft draft)',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isSelected
                                                    ? AppTheme.pastelPink
                                                    : AppTheme.dustyMauve,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Search & Filters Card (Title, Year, Stage, Subject, Status)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.softRose,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.cherryBlossom),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search Input by title
                          TextField(
                            controller: _searchController,
                            onSubmitted: (_) => _loadPapers(),
                            decoration: InputDecoration(
                              hintText: 'Search papers by title, subject or year...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        _searchController.clear();
                                        _loadPapers();
                                      },
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.arrow_forward_rounded),
                                      onPressed: _loadPapers,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Filter Controls Wrap
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Status Filter
                              DropdownButton<String>(
                                value: _statusFilter,
                                underline: const SizedBox(),
                                items: ['All', 'Published', 'Draft'].map((s) {
                                  return DropdownMenuItem(value: s, child: Text('Status: $s'));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _statusFilter = val);
                                    _loadPapers();
                                  }
                                },
                              ),

                              // Stage Filter
                              DropdownButton<String>(
                                value: _stageFilter,
                                underline: const SizedBox(),
                                items: ['All', 'Prelims', 'Mains'].map((s) {
                                  return DropdownMenuItem(value: s, child: Text('Stage: $s'));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _stageFilter = val);
                                    _loadPapers();
                                  }
                                },
                              ),

                              // Subject Filter
                              DropdownButton<String>(
                                value: _subjectFilter,
                                underline: const SizedBox(),
                                items: PapersService.standardSubjects.map((sub) {
                                  return DropdownMenuItem(value: sub, child: Text('Subject: $sub'));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _subjectFilter = val);
                                    _loadPapers();
                                  }
                                },
                              ),

                              // Type Filter
                              DropdownButton<String>(
                                value: _typeFilter,
                                underline: const SizedBox(),
                                items: PapersService.standardPaperTypes.map((t) {
                                  return DropdownMenuItem(value: t, child: Text('Type: $t'));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _typeFilter = val);
                                    _loadPapers();
                                  }
                                },
                              ),

                              // Reset
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _statusFilter = 'All';
                                    _stageFilter = 'All';
                                    _subjectFilter = 'All';
                                    _typeFilter = 'All';
                                    _yearFilter = null;
                                    _searchController.clear();
                                  });
                                  _loadPapers();
                                },
                                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                                label: const Text('Reset filters'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Active operation banner
                    if (_operatingPaperId != null && _operationMessage.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.pastelPink,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.winePlum),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.winePlum),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _operationMessage,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.winePlum),
                            ),
                          ],
                        ),
                      ),

                    // Papers Listing
                    if (_isLoadingPapers)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(color: AppTheme.winePlum),
                        ),
                      )
                    else if (_errorMessage != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppTheme.errorColor, size: 48),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadPapers,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_papers.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            children: [
                              const Icon(Icons.content_paste_off_rounded, size: 54, color: AppTheme.dustyMauve),
                              const SizedBox(height: 16),
                              const Text(
                                'No papers found in database',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.winePlum,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Click "Add Paper" to upload your first question paper or answer key.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.dustyMauve, fontSize: 13),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _openAddPaperDialog,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add First Paper'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _papers.length,
                        itemBuilder: (context, index) {
                          final paper = _papers[index];
                          final isOperating = _operatingPaperId == paper.id;

                          return _AdminPaperListItem(
                            paper: paper,
                            isOperating: isOperating,
                            onTogglePublish: () => _togglePublishStatus(paper),
                            onEdit: () => _openEditPaperDialog(paper),
                            onReplacePdf: () => _replacePdf(paper),
                            onDelete: () => _confirmDeletePaper(paper),
                            onPreview: () => _previewPdf(paper),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminStatBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _AdminStatBox({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.softRose,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cherryBlossom),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.dustyMauve,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminPaperListItem extends StatelessWidget {
  final Paper paper;
  final bool isOperating;
  final VoidCallback onTogglePublish;
  final VoidCallback onEdit;
  final VoidCallback onReplacePdf;
  final VoidCallback onDelete;
  final VoidCallback onPreview;

  const _AdminPaperListItem({
    required this.paper,
    required this.isOperating,
    required this.onTogglePublish,
    required this.onEdit,
    required this.onReplacePdf,
    required this.onDelete,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.softRose,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: paper.isPublished ? AppTheme.cherryBlossom : AppTheme.dustyMauve.withValues(alpha: 0.5),
          width: paper.isPublished ? 1 : 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Status badge and info chips
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: paper.isPublished
                        ? const Color(0xFF2E7D32).withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: paper.isPublished ? const Color(0xFF2E7D32) : Colors.orange,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        paper.isPublished ? Icons.check_circle_outline : Icons.pending_outlined,
                        size: 13,
                        color: paper.isPublished ? const Color(0xFF2E7D32) : Colors.orange.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        paper.isPublished ? 'Published' : 'Draft',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: paper.isPublished ? const Color(0xFF2E7D32) : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelPink,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${paper.year} • ${paper.stage}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.winePlum,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.alabasterGrey,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    paper.paperType,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.winePlum,
                    ),
                  ),
                ),
                const Spacer(),
                if (isOperating)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.winePlum),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              paper.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.winePlum,
              ),
            ),
            const SizedBox(height: 4),

            // Subject & Exam & File path
            Text(
              '${paper.subject} | ${paper.exam}',
              style: const TextStyle(fontSize: 12, color: AppTheme.dustyMauve),
            ),
            if (paper.filePath.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.attach_file_rounded, size: 14, color: AppTheme.dustyMauve),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      paper.filePath,
                      style: const TextStyle(fontSize: 11, color: AppTheme.dustyMauve),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.cherryBlossom),
            const SizedBox(height: 8),

            // Action Buttons (View PDF, Edit, Replace PDF, Publish/Unpublish, Delete)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                // 1. View PDF
                TextButton.icon(
                  onPressed: isOperating ? null : onPreview,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View PDF', style: TextStyle(fontSize: 12)),
                ),

                // 2. Edit details
                TextButton.icon(
                  onPressed: isOperating ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                ),

                // 3. Replace PDF
                TextButton.icon(
                  onPressed: isOperating ? null : onReplacePdf,
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text('Replace PDF', style: TextStyle(fontSize: 12)),
                ),

                // 4. Publish / Unpublish Toggle
                TextButton.icon(
                  onPressed: isOperating ? null : onTogglePublish,
                  icon: Icon(
                    paper.isPublished ? Icons.visibility_off_outlined : Icons.publish_rounded,
                    size: 16,
                    color: paper.isPublished ? Colors.orange.shade800 : const Color(0xFF2E7D32),
                  ),
                  label: Text(
                    paper.isPublished ? 'Unpublish' : 'Publish',
                    style: TextStyle(
                      fontSize: 12,
                      color: paper.isPublished ? Colors.orange.shade800 : const Color(0xFF2E7D32),
                    ),
                  ),
                ),

                // 5. Delete
                TextButton.icon(
                  onPressed: isOperating ? null : onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.errorColor),
                  label: const Text(
                    'Delete',
                    style: TextStyle(fontSize: 12, color: AppTheme.errorColor),
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
