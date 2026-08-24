// Generates the branded EastmarkHK Snowball Privacy Report (App Store / website).
// Same layout as EastmarkHK e-Invoicing / AI privacy reports.
//
//   dart run tool/generate_privacy_pdf.dart
//
// Output: docs/EastmarkHK_Snowball_Privacy_Report.pdf
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _company = 'EastmarkHK';
const _legalName = 'Eastmark (Asia) Limited';
const _appName = 'EastmarkHK Snowball';
const _website = 'eastmarkhk.com';
const _email = 'eastmarkhk@eastmarkhk.com';
const _address =
    'Flat D, 6/F, Brilliance Court, 3 Discovery Bay Road, Discovery Bay, Hong Kong';
const _lastUpdated = '24 August 2026';
const _headerLine = '$_company  |  $_website  |  $_email';
const _bundleId = 'com.eastmarkhk.eastmarkhkSnowball';
const _appVersion = '1.0.0';
const _outFileName = 'EastmarkHK_Snowball_Privacy_Report.pdf';
const _privacyUrl =
    'https://$_website/privacy/EastmarkHK_Snowball_Privacy_Report.pdf';
const _policyHtmlUrl =
    'https://$_website/privacy/privacy-policy-Snowball.html';

const _primary = PdfColor.fromInt(0xFF12806A);
const _gold = PdfColor.fromInt(0xFF53BBA3);
const _muted = PdfColor.fromInt(0xFF5C6B6A);
const _body = PdfColor.fromInt(0xFF1A1A1A);
const _line = PdfColor.fromInt(0xFFC2D2CC);
const _zebra = PdfColor.fromInt(0xFFEDF7F3);
const _white = PdfColor.fromInt(0xFFFFFFFF);

late final pw.MemoryImage? _logo;
late final pw.Font _font;
late final pw.Font _fontBold;

void main() async {
  final logoFile = File('assets/logo.png');
  _logo = logoFile.existsSync()
      ? pw.MemoryImage(logoFile.readAsBytesSync())
      : null;

  const arial = '/System/Library/Fonts/Supplemental/Arial.ttf';
  const arialBold = '/System/Library/Fonts/Supplemental/Arial Bold.ttf';
  _font = File(arial).existsSync()
      ? pw.Font.ttf(File(arial).readAsBytesSync().buffer.asByteData())
      : pw.Font.helvetica();
  _fontBold = File(arialBold).existsSync()
      ? pw.Font.ttf(File(arialBold).readAsBytesSync().buffer.asByteData())
      : pw.Font.helveticaBold();

  final doc =
      pw.Document(title: 'Privacy Report - $_appName', author: _company);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(46, 40, 46, 44),
      theme: pw.ThemeData.withFont(base: _font, bold: _fontBold),
      header: _header,
      footer: _footer,
      build: (context) => _content(),
    ),
  );

  final outDir = Directory('docs');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  final outFile = File('docs/$_outFileName');
  await outFile.writeAsBytes(await doc.save());
  stdout.writeln('Wrote ${outFile.path} (${outFile.lengthSync()} bytes)');

  final webDir = Directory('../eastmarkhk.com/privacy');
  if (webDir.existsSync()) {
    final webOut = File('${webDir.path}/$_outFileName');
    await webOut.writeAsBytes(await outFile.readAsBytes());
    stdout.writeln('Also copied to ${webOut.path}');
  }
}

pw.Widget _header(pw.Context context) {
  if (context.pageNumber == 1) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (_logo != null) ...[
              pw.SizedBox(
                  width: 52,
                  height: 52,
                  child: pw.Image(_logo!, fit: pw.BoxFit.contain)),
              pw.SizedBox(width: 14),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_appName,
                      style: pw.TextStyle(
                          fontSize: 19,
                          fontWeight: pw.FontWeight.bold,
                          color: _primary)),
                  pw.Text('Privacy Report',
                      style: const pw.TextStyle(fontSize: 13, color: _body)),
                  pw.Text('iPhone  /  iPad  /  Mac',
                      style: const pw.TextStyle(fontSize: 9, color: _muted)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(_website,
                    style: const pw.TextStyle(fontSize: 9, color: _muted)),
                pw.Text(_email,
                    style: const pw.TextStyle(fontSize: 9, color: _muted)),
                pw.Text('Version $_appVersion',
                    style: const pw.TextStyle(fontSize: 8, color: _muted)),
                pw.Text('Updated $_lastUpdated',
                    style: const pw.TextStyle(fontSize: 8, color: _muted)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 2, color: _primary),
        pw.SizedBox(height: 12),
      ],
    );
  }
  return pw.Column(
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$_appName  -  Privacy Report',
              style: pw.TextStyle(
                  fontSize: 8.5,
                  color: _primary,
                  fontWeight: pw.FontWeight.bold)),
          pw.Text(_website,
              style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Container(height: 0.8, color: _line),
      pw.SizedBox(height: 10),
    ],
  );
}

pw.Widget _footer(pw.Context context) => pw.Column(
      children: [
        pw.Container(height: 0.8, color: _line),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(_headerLine,
                style: const pw.TextStyle(fontSize: 7, color: _muted)),
            pw.Text('Page ${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 7, color: _muted)),
          ],
        ),
      ],
    );

pw.Widget _section(String title) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 10, bottom: 5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _primary)),
          pw.SizedBox(height: 2),
          pw.Container(height: 1.4, width: 42, color: _gold),
        ],
      ),
    );

pw.Widget _para(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(text,
          textAlign: pw.TextAlign.justify,
          style: const pw.TextStyle(
              fontSize: 9.5, color: _body, lineSpacing: 1.9)),
    );

pw.Widget _table(List<String> headers, List<List<String>> rows,
    Map<int, pw.TableColumnWidth> widths) {
  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    border: pw.TableBorder.all(color: _line, width: 0.5),
    headerStyle: pw.TextStyle(
        fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _white),
    headerDecoration: const pw.BoxDecoration(color: _primary),
    headerHeight: 18,
    cellStyle: const pw.TextStyle(fontSize: 8.5, color: _body),
    oddRowDecoration: const pw.BoxDecoration(color: _zebra),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    cellAlignment: pw.Alignment.centerLeft,
    columnWidths: widths,
    headerAlignment: pw.Alignment.centerLeft,
  );
}

List<pw.Widget> _content() => [
      _section('1. Introduction'),
      _para(
          'This Privacy Report applies to $_appName (bundle ID $_bundleId), '
          'version $_appVersion, for iPhone, iPad and Mac. $_appName is a '
          'compound-interest calculator: it projects an investment month by month, '
          'optionally converts the result into a second currency, and can export a PDF report.'),
      _para(
          'This document describes the data the app stores, the purposes it is used for, '
          'every network connection the app can make and the system permissions it '
          'requires - in the format expected for App Store / Mac App Store submission '
          '(Privacy Nutrition Labels and PrivacyInfo.xcprivacy) and for publication at '
          'https://$_website/privacy/.'),
      _para(
          '$_company operates no cloud account and no server-side copy of your calculations. '
          '$_appName has no user account, no sign-in and no advertising or analytics SDK. '
          'Figures you type stay on the device unless you yourself save or share a PDF.'),

      _section('2. Data Stored by EastmarkHK Snowball'),
      _table(
        ['Data', 'Storage', 'Shared With', 'Purpose'],
        [
          [
            'Investment inputs (amount, rate, years, contributions)',
            'In memory only, until you leave the screen',
            'Nobody',
            'Run the calculation you asked for'
          ],
          [
            'Chosen investment and reference currencies',
            'SharedPreferences (on-device)',
            'Nobody',
            'Restore the last currencies you picked'
          ],
          [
            'Interface language code and name',
            'SharedPreferences (on-device)',
            'Nobody',
            'Keep the language you selected'
          ],
          [
            'Cached UI translations (non-English)',
            'Application Support / ui_l10n/*.json',
            'Nobody',
            'Avoid translating the same language twice'
          ],
          [
            'PDF report you export',
            'A file you choose (Mac Save dialog) or the share sheet (iPhone / iPad)',
            'Only if you send that file yourself',
            'Print or keep a copy of the projection'
          ],
        ],
        {
          0: const pw.FlexColumnWidth(2.6),
          1: const pw.FlexColumnWidth(2.2),
          2: const pw.FlexColumnWidth(1.8),
          3: const pw.FlexColumnWidth(2.6)
        },
      ),
      pw.SizedBox(height: 6),
      _para(
          'Your principal, rate and contribution amounts are never written to an '
          '$_company database and are never included in translation or exchange-rate requests.'),

      _section('3. Network Connections'),
      _table(
        ['Endpoint', 'Purpose', 'Triggered By', 'Data Sent'],
        [
          [
            'api.frankfurter.app',
            'ECB foreign-exchange rate for the two currencies you selected',
            'You pick two different currencies',
            'ISO currency codes only (for example HKD, EUR). No amounts, no identity'
          ],
          [
            'open.er-api.com',
            'Fallback FX rate if Frankfurter does not list that pair',
            'Frankfurter fails or does not support the pair',
            'ISO currency codes only'
          ],
          [
            'Apple Translation (on-device, Mac / iPhone / iPad)',
            'Translate the app interface',
            'You choose a non-English language and Apple Translation is available',
            'English UI catalogue, processed on-device. Not sent to $_company'
          ],
          [
            'api.mistral.ai',
            'Translate the app interface when Apple Translation is not available',
            'You choose a non-English language on a device without Apple Translation',
            'English UI strings from the app catalogue. Not your investment figures'
          ],
          [
            'fonts.gstatic.com (Google Fonts / Noto Sans)',
            'Unicode font for the PDF preview',
            'The PDF report is generated',
            'A font file download. No personal data'
          ],
        ],
        {
          0: const pw.FlexColumnWidth(2.2),
          1: const pw.FlexColumnWidth(2.4),
          2: const pw.FlexColumnWidth(2.4),
          3: const pw.FlexColumnWidth(2.6)
        },
      ),
      pw.SizedBox(height: 6),
      _para(
          'Calculations themselves work offline. Network use is limited to a live FX quote '
          '(when two currencies differ), optional interface translation, and loading the PDF font.'),

      _section('4. System Permissions Required'),
      _table(
        ['Permission', 'iPhone / iPad', 'Mac', 'Reason'],
        [
          [
            'Network client',
            'When FX, translation or PDF font is needed',
            'App Sandbox network client',
            'Exchange rates, optional Mistral translation, PDF font'
          ],
          [
            'User-selected files',
            'Share / Files (you choose)',
            'Save panel (read-write)',
            'Save the PDF report where you want'
          ],
          [
            'Printing',
            'System print / share',
            'App Sandbox print',
            'Print the PDF report'
          ],
          [
            'Camera',
            'Not used',
            'Not used',
            'Not requested'
          ],
          [
            'Photo Library',
            'Not used',
            'Not used',
            'Not requested'
          ],
          [
            'Microphone',
            'Not used',
            'Not used',
            'Not requested'
          ],
          [
            'Location (GPS)',
            'Not used',
            'Not used',
            'Not requested'
          ],
          [
            'Contacts',
            'Not used',
            'Not used',
            'Not requested'
          ],
          [
            'Tracking / ATT',
            'Not used',
            'Not used',
            'No advertising identifier'
          ],
        ],
        {
          0: const pw.FlexColumnWidth(2.0),
          1: const pw.FlexColumnWidth(2.4),
          2: const pw.FlexColumnWidth(2.2),
          3: const pw.FlexColumnWidth(2.8)
        },
      ),

      _section('5. PrivacyInfo.xcprivacy - Required Reason APIs'),
      _table(
        ['API Category', 'Reason Code', 'Usage'],
        [
          [
            'NSPrivacyAccessedAPICategoryUserDefaults',
            'CA92.1',
            'Read / write language and currency preferences via SharedPreferences'
          ],
          [
            'NSPrivacyAccessedAPICategoryFileTimestamp',
            'C617.1',
            'Manage on-device translation cache files in Application Support'
          ],
        ],
        {
          0: const pw.FlexColumnWidth(3.4),
          1: const pw.FlexColumnWidth(1.4),
          2: const pw.FlexColumnWidth(4.0)
        },
      ),
      pw.SizedBox(height: 6),
      _para(
          'NSPrivacyTracking is set to false. No advertising identifier APIs are used. '
          'NSPrivacyCollectedDataTypes is empty: $_company does not collect personal data from this app.'),

      _section('6. App Store Privacy Nutrition Labels'),
      _table(
        ['Category', 'Collected?', 'Linked to Identity?', 'Used for Tracking?'],
        [
          ['Contact Info', 'No', '-', '-'],
          ['Health & Fitness', 'No', '-', '-'],
          ['Financial Info', 'No (figures stay on device)', '-', '-'],
          ['Location', 'No', '-', '-'],
          ['Sensitive Info', 'No', '-', '-'],
          ['Contacts', 'No', '-', '-'],
          ['User Content', 'No', '-', '-'],
          ['Browsing History', 'No', '-', '-'],
          ['Search History', 'No', '-', '-'],
          ['Identifiers', 'No', '-', '-'],
          ['Purchases', 'No (processed by Apple if you buy the app)', '-', '-'],
          ['Usage Data', 'No', '-', '-'],
          ['Diagnostics', 'No', '-', '-'],
          ['Surroundings', 'No', '-', '-'],
          ['Body', 'No', '-', '-'],
          ['Other Data', 'No', '-', '-'],
        ],
        {
          0: const pw.FlexColumnWidth(2.4),
          1: const pw.FlexColumnWidth(3.0),
          2: const pw.FlexColumnWidth(1.8),
          3: const pw.FlexColumnWidth(1.8)
        },
      ),
      pw.SizedBox(height: 6),
      _para(
          'In App Store Connect, declare Data Not Collected. Optional third-party calls '
          '(FX APIs, Mistral for UI translation, Google Fonts) do not receive your name, '
          'Apple ID, or investment amounts.'),

      _section('7. Data Retention and Deletion'),
      _table(
        ['Data', 'Retention', 'How to Delete'],
        [
          [
            'Language and currency preferences',
            'Until you change them or uninstall',
            'Change in the app, or delete the app'
          ],
          [
            'Cached UI translations',
            'Until uninstall',
            'Delete the app (clears Application Support)'
          ],
          [
            'PDF you saved',
            'Wherever you saved it',
            'Delete that file yourself'
          ],
        ],
        {
          0: const pw.FlexColumnWidth(2.6),
          1: const pw.FlexColumnWidth(2.6),
          2: const pw.FlexColumnWidth(3.2)
        },
      ),
      pw.SizedBox(height: 6),
      _para(
          'Uninstalling the app permanently deletes on-device preferences and translation packs. '
          '$_company has no copy to erase on its servers because none was sent.'),

      _section('8. Third-Party Services'),
      _table(
        ['Service', 'Provider', 'Purpose', 'Data Sent', 'Privacy Policy'],
        [
          [
            'Frankfurter',
            'Frankfurter (ECB rates)',
            'Live FX quote',
            'Currency codes',
            'frankfurter.dev'
          ],
          [
            'Open Exchange Rates API',
            'open.er-api.com',
            'Fallback FX quote',
            'Currency codes',
            'exchangerate-api.com'
          ],
          [
            'Apple Translation',
            'Apple (on-device)',
            'Interface translation',
            'On-device only',
            'apple.com/privacy'
          ],
          [
            'Mistral AI API',
            'Mistral AI',
            'Interface translation fallback',
            'English UI catalogue (not your numbers)',
            'mistral.ai/terms'
          ],
          [
            'Google Fonts (Noto Sans)',
            'Google',
            'PDF Unicode font',
            'Font download only',
            'policies.google.com/privacy'
          ],
          [
            'App Store / Mac App Store',
            'Apple',
            'Purchase and distribution',
            'Per Apple\'s commerce terms',
            'apple.com/privacy'
          ],
        ],
        {
          0: const pw.FlexColumnWidth(1.7),
          1: const pw.FlexColumnWidth(1.8),
          2: const pw.FlexColumnWidth(1.7),
          3: const pw.FlexColumnWidth(2.2),
          4: const pw.FlexColumnWidth(1.6)
        },
      ),
      pw.SizedBox(height: 6),
      _para(
          'No analytics SDKs, advertising networks, crash reporters or third-party tracking libraries are included in $_appName.'),

      _section("9. Children's Privacy"),
      _para(
          '$_appName is a personal finance calculator. It is not directed at children under 13 '
          '(or under 16 in the European Union). We do not knowingly collect any data from children.'),

      _section('10. No Account, No Cloud Login'),
      _para(
          '$_appName does not require an $_company account. There is no sign-in, no licence server '
          'phone-home, and no remote backup of your calculations. App Store purchases are processed by Apple.'),

      _section('11. Changes'),
      _para(
          'Updates to this policy are published at $_policyHtmlUrl and $_privacyUrl '
          'with a new "last updated" date. Material changes to what leaves the device are noted '
          'in the release notes of the version that introduces them.'),

      _section('12. Contact'),
      _para(
          'For any privacy-related question or request regarding $_appName, please contact:'),
      _contactBlock(),
    ];

pw.Widget _contactBlock() => pw.Container(
      decoration: pw.BoxDecoration(
        color: _zebra,
        border: pw.Border.all(color: _line, width: 0.5),
      ),
      child: pw.Column(
        children: [
          _contactRow('Company', '$_company - $_legalName', top: false),
          _contactRow('Website', 'https://$_website'),
          _contactRow('Privacy', _privacyUrl),
          _contactRow('Policy page', _policyHtmlUrl),
          _contactRow('Support', 'https://$_website/support'),
          _contactRow('Terms',
              'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
          _contactRow('Email', _email),
          _contactRow('Address', _address),
        ],
      ),
    );

pw.Widget _contactRow(String label, String value, {bool top = true}) =>
    pw.Container(
      decoration: top
          ? const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _line, width: 0.5)))
          : null,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 78,
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary)),
          ),
          pw.Expanded(
              child: pw.Text(value,
                  style: const pw.TextStyle(fontSize: 9, color: _body))),
        ],
      ),
    );
