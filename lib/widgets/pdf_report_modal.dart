import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../calculator.dart';
import '../l10n/l10n_controller.dart';
import '../services/report_pdf_service.dart';

/// Opens the e-Invoicing-style report modal: thumbnail preview, tap to
/// enlarge (pinch/scroll zoom), print, and download.
Future<void> showPdfReportDialog({
  required BuildContext context,
  required L10nController l10n,
  required CalculationResult result,
  required double annualRatePercent,
  required int years,
  required String compoundingLabel,
  required String investCurrency,
  required String referenceCurrency,
  required double? exchangeRate,
  required DateTime? exchangeAsOf,
  required double contributionAmount,
  required String? contributionFrequencyLabel,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ReportPdfDialog(
      l10n: l10n,
      result: result,
      annualRatePercent: annualRatePercent,
      years: years,
      compoundingLabel: compoundingLabel,
      investCurrency: investCurrency,
      referenceCurrency: referenceCurrency,
      exchangeRate: exchangeRate,
      exchangeAsOf: exchangeAsOf,
      contributionAmount: contributionAmount,
      contributionFrequencyLabel: contributionFrequencyLabel,
    ),
  );
}

class _ReportPdfDialog extends StatefulWidget {
  const _ReportPdfDialog({
    required this.l10n,
    required this.result,
    required this.annualRatePercent,
    required this.years,
    required this.compoundingLabel,
    required this.investCurrency,
    required this.referenceCurrency,
    required this.exchangeRate,
    required this.exchangeAsOf,
    required this.contributionAmount,
    required this.contributionFrequencyLabel,
  });

  final L10nController l10n;
  final CalculationResult result;
  final double annualRatePercent;
  final int years;
  final String compoundingLabel;
  final String investCurrency;
  final String referenceCurrency;
  final double? exchangeRate;
  final DateTime? exchangeAsOf;
  final double contributionAmount;
  final String? contributionFrequencyLabel;

  @override
  State<_ReportPdfDialog> createState() => _ReportPdfDialogState();
}

class _ReportPdfDialogState extends State<_ReportPdfDialog> {
  Uint8List? _bytes;
  Object? _error;
  bool _loading = true;

  L10nController get _l10n => widget.l10n;
  String get _fileName => _l10n.t('reportFileName');

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Uint8List? logoBytes;
      try {
        final data = await rootBundle.load('assets/logo.png');
        logoBytes = data.buffer.asUint8List();
      } catch (_) {
        logoBytes = null;
      }

      final bytes = await ReportPdfService.build(
        l10n: _l10n,
        result: widget.result,
        annualRatePercent: widget.annualRatePercent,
        years: widget.years,
        compoundingLabel: widget.compoundingLabel,
        investCurrency: widget.investCurrency,
        referenceCurrency: widget.referenceCurrency,
        exchangeRate: widget.exchangeRate,
        exchangeAsOf: widget.exchangeAsOf,
        contributionAmount: widget.contributionAmount,
        contributionFrequencyLabel: widget.contributionFrequencyLabel,
        logoBytes: logoBytes,
      );
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  static const _filesChannel = MethodChannel('com.eastmarkhk.snowball/files');

  Future<void> _print() async {
    final bytes = _bytes;
    if (bytes == null) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: _fileName);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _download() async {
    final bytes = _bytes;
    if (bytes == null) return;

    try {
      if (!kIsWeb && Platform.isMacOS) {
        final path = await _filesChannel.invokeMethod<String>('savePdf', {
          'fileName': _fileName,
          'bytes': bytes,
        });
        if (path == null) return;
        _toast(_l10n.t('reportSaved'));
        return;
      }

      final desktop = !kIsWeb && (Platform.isWindows || Platform.isLinux);
      if (desktop) {
        final dir = await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
        final file = File(p.join(dir.path, _fileName));
        await file.writeAsBytes(bytes, flush: true);
        _toast('${_l10n.t('reportSaved')}: ${file.path}');
        return;
      }

      await Printing.sharePdf(bytes: bytes, filename: _fileName);
    } on PlatformException catch (e) {
      final channelGone = e.code == 'channel-error' ||
          (e.message?.contains('Unable to establish connection') ?? false);
      _toast(
        channelGone
            ? _l10n.t('reportRestartToDownload')
            : '${_l10n.t('reportSaveFailed')}\n${e.message ?? e.code}',
      );
    } catch (e) {
      _toast('${_l10n.t('reportSaveFailed')}\n$e');
    }
  }

  Future<void> _enlarge() async {
    final bytes = _bytes;
    if (bytes == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: size.width * 0.92,
            height: size.height * 0.92,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _l10n.t('reportTitle'),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => Printing.layoutPdf(
                          onLayout: (_) async => bytes,
                          name: _fileName,
                        ),
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: Text(_l10n.t('reportPrint')),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: Text(_l10n.t('reportClose')),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _PdfPane(bytes: bytes, interactive: true),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 780;
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding:
          EdgeInsets.symmetric(horizontal: wide ? 40 : 12, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: wide ? 720 : 520,
          maxHeight: size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _l10n.t('reportTitle'),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(_l10n.t('reportClose')),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_loading)
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 8),
                                Text(_l10n.t('reportGenerating')),
                              ],
                            ),
                          )
                        else if (_error != null || _bytes == null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                '${_l10n.t('reportFailed')}\n${_error ?? ''}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          IgnorePointer(
                            child: _PdfPane(bytes: _bytes!, interactive: false),
                          ),
                        if (_bytes != null)
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(onTap: _enlarge),
                            ),
                          ),
                        if (_bytes != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.zoom_in,
                                          color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        _l10n.t('reportTapToEnlarge'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _bytes == null ? null : _print,
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: Text(_l10n.t('reportPrint')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _bytes == null ? null : _download,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(_l10n.t('reportDownload')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfPane extends StatelessWidget {
  const _PdfPane({required this.bytes, required this.interactive});

  final Uint8List bytes;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return PdfPreview(
      build: (_) async => bytes,
      maxPageWidth: interactive ? 1000 : 520,
      allowPrinting: false,
      allowSharing: false,
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      actions: const [],
    );
  }
}
