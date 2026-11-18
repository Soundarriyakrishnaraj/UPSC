import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/paper_model.dart';

class PapersService {
  static const String papersTable = 'papers';
  static const String adminTable = 'admin_users';
  static const String bucketName = 'upsc-papers';

  final SupabaseClient _supabase;

  PapersService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  /// Check whether the current user is an authenticated administrator in public.admin_users.
  Future<bool> checkIsAdmin([String? userId]) async {
    final uid = userId ?? currentUser?.id;
    if (uid == null) return false;

    try {
      final data = await _supabase
          .from(adminTable)
          .select('user_id')
          .eq('user_id', uid)
          .maybeSingle();

      return data != null;
    } catch (e) {
      debugPrint('Admin check error: $e');
      return false;
    }
  }

  /// Fetch published papers for student view.
  Future<List<Paper>> fetchPublishedPapers({
    int? year,
    String? stage,
    String? subject,
    String? paperType,
    String? searchQuery,
  }) async {
    try {
      var query = _supabase
          .from(papersTable)
          .select()
          .eq('is_published', true);

      if (year != null && year > 0) {
        query = query.eq('year', year);
      }

      if (stage != null && stage.isNotEmpty && stage != 'All') {
        query = query.eq('stage', stage);
      }

      if (subject != null && subject.isNotEmpty && subject != 'All') {
        query = query.eq('subject', subject);
      }

      if (paperType != null && paperType.isNotEmpty && paperType != 'All') {
        query = query.eq('paper_type', paperType);
      }

      final response = await query
          .order('year', ascending: false)
          .order('created_at', ascending: false);

      List<Paper> papers = (response as List)
          .map((item) => Paper.fromJson(item as Map<String, dynamic>))
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        papers = papers.where((p) {
          final titleMatch = p.title.toLowerCase().contains(q);
          final subjectMatch = p.subject.toLowerCase().contains(q);
          final yearMatch = p.year.toString().contains(q);
          final stageMatch = p.stage.toLowerCase().contains(q);
          final typeMatch = p.paperType.toLowerCase().contains(q);
          return titleMatch || subjectMatch || yearMatch || stageMatch || typeMatch;
        }).toList();
      }

      return papers;
    } catch (e) {
      debugPrint('Error fetching published papers: $e');
      rethrow;
    }
  }

  /// Fetch all papers for admin view (both published and unpublished drafts).
  Future<List<Paper>> fetchAllPapers({
    int? year,
    String? stage,
    String? subject,
    String? paperType,
    bool? isPublished,
    String? searchQuery,
  }) async {
    try {
      var query = _supabase.from(papersTable).select();

      if (isPublished != null) {
        query = query.eq('is_published', isPublished);
      }

      if (year != null && year > 0) {
        query = query.eq('year', year);
      }

      if (stage != null && stage.isNotEmpty && stage != 'All') {
        query = query.eq('stage', stage);
      }

      if (subject != null && subject.isNotEmpty && subject != 'All') {
        query = query.eq('subject', subject);
      }

      if (paperType != null && paperType.isNotEmpty && paperType != 'All') {
        query = query.eq('paper_type', paperType);
      }

      final response = await query
          .order('year', ascending: false)
          .order('created_at', ascending: false);

      List<Paper> papers = (response as List)
          .map((item) => Paper.fromJson(item as Map<String, dynamic>))
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        papers = papers.where((p) {
          final titleMatch = p.title.toLowerCase().contains(q);
          final subjectMatch = p.subject.toLowerCase().contains(q);
          final yearMatch = p.year.toString().contains(q);
          final stageMatch = p.stage.toLowerCase().contains(q);
          final typeMatch = p.paperType.toLowerCase().contains(q);
          return titleMatch || subjectMatch || yearMatch || stageMatch || typeMatch;
        }).toList();
      }

      return papers;
    } catch (e) {
      debugPrint('Error fetching all papers: $e');
      rethrow;
    }
  }

  /// Get authenticated signed URL for a private PDF file.
  /// Generates a fresh temporary URL using Supabase createSignedUrl().
  /// Never returns or uses public URLs for private bucket upsc-papers.
  Future<String> getSignedPdfUrl(String filePath, {int expiresInSeconds = 3600}) async {
    if (filePath.isEmpty) {
      throw Exception('PDF document path is missing.');
    }

    try {
      final signedUrl = await _supabase.storage
          .from(bucketName)
          .createSignedUrl(filePath, expiresInSeconds);

      return signedUrl;
    } catch (e) {
      debugPrint('Error generating signed URL for $filePath: $e');
      rethrow;
    }
  }

  /// Upload PDF bytes to private bucket upsc-papers with a safe, unique path.
  Future<String> uploadPdf({
    required Uint8List bytes,
    required String originalFileName,
    required int year,
    required String stage,
  }) async {
    try {
      final cleanName = originalFileName
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\.\-]'), '_')
          .toLowerCase();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final stageClean = stage.toLowerCase().replaceAll(' ', '_');
      final path = 'papers/$year/${stageClean}_${timestamp}_$cleanName';

      await _supabase.storage.from(bucketName).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );

      return path;
    } catch (e) {
      debugPrint('Error uploading PDF: $e');
      rethrow;
    }
  }

  /// Create paper with PDF upload atomically:
  /// 1. Uploads PDF to storage.
  /// 2. Saves paper in database with created_by set to current authenticated user.
  /// 3. If database insert fails, cleans up the uploaded file to avoid orphaned storage files.
  Future<Paper> createPaperWithPdf({
    required String title,
    required int year,
    required String exam,
    required String stage,
    required String subject,
    required String paperType,
    required Uint8List pdfBytes,
    required String fileName,
    required bool isPublished,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Admin authentication required.');
    }

    // Step 1: Upload to private storage
    final storagePath = await uploadPdf(
      bytes: pdfBytes,
      originalFileName: fileName,
      year: year,
      stage: stage,
    );

    // Step 2: Insert into database
    try {
      final row = {
        'title': title.trim(),
        'year': year,
        'exam': exam.trim(),
        'stage': stage.trim(),
        'subject': subject.trim(),
        'paper_type': paperType.trim(),
        'file_path': storagePath,
        'is_published': isPublished,
        'created_by': user.id,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final data = await _supabase
          .from(papersTable)
          .insert(row)
          .select()
          .single();

      return Paper.fromJson(data);
    } catch (dbError) {
      // Step 3: Clean up uploaded file if DB insert fails
      debugPrint('Database insert failed, cleaning up uploaded file: $storagePath');
      try {
        await _supabase.storage.from(bucketName).remove([storagePath]);
      } catch (cleanupError) {
        debugPrint('File cleanup warning: $cleanupError');
      }
      rethrow;
    }
  }

  /// Replace a paper's PDF safely:
  /// 1. Upload new file first.
  /// 2. Update database record with new path.
  /// 3. If database update fails, delete new file.
  /// 4. If database update succeeds, delete old file.
  Future<Paper> replacePaperPdf({
    required Paper paper,
    required Uint8List newPdfBytes,
    required String newFileName,
  }) async {
    final oldFilePath = paper.filePath;

    // 1. Upload new file
    final newPath = await uploadPdf(
      bytes: newPdfBytes,
      originalFileName: newFileName,
      year: paper.year,
      stage: paper.stage,
    );

    // 2. Update record in database
    try {
      final updated = await updatePaper(
        id: paper.id,
        title: paper.title,
        year: paper.year,
        exam: paper.exam,
        stage: paper.stage,
        subject: paper.subject,
        paperType: paper.paperType,
        filePath: newPath,
        isPublished: paper.isPublished,
      );

      // 3. Remove old file from storage now that DB points to the new file
      if (oldFilePath.isNotEmpty && oldFilePath != newPath) {
        try {
          await _supabase.storage.from(bucketName).remove([oldFilePath]);
        } catch (storageError) {
          debugPrint('Notice: could not delete old file $oldFilePath: $storageError');
        }
      }

      return updated;
    } catch (dbError) {
      // If DB update failed, delete the newly uploaded file to prevent orphan
      try {
        await _supabase.storage.from(bucketName).remove([newPath]);
      } catch (_) {}
      rethrow;
    }
  }

  /// Update paper details in database.
  Future<Paper> updatePaper({
    required String id,
    required String title,
    required int year,
    required String exam,
    required String stage,
    required String subject,
    required String paperType,
    String? filePath,
    bool? isPublished,
  }) async {
    try {
      final updates = <String, dynamic>{
        'title': title.trim(),
        'year': year,
        'exam': exam.trim(),
        'stage': stage.trim(),
        'subject': subject.trim(),
        'paper_type': paperType.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (filePath != null && filePath.isNotEmpty) {
        updates['file_path'] = filePath.trim();
      }

      if (isPublished != null) {
        updates['is_published'] = isPublished;
      }

      final data = await _supabase
          .from(papersTable)
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return Paper.fromJson(data);
    } catch (e) {
      debugPrint('Error updating paper: $e');
      rethrow;
    }
  }

  /// Toggle publish status for a paper.
  Future<void> togglePublishStatus(String paperId, bool isPublished) async {
    try {
      await _supabase.from(papersTable).update({
        'is_published': isPublished,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', paperId);
    } catch (e) {
      debugPrint('Error toggling publish status: $e');
      rethrow;
    }
  }

  /// Delete paper record and corresponding PDF from storage safely:
  /// Deletes database record first, then removes the file from storage.
  Future<void> deletePaperSafely(Paper paper) async {
    try {
      // 1. Delete database row
      await _supabase.from(papersTable).delete().eq('id', paper.id);

      // 2. Remove storage file
      if (paper.filePath.isNotEmpty) {
        try {
          await _supabase.storage.from(bucketName).remove([paper.filePath]);
        } catch (storageError) {
          debugPrint('Storage deletion warning for ${paper.filePath}: $storageError');
        }
      }
    } catch (e) {
      debugPrint('Error deleting paper: $e');
      rethrow;
    }
  }

  /// Group a list of papers by year, with newest year first.
  static Map<int, List<Paper>> groupPapersByYear(List<Paper> papers) {
    final Map<int, List<Paper>> grouped = {};
    for (final paper in papers) {
      grouped.putIfAbsent(paper.year, () => []).add(paper);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final Map<int, List<Paper>> sortedGrouped = {};
    for (final year in sortedKeys) {
      sortedGrouped[year] = grouped[year]!;
    }

    return sortedGrouped;
  }

  /// Standard subjects list for UPSC preparation.
  static const List<String> standardSubjects = [
    'All',
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
  ];

  /// Standard stages.
  static const List<String> standardStages = ['All', 'Prelims', 'Mains'];

  /// Standard paper types.
  static const List<String> standardPaperTypes = [
    'All',
    'Question Paper',
    'Answer Key',
    'Syllabus',
    'Other',
  ];
}
