import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/paper_model.dart';
import '../../services/papers_service.dart';

class AdminPaperFormDialog extends StatefulWidget {
  final Paper? paperToEdit;

  const AdminPaperFormDialog({super.key, this.paperToEdit});

  @override
  State<AdminPaperFormDialog> createState() => _AdminPaperFormDialogState();
}

class _AdminPaperFormDialogState extends State<AdminPaperFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final PapersService _papersService = PapersService();

  late TextEditingController _titleController;
  late TextEditingController _examController;
  late TextEditingController _customSubjectController;

  late int _selectedYear;
  late String _selectedStage;
  late String _selectedSubject;
  late String _selectedType;
  late bool _isPublished;

  bool _isCustomSubject = false;
  PlatformFile? _pickedFile;
  Uint8List? _fileBytes;
  bool _isSaving = false;
  String _savingStatus = '';

  bool get isEditing => widget.paperToEdit != null;

  // Year range 2000 - 2100 as specified
  final List<int> _yearOptions = List<int>.generate(
    101,
    (index) => 2100 - index,
  );

  final List<String> _subjects = [
    'General Studies I',
    'General Studies II (CSAT)',
    'General Studies III',
    'General Studies IV (Ethics)',
    'Essay',
    'History',
    'Geography',
    'Polity & Governance',
    'Economy',
    'Environment & Ecology',
    'Science & Technology',
    'Optional Subject',
    'Other (Custom)',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.paperToEdit;

    _titleController = TextEditingController(text: p?.title ?? '');
    _examController = TextEditingController(
      text: p?.exam ?? 'Civil Services Examination',
    );
    _selectedYear = p?.year ?? DateTime.now().year;
    _selectedStage = p?.stage ?? 'Prelims';
    _selectedType = p?.paperType ?? 'Question Paper';
    _isPublished = p?.isPublished ?? true;

    final existingSubject = p?.subject ?? 'General Studies I';
    if (_subjects.contains(existingSubject)) {
      _selectedSubject = existingSubject;
      _isCustomSubject = false;
      _customSubjectController = TextEditingController();
    } else {
      _selectedSubject = 'Other (Custom)';
      _isCustomSubject = true;
      _customSubjectController = TextEditingController(text: existingSubject);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _examController.dispose();
    _customSubjectController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.xFile.readAsBytes();

        setState(() {
          _pickedFile = file;
          _fileBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting file: $e')),
        );
      }
    }
  }

  Future<void> _savePaper() async {
    if (!_formKey.currentState!.validate()) return;

    if (!isEditing && (_fileBytes == null || _pickedFile == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF document to upload.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _savingStatus = 'Saving paper...';
    });

    try {
      final subject = _isCustomSubject
          ? _customSubjectController.text.trim()
          : _selectedSubject;

      if (isEditing) {
        final existingPaper = widget.paperToEdit!;

        if (_fileBytes != null && _pickedFile != null) {
          // Replace PDF safely: upload new first, update record, remove old file
          setState(() {
            _savingStatus = 'Uploading new PDF and replacing document...';
          });

          await _papersService.replacePaperPdf(
            paper: existingPaper,
            newPdfBytes: _fileBytes!,
            newFileName: _pickedFile!.name,
          );
        }

        setState(() {
          _savingStatus = 'Updating paper details...';
        });

        await _papersService.updatePaper(
          id: existingPaper.id,
          title: _titleController.text.trim(),
          year: _selectedYear,
          exam: _examController.text.trim(),
          stage: _selectedStage,
          subject: subject,
          paperType: _selectedType,
          isPublished: _isPublished,
        );
      } else {
        // Create new paper with atomic storage upload and rollback on failure
        setState(() {
          _savingStatus = 'Uploading PDF and creating paper record...';
        });

        await _papersService.createPaperWithPdf(
          title: _titleController.text.trim(),
          year: _selectedYear,
          exam: _examController.text.trim(),
          stage: _selectedStage,
          subject: subject,
          paperType: _selectedType,
          pdfBytes: _fileBytes!,
          fileName: _pickedFile!.name,
          isPublished: _isPublished,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save paper: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.pastelPink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit_note_rounded : Icons.post_add_rounded,
                        color: AppTheme.winePlum,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit Paper Details' : 'Add New Paper',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.winePlum,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.winePlum),
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppTheme.cherryBlossom),
                const SizedBox(height: 16),

                // Form Fields
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        const Text(
                          'Paper Title *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.winePlum,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. UPSC CSE 2023 GS Paper 1',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a paper title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Examination Name
                        const Text(
                          'Examination *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.winePlum,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _examController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Civil Services Examination',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter examination name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Year and Stage Row
                        Row(
                          children: [
                            // Year (2000 - 2100)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Year (2000–2100) *',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.winePlum,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<int>(
                                    value: _selectedYear,
                                    menuMaxHeight: 350,
                                    decoration: const InputDecoration(),
                                    items: _yearOptions.map((year) {
                                      return DropdownMenuItem<int>(
                                        value: year,
                                        child: Text('$year'),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedYear = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Stage
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Stage *',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.winePlum,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedStage,
                                    decoration: const InputDecoration(),
                                    items: ['Prelims', 'Mains'].map((stage) {
                                      return DropdownMenuItem<String>(
                                        value: stage,
                                        child: Text(stage),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedStage = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Paper Type
                        const Text(
                          'Document Type *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.winePlum,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: const InputDecoration(),
                          items: ['Question Paper', 'Answer Key', 'Syllabus', 'Other'].map((t) {
                            return DropdownMenuItem<String>(
                              value: t,
                              child: Text(t),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedType = val);
                          },
                        ),
                        const SizedBox(height: 14),

                        // Subject
                        const Text(
                          'Subject *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.winePlum,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedSubject,
                          decoration: const InputDecoration(),
                          items: _subjects.map((sub) {
                            return DropdownMenuItem<String>(
                              value: sub,
                              child: Text(sub),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedSubject = val;
                                _isCustomSubject = val == 'Other (Custom)';
                              });
                            }
                          },
                        ),
                        if (_isCustomSubject) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _customSubjectController,
                            decoration: const InputDecoration(
                              hintText: 'Enter custom subject name',
                            ),
                            validator: (value) {
                              if (_isCustomSubject && (value == null || value.trim().isEmpty)) {
                                return 'Please enter subject name';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 18),

                        // PDF File Selector
                        const Text(
                          'PDF File *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.winePlum,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.softRose,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.cherryBlossom),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_pickedFile != null)
                                Row(
                                  children: [
                                    const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.winePlum),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _pickedFile!.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppTheme.winePlum,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${((_fileBytes?.length ?? 0) / 1024).toStringAsFixed(1)} KB (New file selected)',
                                            style: const TextStyle(fontSize: 11, color: AppTheme.dustyMauve),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
                                      onPressed: () {
                                        setState(() {
                                          _pickedFile = null;
                                          _fileBytes = null;
                                        });
                                      },
                                    ),
                                  ],
                                )
                              else if (isEditing && widget.paperToEdit!.filePath.isNotEmpty)
                                Row(
                                  children: [
                                    const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.winePlum),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.paperToEdit!.fileName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppTheme.winePlum,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const Text(
                                            'Current file attached in storage',
                                            style: TextStyle(fontSize: 11, color: AppTheme.dustyMauve),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              else
                                const Row(
                                  children: [
                                    Icon(Icons.upload_file_rounded, color: AppTheme.dustyMauve),
                                    SizedBox(width: 10),
                                    Text(
                                      'No PDF selected yet',
                                      style: TextStyle(fontSize: 13, color: AppTheme.dustyMauve),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _isSaving ? null : _pickPdf,
                                icon: const Icon(Icons.attach_file_rounded, size: 18),
                                label: Text(_pickedFile != null || isEditing ? 'Replace PDF' : 'Select PDF'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.winePlum,
                                  backgroundColor: AppTheme.pastelPink,
                                  minimumSize: const Size(double.infinity, 40),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Publish Immediately Checkbox
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.softRose,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.cherryBlossom),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Publish immediately',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.winePlum,
                              ),
                            ),
                            subtitle: Text(
                              _isPublished
                                  ? 'Visible to students immediately on the Papers tab'
                                  : 'Saved as draft (only administrators can see)',
                              style: const TextStyle(fontSize: 11, color: AppTheme.dustyMauve),
                            ),
                            value: _isPublished,
                            activeColor: AppTheme.winePlum,
                            onChanged: (val) => setState(() => _isPublished = val),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Save Status / Progress indicator
                if (_isSaving) ...[
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.winePlum),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _savingStatus,
                          style: const TextStyle(fontSize: 12, color: AppTheme.winePlum),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _savePaper,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.winePlum,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(140, 46),
                      ),
                      child: Text(isEditing ? 'Save Changes' : 'Upload & Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
