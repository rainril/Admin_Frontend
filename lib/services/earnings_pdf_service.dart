import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'auth_service.dart';

/// Builds and shares/prints/emails the PrimeFit earnings statement.
///
/// Used by BillingScreen's "Export" menu:
///  - printStatement()      -> opens the print/share preview
///  - sendEarningsEmail()   -> attaches the PDF and opens the device's
///                             email app via flutter_email_sender
class EarningsPdfService {
  EarningsPdfService._();

  /// Builds the PDF document bytes shared by both actions.
  static Future<Uint8List> _buildPdf({
    required String generatedDate,
    required List<List<String>> membershipRows,
    required String membershipTotal,
    required List<List<String>> walkInRows,
    required String walkInTotal,
    required String grandTotal,
  }) async {
    // Fetch NotoSans via the pdf package's built-in Google Fonts loader so
    // the ₱ (peso) glyph actually renders — the PDF package's default font
    // has no glyph for U+20B1, which is why it was showing as a box before.
    // This downloads (and caches) the font at runtime, so no local .ttf
    // files need to be bundled in assets/.
    pw.ThemeData? theme;
    try {
      final regularFont = await PdfGoogleFonts.notoSansRegular();
      final boldFont = await PdfGoogleFonts.notoSansBold();
      theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);
    } catch (_) {
      theme = null; // no internet / fetch failed — falls back to default font
    }

    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('PrimeFit Gym', style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Earnings Statement', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text('Generated: $generatedDate', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            pw.SizedBox(height: 12),
            pw.Divider(color: PdfColors.grey300),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 8),
          pw.Text('Membership Payments', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _buildCompactTable(
            headers: const ['Member', 'Plan', 'Amount', 'Method', 'Date'],
            rows: membershipRows,
            amountColumnIndex: 2,
          ),
          pw.SizedBox(height: 4),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Subtotal: $membershipTotal', style: const pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Walk-in Payments', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _buildCompactTable(
            headers: const ['Name', 'Amount', 'Method', 'Date'],
            rows: walkInRows,
            amountColumnIndex: 1,
          ),
          pw.SizedBox(height: 4),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Subtotal: $walkInTotal', style: const pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFE0F7FA),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Grand Total', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  grandTotal,
                  style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF00838F)),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  /// Compact, zebra-striped table. [amountColumnIndex] is right-aligned and
  /// tinted green to read as an incoming payment. Built manually with
  /// pw.Table (instead of TableHelper.fromTextArray) for full control over
  /// per-cell styling without depending on optional params that vary by
  /// pdf package version.
  static pw.Widget _buildCompactTable({
    required List<String> headers,
    required List<List<String>> rows,
    required int amountColumnIndex,
  }) {
    if (rows.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Text(
          'No paid records for this period.',
          style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 9),
        ),
      );
    }

    pw.Widget cell(String text, {required bool isAmount, required bool isHeader}) {
      return pw.Padding(
        padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: isHeader ? 6 : 5),
        child: pw.Text(
          text,
          textAlign: isAmount ? pw.TextAlign.right : pw.TextAlign.left,
          style: isHeader
              ? const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)
              : isAmount
                  ? const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF16A34A))
                  : const pw.TextStyle(fontSize: 9),
        ),
      );
    }

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF00B4D8)),
      children: [
        for (int i = 0; i < headers.length; i++)
          cell(headers[i], isAmount: i == amountColumnIndex, isHeader: true),
      ],
    );

    final dataRows = <pw.TableRow>[
      for (int r = 0; r < rows.length; r++)
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: r.isOdd ? const PdfColor.fromInt(0xFFF8FAFC) : PdfColors.white,
            border: const pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
          ),
          children: [
            for (int c = 0; c < rows[r].length; c++)
              cell(rows[r][c], isAmount: c == amountColumnIndex, isHeader: false),
          ],
        ),
    ];

    return pw.Table(children: [headerRow, ...dataRows]);
  }

  /// Opens the OS print/share preview for the earnings statement.
  static Future<void> printStatement({
    required String generatedDate,
    required List<List<String>> membershipRows,
    required String membershipTotal,
    required List<List<String>> walkInRows,
    required String walkInTotal,
    required String grandTotal,
  }) async {
    final bytes = await _buildPdf(
      generatedDate: generatedDate,
      membershipRows: membershipRows,
      membershipTotal: membershipTotal,
      walkInRows: walkInRows,
      walkInTotal: walkInTotal,
      grandTotal: grandTotal,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'PrimeFit_Earnings_Statement.pdf',
    );
  }

  /// Builds the PDF and posts it to the Laravel backend, which emails it
  /// (via Gmail SMTP) to whichever admin is currently logged in. Works on
  /// web, desktop, and mobile since it's a plain HTTP call — no native
  /// email app required. Returns true only if the backend confirms send.
  static Future<bool> sendEarningsEmail({
    required String generatedDate,
    required List<List<String>> membershipRows,
    required String membershipTotal,
    required List<List<String>> walkInRows,
    required String walkInTotal,
    required String grandTotal,
  }) async {
    try {
      final recipientEmail = await AuthService.getEmail();
      if (recipientEmail == null || recipientEmail.isEmpty) {
        return false; // no logged-in admin email on file
      }

      final bytes = await _buildPdf(
        generatedDate: generatedDate,
        membershipRows: membershipRows,
        membershipTotal: membershipTotal,
        walkInRows: walkInRows,
        walkInTotal: walkInTotal,
        grandTotal: grandTotal,
      );

      final uri = Uri.parse('${AuthService.baseUrl}/send-earnings-email');
      final request = http.MultipartRequest('POST', uri)
        ..fields['email'] = recipientEmail
        ..fields['subject'] = 'PrimeFit Earnings Statement - $generatedDate'
        ..fields['body'] =
            'Attached is the PrimeFit earnings statement generated on '
            '$generatedDate.\n\nGrand Total: $grandTotal'
        ..files.add(
          http.MultipartFile.fromBytes(
            'pdf',
            bytes,
            filename: 'PrimeFit_Earnings_Statement.pdf',
          ),
        );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
