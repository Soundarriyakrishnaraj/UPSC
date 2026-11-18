// lib/services/pdf_report_service.dart
// Professional, high-contrast PDF test report generator and direct Downloads saver

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/test_model.dart';
import 'test_service.dart';

class PdfReportService {
  static const _channel = MethodChannel('com.example.upsc_preparation_app/downloads');

  // ── High-Contrast, Accessible Professional Colors ──
  static const _winePlum        = PdfColor.fromInt(0xFF723D46);
  static const _darkText        = PdfColor.fromInt(0xFF2D3142);
  static const _mutedText       = PdfColor.fromInt(0xFF5A6075);
  static const _lightCardBorder = PdfColor.fromInt(0xFFE2E4E8);
  static const _lightNeutralBg  = PdfColor.fromInt(0xFFF8F9FA);

  // Pale green & dark green for correct answers (high contrast)
  static const _paleGreenBg     = PdfColor.fromInt(0xFFE4F2E7);
  static const _darkGreenText   = PdfColor.fromInt(0xFF245C35);

  // Pale red & dark red for incorrect answers (high contrast)
  static const _paleRedBg       = PdfColor.fromInt(0xFFFBE8E8);
  static const _darkRedText     = PdfColor.fromInt(0xFF8B3030);

  // Pale neutral for unanswered
  static const _paleUnansweredBg = PdfColor.fromInt(0xFFEEF0F2);
  static const _darkUnansweredText = PdfColor.fromInt(0xFF495057);

  /// Saves the generated PDF directly into the device's Downloads folder
  /// Returns the saved location string (e.g. "Downloads/UPSC_Test_Result_...pdf")
  static Future<String> savePdfToDownloads({
    required TestModel test,
    required TestAttempt attempt,
    required TestService service,
  }) async {
    final pdf = await _buildPdf(test: test, attempt: attempt, service: service);
    final bytes = await pdf.save();
    final fileName = _buildFileName(test: test, attempt: attempt);

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<String>('savePdfToDownloads', {
          'bytes': bytes,
          'fileName': fileName,
        });
        return result ?? 'Downloads/$fileName';
      } catch (e) {
        // Fallback to Printing.sharePdf if platform channel encounters an issue
        await Printing.sharePdf(bytes: bytes, filename: fileName);
        return 'Downloads/$fileName';
      }
    } else {
      // iOS / Web / Desktop: standard supported file workflow
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return fileName;
    }
  }

  /// Generates the PDF and opens the system share/print dialog
  static Future<void> generateAndShare({
    required TestModel test,
    required TestAttempt attempt,
    required TestService service,
  }) async {
    final pdf = await _buildPdf(test: test, attempt: attempt, service: service);
    final bytes = await pdf.save();
    final fileName = _buildFileName(test: test, attempt: attempt);
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  static String _buildFileName({required TestModel test, required TestAttempt attempt}) {
    final safeTitle = _safe(test.title);
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'UPSC_Test_Result_${safeTitle}_Attempt${attempt.attemptNumber}_$dateStr.pdf';
  }

  static String _safe(String s) {
    final safe = s.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final trimmed = safe.substring(0, safe.length.clamp(0, 30));
    return trimmed.isEmpty ? 'Test' : trimmed;
  }

  static Future<pw.Document> _buildPdf({
    required TestModel test,
    required TestAttempt attempt,
    required TestService service,
  }) async {
    final questions = await service.fetchQuestionsForReview(test.id);
    final answers   = await service.fetchAnswers(attempt.id);
    final user      = Supabase.instance.client.auth.currentUser;
    final fullName  = user?.userMetadata?['full_name']?.toString() ?? 'Student';
    final username  = user?.email ?? '';

    final correct    = attempt.correctCount ?? 0;
    final incorrect  = attempt.incorrectCount ?? 0;
    final unanswered = attempt.unansweredCount ?? 0;
    final marks      = attempt.marksObtained ?? 0.0;
    final negMarks   = attempt.negativeMarks ?? 0.0;
    final maxMarks   = attempt.maxMarks ?? 0.0;
    final pct        = attempt.percentage ?? 0.0;
    final taken      = attempt.submittedAt != null
        ? attempt.submittedAt!.difference(attempt.startedAt)
        : const Duration();
    final dateStr    = _fmtDate(attempt.submittedAt ?? attempt.startedAt);

    final doc = pw.Document();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (ctx) => _pageHeader(dateStr),
      footer: (ctx) => _pageFooter(ctx, dateStr),
      build: (ctx) => [
        // ── Report title header banner ──────────────────────
        pw.Container(
          decoration: pw.BoxDecoration(
            color: _winePlum,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(
              'UPSC EXAMINATION PERFORMANCE REPORT',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              test.title,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${test.upscStage}  •  ${test.stageCategory}  •  ${test.subject}',
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
            ),
          ]),
        ),
        pw.SizedBox(height: 12),

        // ── Candidate & Attempt Meta ─────────────────────────
        pw.Container(
          decoration: pw.BoxDecoration(
            color: _lightNeutralBg,
            border: pw.Border.all(color: _lightCardBorder),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          padding: const pw.EdgeInsets.all(12),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Candidate Name', style: const pw.TextStyle(color: _mutedText, fontSize: 9)),
                  pw.Text(fullName, style: pw.TextStyle(color: _darkText, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text(username, style: const pw.TextStyle(color: _mutedText, fontSize: 10)),
                ]),
              ),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('Date: $dateStr', style: const pw.TextStyle(color: _darkText, fontSize: 10)),
                pw.Text('Attempt: #${attempt.attemptNumber}', style: const pw.TextStyle(color: _darkText, fontSize: 10)),
                pw.Text('Duration: ${attempt.selectedDurationMinutes} min', style: const pw.TextStyle(color: _darkText, fontSize: 10)),
                pw.Text('Time Taken: ${taken.inMinutes}m ${taken.inSeconds.remainder(60)}s',
                    style: const pw.TextStyle(color: _darkText, fontSize: 10)),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 14),

        // ── Performance Summary Block ────────────────────────
        pw.Text(
          'Performance Summary',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _winePlum),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: _lightCardBorder),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          padding: const pw.EdgeInsets.all(12),
          child: pw.Column(children: [
            _summaryRow('Percentage Score', '${pct.toStringAsFixed(1)}%', _winePlum, bold: true),
            _summaryRow(
              'Marks Obtained',
              '${marks.toStringAsFixed(2)} / ${maxMarks.toStringAsFixed(0)}',
              _darkText,
              bold: true,
            ),
            _summaryRow('Correct Answers', '$correct', _darkGreenText),
            _summaryRow('Incorrect Answers', '$incorrect', _darkRedText),
            _summaryRow('Unanswered', '$unanswered', _mutedText),
            _summaryRow(
              'Negative Marks Deducted (1/3 per wrong answer)',
              '-${negMarks.toStringAsFixed(2)}',
              _darkRedText,
            ),
            _summaryRow(
              'Stars Earned',
              '${'★' * attempt.starsEarned}${'☆' * (3 - attempt.starsEarned)}',
              _winePlum,
            ),
          ]),
        ),
        pw.SizedBox(height: 18),

        // ── Question-wise Analysis Heading ────────────────────
        pw.Text(
          'Question-wise Review & Solutions',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _winePlum),
        ),
        pw.SizedBox(height: 8),

        for (final q in questions)
          ..._questionBlock(
            q: q,
            studentAnswer: answers[q.id]?.selectedOption,
            marksPerQ: test.marksPerQuestion,
          ),
      ],
    ));

    return doc;
  }

  // ── Page Header / Footer ─────────────────────────────
  static pw.Widget _pageHeader(String dateStr) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _lightCardBorder, width: 0.8)),
        ),
        child: pw.Row(children: [
          pw.Text(
            'UPSC PREPARATION APP',
            style: pw.TextStyle(
              color: _winePlum,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          pw.Spacer(),
          pw.Text('Detailed Test Result Report', style: const pw.TextStyle(color: _mutedText, fontSize: 8)),
        ]),
      );

  static pw.Widget _pageFooter(pw.Context ctx, String dateStr) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _lightCardBorder, width: 0.8)),
        ),
        child: pw.Row(children: [
          pw.Text('Saved: $dateStr', style: const pw.TextStyle(color: _mutedText, fontSize: 8)),
          pw.Spacer(),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(color: _mutedText, fontSize: 8)),
        ]),
      );

  static pw.Widget _summaryRow(
    String label,
    String value,
    PdfColor color, {
    bool bold = false,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                color: bold ? _darkText : _mutedText,
                fontSize: 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ]),
      );

  static List<pw.Widget> _questionBlock({
    required TestQuestion q,
    required String? studentAnswer,
    required double marksPerQ,
  }) {
    final correct = q.correctOption ?? '';
    final isCorrect = studentAnswer != null && studentAnswer == correct;
    final isUnanswered = studentAnswer == null;

    PdfColor badgeBg;
    PdfColor badgeText;
    String statusLabel;
    double marks;

    if (isCorrect) {
      badgeBg = _paleGreenBg;
      badgeText = _darkGreenText;
      statusLabel = 'CORRECT';
      marks = marksPerQ;
    } else if (isUnanswered) {
      badgeBg = _paleUnansweredBg;
      badgeText = _darkUnansweredText;
      statusLabel = 'UNANSWERED';
      marks = 0.0;
    } else {
      badgeBg = _paleRedBg;
      badgeText = _darkRedText;
      statusLabel = 'INCORRECT';
      marks = -(marksPerQ / 3);
    }

    final marksStr = marks > 0
        ? '+${marks.toStringAsFixed(2)} marks'
        : marks < 0
            ? '${marks.toStringAsFixed(2)} marks'
            : '0.00 marks';

    return [
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: _lightCardBorder),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          // Row: Question # + Status Badge + Marks
          pw.Row(children: [
            pw.Text(
              'Q${q.questionNumber}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _darkText),
            ),
            pw.SizedBox(width: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: pw.BoxDecoration(
                color: badgeBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                statusLabel,
                style: pw.TextStyle(fontSize: 8, color: badgeText, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Spacer(),
            pw.Text(
              marksStr,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: badgeText),
            ),
          ]),
          pw.SizedBox(height: 6),

          // Question Text
          pw.Text(
            q.questionText,
            style: const pw.TextStyle(fontSize: 10, color: _darkText, lineSpacing: 1.5),
          ),
          pw.SizedBox(height: 6),

          // Options A, B, C, D
          for (final entry in {
            'A': q.optionA,
            'B': q.optionB,
            'C': q.optionC,
            'D': q.optionD,
          }.entries) ...[
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 3),
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: entry.key == correct
                    ? _paleGreenBg
                    : (entry.key == studentAnswer && !isCorrect)
                        ? _paleRedBg
                        : _lightNeutralBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(
                  color: entry.key == correct
                      ? const PdfColor.fromInt(0xFFC3E6CB)
                      : (entry.key == studentAnswer && !isCorrect)
                          ? const PdfColor.fromInt(0xFFF5C6CB)
                          : _lightCardBorder,
                  width: 0.5,
                ),
              ),
              child: pw.Row(children: [
                pw.Text(
                  '${entry.key}. ',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: entry.key == correct
                        ? _darkGreenText
                        : (entry.key == studentAnswer && !isCorrect)
                            ? _darkRedText
                            : _darkText,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    entry.value,
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: entry.key == correct
                          ? _darkGreenText
                          : (entry.key == studentAnswer && !isCorrect)
                              ? _darkRedText
                              : _darkText,
                    ),
                  ),
                ),
                if (entry.key == correct)
                  pw.Text(
                    '✓ Correct Answer',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _darkGreenText,
                    ),
                  )
                else if (entry.key == studentAnswer && !isCorrect)
                  pw.Text(
                    '✗ Your Choice',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _darkRedText,
                    ),
                  ),
              ]),
            ),
          ],

          // Solution / Explanation
          if (q.explanation != null && q.explanation!.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: _lightNeutralBg,
                border: const pw.Border(left: pw.BorderSide(color: _winePlum, width: 2)),
              ),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(
                  'Explanation: ',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _darkText),
                ),
                pw.Expanded(
                  child: pw.Text(
                    q.explanation!,
                    style: const pw.TextStyle(fontSize: 8, color: _mutedText, lineSpacing: 1.3),
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
    ];
  }

  static String _fmtDate(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }
}
