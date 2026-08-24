import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Loads a Unicode-capable font for the PDF report (Noto Sans covers Latin,
/// Cyrillic, Greek, Vietnamese and most accented text — the same font used
/// by the EastmarkHK e-Invoicing app's PDFs).
///
/// EXTENDING FOR OTHER SCRIPTS: Noto Sans alone doesn't include CJK,
/// Arabic, Thai, or Indic glyphs. The `printing` package ships many more
/// Noto variants via `PdfGoogleFonts` (e.g. for Chinese, Japanese, Korean,
/// Arabic, Thai, Devanagari…). If you add support for one of those
/// languages and the PDF shows empty boxes instead of characters, open
/// this file, check `PdfGoogleFonts.` autocomplete in your IDE for the
/// right method name for that script, and swap it in based on the
/// language code below (this was left as the safe, already-verified
/// default rather than guessing exact method names blind).
class SnowballPdfFonts {
  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<void> _ensureLoaded() async {
    if (_regular != null && _bold != null) return;
    try {
      _regular = await PdfGoogleFonts.notoSansRegular();
      _bold = await PdfGoogleFonts.notoSansBold();
    } catch (_) {
      // Sandbox / offline: still produce a readable report.
      _regular = pw.Font.helvetica();
      _bold = pw.Font.helveticaBold();
    }
  }

  static Future<pw.Document> createDocument(String languageCode) async {
    await _ensureLoaded();
    return pw.Document(
      theme: pw.ThemeData.withFont(base: _regular!, bold: _bold!),
    );
  }
}
