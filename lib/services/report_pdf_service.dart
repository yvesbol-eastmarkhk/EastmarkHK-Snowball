import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../calculator.dart';
import '../data/currencies.dart';
import '../l10n/l10n_controller.dart';
import '../utils/pdf_fonts.dart';

class _Palette {
  static const brand = PdfColor.fromInt(0xFF0B6E4F); // EastmarkHK green
  static const bodyText = PdfColor.fromInt(0xFF232B36);
  static const muted = PdfColor.fromInt(0xFF5D6975);
  static const border = PdfColor.fromInt(0xFFC1CED9);
  static const softBg = PdfColor.fromInt(0xFFEFF7F4);
  static const tableHeader = brand;
  static const yearlyIndigo = PdfColor.fromInt(0xFF3F51B5);
  static const yearlyIndigoBg = PdfColor.fromInt(0xFFE8EAF6);
}

/// Builds a well-formatted, translated PDF report of a compound-interest
/// calculation: header with logo, investment details, headline summary,
/// and the month-by-month breakdown (with year totals) — matching the page
/// across EastmarkHK apps' PDF exports.
class ReportPdfService {
  static final NumberFormat _numberFormat = NumberFormat('#,##0.00', 'en_US');

  static Future<Uint8List> build({
    required L10nController l10n,
    required CalculationResult result,
    required double annualRatePercent,
    required int years,
    required String compoundingLabel,
    required String investCurrency,
    required String referenceCurrency,
    double? exchangeRate,
    DateTime? exchangeAsOf,
    required double contributionAmount,
    required String? contributionFrequencyLabel,
    Uint8List? logoBytes,
  }) async {
    String pdfSymbol(String code) {
      final raw = currencySymbol(code);
      for (final rune in raw.runes) {
        // Keep Latin-1 and Euro; anything else (₩ ₹ ฿ …) becomes the ISO code.
        if (rune > 0xFF && rune != 0x20AC) return code;
      }
      return raw;
    }

    String fmt(double v, {String? code}) {
      final symbol = pdfSymbol(code ?? investCurrency);
      return '$symbol ${_numberFormat.format(v)}';
    }

    final convert = exchangeRate != null &&
        investCurrency != referenceCurrency &&
        exchangeRate > 0;
    // `≈` is missing from the PDF font and shows as a broken glyph.
    String? fmtRef(double v) =>
        convert ? '~ ${fmt(v * exchangeRate, code: referenceCurrency)}' : null;

    final doc = await SnowballPdfFonts.createDocument(l10n.languageCode);
    final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
    final generatedOn = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 20),
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(color: _Palette.border, thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  l10n.t('reportGeneratedBy'),
                  style: const pw.TextStyle(fontSize: 8, color: _Palette.muted),
                ),
                pw.Text(
                  '${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: _Palette.muted),
                ),
              ],
            ),
          ],
        ),
        build: (context) => [
          // Header: logo + title + generated date.
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) pw.Image(logo, height: 42),
              if (logo != null) pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      l10n.t('reportTitle'),
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: _Palette.brand,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${l10n.t('reportGeneratedOn')} $generatedOn',
                      style: const pw.TextStyle(fontSize: 9, color: _Palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),

          // Investment details.
          pw.Text(
            l10n.t('reportInvestmentDetails'),
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: _Palette.bodyText),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _Palette.softBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: _Palette.border, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _detailRow(l10n.t('initialInvestment'), fmt(result.totalPrincipal)),
                _detailRow(l10n.t('investCurrency'), investCurrency),
                _detailRow(l10n.t('referenceCurrency'), referenceCurrency),
                if (convert && exchangeAsOf != null)
                  _detailRow(
                    l10n.t('exchangeRate'),
                    '1 $investCurrency = ${_numberFormat.format(exchangeRate)} $referenceCurrency'
                    ' (${DateFormat('yyyy-MM-dd').format(exchangeAsOf)})',
                  ),
                _detailRow(l10n.t('annualRate'), '${_numberFormat.format(annualRatePercent)} %'),
                _detailRow(l10n.t('numberOfYears'), '$years'),
                _detailRow(l10n.t('compoundingFrequency'), compoundingLabel),
                if (contributionAmount > 0 && contributionFrequencyLabel != null)
                  _detailRow(
                    l10n.t('contributionAmount'),
                    '${fmt(contributionAmount)} (${contributionFrequencyLabel})',
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),

          // Headline summary.
          pw.Text(
            l10n.t('reportSummary'),
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: _Palette.bodyText),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              _summaryTile(
                l10n.t('finalBalance'),
                fmt(result.finalBalance),
                subtitle: fmtRef(result.finalBalance),
                emphasize: true,
              ),
              pw.SizedBox(width: 8),
              _summaryTile(
                l10n.t('totalContributions'),
                fmt(result.totalContributions),
                subtitle: fmtRef(result.totalContributions),
              ),
              pw.SizedBox(width: 8),
              _summaryTile(
                l10n.t('totalInterestEarned'),
                fmt(result.totalInterest),
                subtitle: fmtRef(result.totalInterest),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Month-by-month table.
          pw.Text(
            l10n.t('monthByMonthBreakdown'),
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: _Palette.bodyText),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: _Palette.border, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.8),
              1: pw.FlexColumnWidth(0.8),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2),
              4: pw.FlexColumnWidth(2.2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _Palette.tableHeader),
                children: [
                  _headerCell(l10n.t('year')),
                  _headerCell(l10n.t('month')),
                  _headerCell(l10n.t('contributed'), alignRight: true),
                  _headerCell(l10n.t('interest'), alignRight: true),
                  _headerCell(l10n.t('balance'), alignRight: true),
                ],
              ),
              ...breakdownTableRows(result).map(
                (row) => pw.TableRow(
                  decoration: row.isYearTotal
                      ? const pw.BoxDecoration(color: _Palette.yearlyIndigoBg)
                      : null,
                  children: [
                    _cell('${row.year}', yearTotal: row.isYearTotal),
                    _cell(
                      row.isYearTotal ? l10n.t('yearTotal') : '${row.month}',
                      yearTotal: row.isYearTotal,
                    ),
                    _moneyCell(
                      fmt(row.contributions),
                      subtitle: fmtRef(row.contributions),
                      yearTotal: row.isYearTotal,
                    ),
                    _moneyCell(
                      fmt(row.interest),
                      subtitle: fmtRef(row.interest),
                      yearTotal: row.isYearTotal,
                    ),
                    _moneyCell(
                      fmt(row.balance),
                      subtitle: fmtRef(row.balance),
                      yearTotal: row.isYearTotal,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _detailRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: _Palette.muted)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold, color: _Palette.bodyText)),
          ],
        ),
      );

  static pw.Widget _summaryTile(
    String label,
    String value, {
    String? subtitle,
    bool emphasize = false,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: emphasize ? _Palette.brand : _Palette.softBg,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8,
                color: emphasize ? PdfColors.white : _Palette.muted,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: emphasize ? PdfColors.white : _Palette.bodyText,
              ),
            ),
            if (subtitle != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                subtitle,
                style: pw.TextStyle(
                  fontSize: 8,
                  color: emphasize ? PdfColors.white : _Palette.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static pw.Widget _headerCell(String text, {bool alignRight = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(
          text,
          textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
              fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        ),
      );

  static pw.Widget _cell(
    String text, {
    bool alignRight = false,
    bool yearTotal = false,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(
          text,
          textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: yearTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: yearTotal ? _Palette.yearlyIndigo : _Palette.bodyText,
          ),
        ),
      );

  /// Same stack as the on-screen table: invest amount, then ~ customer.
  static pw.Widget _moneyCell(
    String text, {
    String? subtitle,
    bool yearTotal = false,
  }) {
    final color = yearTotal ? _Palette.yearlyIndigo : _Palette.bodyText;
    final weight = yearTotal ? pw.FontWeight.bold : pw.FontWeight.normal;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            text,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(fontSize: 9, fontWeight: weight, color: color),
          ),
          if (subtitle != null)
            pw.Text(
              subtitle,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontSize: 7, fontWeight: weight, color: color),
            ),
        ],
      ),
    );
  }
}
