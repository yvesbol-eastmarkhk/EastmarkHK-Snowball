import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../calculator.dart';
import '../l10n/l10n_controller.dart';
import '../models/client_report.dart';
import '../services/client_report_store.dart';
import '../services/exchange_rate_service.dart';
import '../utils/money_format.dart';
import '../widgets/currency_picker.dart';
import '../widgets/eastmark_footer.dart';
import '../widgets/pdf_report_modal.dart';
import '../widgets/report_results.dart';
import '../widgets/thousands_input_formatter.dart';

class ReportEditorScreen extends StatefulWidget {
  const ReportEditorScreen({
    super.key,
    required this.l10n,
    this.existing,
  });

  final L10nController l10n;
  final ClientReport? existing;

  @override
  State<ReportEditorScreen> createState() => _ReportEditorScreenState();
}

class _ReportEditorScreenState extends State<ReportEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _id;

  final _clientCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  final _contributionCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();

  ReportMode _mode = ReportMode.project;
  CompoundingFrequency _compounding = CompoundingFrequency.monthly;
  ContributionFrequency _contributionFrequency = ContributionFrequency.monthly;
  bool _addContributions = false;
  String _investCurrency = 'HKD';
  String _referenceCurrency = 'USD';
  ExchangeQuote? _quote;
  Object? _fxError;
  bool _fxLoading = false;
  int _fxRequestId = 0;
  CalculationResult? _result;
  String? _goalMessage;
  bool _goalOk = true;

  L10nController get _l10n => widget.l10n;
  bool get _needsFx => _investCurrency != _referenceCurrency;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _id = existing.id;
      _clientCtrl.text = existing.clientName;
      _notesCtrl.text = existing.notes;
      _mode = existing.mode;
      _principalCtrl.text = MoneyFormat.input(existing.principal);
      _rateCtrl.text = MoneyFormat.input(existing.annualRatePercent);
      _yearsCtrl.text = existing.years == 0 ? '' : '${existing.years}';
      _compounding = existing.compounding;
      _addContributions = existing.addContributions;
      _contributionCtrl.text = MoneyFormat.input(existing.contributionAmount);
      _contributionFrequency = existing.contributionFrequency;
      if (existing.targetBalance != null) {
        _targetCtrl.text = MoneyFormat.input(existing.targetBalance!);
      }
      _investCurrency = existing.investCurrency;
      _referenceCurrency = existing.referenceCurrency;
    } else {
      _id = ClientReport.newId();
    }
    _refreshRate();
    if (existing != null && existing.principal > 0 && existing.years > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _buildReport(persist: false);
      });
    }
  }

  @override
  void dispose() {
    _clientCtrl.dispose();
    _notesCtrl.dispose();
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    _contributionCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _setInvestCurrency(String code) async {
    if (code == _investCurrency) return;
    setState(() {
      _investCurrency = code;
      _quote = null;
      _fxError = null;
    });
    await _refreshRate();
  }

  Future<void> _setReferenceCurrency(String code) async {
    if (code == _referenceCurrency) return;
    setState(() {
      _referenceCurrency = code;
      _quote = null;
      _fxError = null;
    });
    await _refreshRate();
  }

  Future<void> _refreshRate() async {
    final from = _investCurrency;
    final to = _referenceCurrency;
    final requestId = ++_fxRequestId;
    if (from == to) {
      setState(() {
        _quote = null;
        _fxError = null;
        _fxLoading = false;
      });
      return;
    }
    setState(() {
      _fxLoading = true;
      _fxError = null;
      _quote = null;
    });
    try {
      final quote = await ExchangeRateService.quote(from: from, to: to);
      if (!mounted || requestId != _fxRequestId) return;
      setState(() {
        _quote = quote;
        _fxLoading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _fxRequestId) return;
      setState(() {
        _fxError = e;
        _quote = null;
        _fxLoading = false;
      });
    }
  }

  double? _toReference(double value) {
    final quote = _quote;
    if (!_needsFx || quote == null) return null;
    if (quote.from != _investCurrency || quote.to != _referenceCurrency) {
      return null;
    }
    return value * quote.rate;
  }

  String _compoundingLabel(CompoundingFrequency f) {
    switch (f) {
      case CompoundingFrequency.annually:
        return _l10n.t('freqAnnually');
      case CompoundingFrequency.semiAnnually:
        return _l10n.t('freqSemiAnnually');
      case CompoundingFrequency.quarterly:
        return _l10n.t('freqQuarterly');
      case CompoundingFrequency.monthly:
        return _l10n.t('freqMonthly');
      case CompoundingFrequency.weekly:
        return _l10n.t('freqWeekly');
      case CompoundingFrequency.daily:
        return _l10n.t('freqDaily');
    }
  }

  String _contribFreqLabel(ContributionFrequency f) {
    switch (f) {
      case ContributionFrequency.monthly:
        return _l10n.t('contribFreqMonthly');
      case ContributionFrequency.annually:
        return _l10n.t('contribFreqAnnually');
    }
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  String? _requiredNumber(String? v, {bool allowZero = true}) {
    if (v == null || v.trim().isEmpty) return _l10n.t('required');
    final n = parseFormattedNumber(v);
    if (n == null) return _l10n.t('enterValidNumber');
    if (n < 0) return _l10n.t('mustBePositive');
    if (!allowZero && n == 0) return _l10n.t('mustBeGreaterThanZero');
    return null;
  }

  ClientReport _draft({
    required double principal,
    required double rate,
    required int years,
    required double contribution,
    required bool addContributions,
    double? target,
  }) {
    return ClientReport(
      id: _id,
      clientName: _clientCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      mode: _mode,
      principal: principal,
      annualRatePercent: rate,
      years: years,
      compounding: _compounding,
      addContributions: addContributions,
      contributionAmount: contribution,
      contributionFrequency: _contributionFrequency,
      targetBalance: target,
      investCurrency: _investCurrency,
      referenceCurrency: _referenceCurrency,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _buildReport({bool persist = true}) async {
    _dismissKeyboard();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final principal = parseFormattedNumber(_principalCtrl.text) ?? 0;
    final rate = parseFormattedNumber(_rateCtrl.text) ?? 0;
    final years = int.parse(_yearsCtrl.text.replaceAll(',', ''));
    var contribution = _addContributions
        ? (parseFormattedNumber(_contributionCtrl.text) ?? 0)
        : 0.0;
    var addContributions = _addContributions;
    double? target;
    String? goalMessage;
    var goalOk = true;

    if (_mode == ReportMode.goal) {
      target = parseFormattedNumber(_targetCtrl.text) ?? 0;
      final needed = requiredContributionForGoal(
        principal: principal,
        annualRatePercent: rate,
        years: years,
        compounding: _compounding,
        targetBalance: target,
        contributionFrequency: _contributionFrequency,
      );
      if (needed == null) {
        setState(() {
          _result = null;
          _goalMessage = _l10n.t('goalUnreachable');
          _goalOk = false;
        });
        return;
      }
      contribution = needed;
      addContributions = needed > 0.005;
      _contributionCtrl.text = MoneyFormat.input(needed);
      _addContributions = addContributions;
      if (needed <= 0.005) {
        goalMessage = _l10n.t('goalReachedWithoutContributions');
      } else {
        goalMessage =
            '${_l10n.t('requiredContribution')}: ${MoneyFormat.amount(needed, _investCurrency)} / ${_contribFreqLabel(_contributionFrequency)}';
      }
    }

    final result = calculateCompoundGrowth(
      principal: principal,
      annualRatePercent: rate,
      years: years,
      compounding: _compounding,
      contributionAmount: addContributions ? contribution : 0,
      contributionFrequency: _contributionFrequency,
    );

    setState(() {
      _result = result;
      _goalMessage = goalMessage;
      _goalOk = goalOk;
      _addContributions = addContributions;
    });
    _refreshRate();

    if (persist) {
      await ClientReportStore.upsert(
        _draft(
          principal: principal,
          rate: rate,
          years: years,
          contribution: contribution,
          addContributions: addContributions,
          target: target,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.t('reportSavedLocally'))),
      );
    }
  }

  void _openPdf() {
    final result = _result;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.t('reportNoDataYet'))),
      );
      return;
    }
    final target = _mode == ReportMode.goal
        ? parseFormattedNumber(_targetCtrl.text)
        : null;
    showPdfReportDialog(
      context: context,
      l10n: _l10n,
      result: result,
      annualRatePercent: parseFormattedNumber(_rateCtrl.text) ?? 0,
      years: int.tryParse(_yearsCtrl.text.replaceAll(',', '')) ?? 0,
      compoundingLabel: _compoundingLabel(_compounding),
      investCurrency: _investCurrency,
      referenceCurrency: _referenceCurrency,
      exchangeRate: _quote?.rate,
      exchangeAsOf: _quote?.asOf,
      contributionAmount: _addContributions
          ? (parseFormattedNumber(_contributionCtrl.text) ?? 0)
          : 0,
      contributionFrequencyLabel:
          _addContributions ? _contribFreqLabel(_contributionFrequency) : null,
      clientName: _clientCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      targetBalance: target,
      fileName: MoneyFormat.pdfFileName(_clientCtrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_l10n.t('editReport')),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: _l10n.t('viewReport'),
              onPressed: _openPdf,
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 760;
              final form = _buildForm(context, isWide: isWide);
              final results = ReportResults(
                l10n: _l10n,
                result: _result,
                investCurrency: _investCurrency,
                referenceCurrency: _referenceCurrency,
                toReference: _toReference,
                onViewPdf: _openPdf,
                goalBanner: _goalBanner(context),
              );
              if (isWide) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: SingleChildScrollView(child: form)),
                      const SizedBox(width: 24),
                      Expanded(child: SingleChildScrollView(child: results)),
                    ],
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    form,
                    const SizedBox(height: 24),
                    results,
                  ],
                ),
              );
            },
          ),
        ),
        bottomNavigationBar: const EastmarkFooter(includeBottomSafeArea: true),
      ),
    );
  }

  Widget? _goalBanner(BuildContext context) {
    final message = _goalMessage;
    if (message == null) return null;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: _goalOk ? scheme.secondaryContainer : scheme.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _goalOk ? Icons.flag_outlined : Icons.error_outline,
              color: _goalOk
                  ? scheme.onSecondaryContainer
                  : scheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: _goalOk
                      ? scheme.onSecondaryContainer
                      : scheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, {required bool isWide}) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _card(
            context,
            children: [
              Text(
                _l10n.t('preparedFor'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clientCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: _l10n.t('clientName'),
                  hintText: _l10n.t('clientNameHint'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? _l10n.t('required') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: _l10n.t('clientNotes'),
                  hintText: _l10n.t('clientNotesHint'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            context,
            children: [
              Text(
                _l10n.t('yourInvestment'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SegmentedButton<ReportMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ReportMode.project,
                    label: Text(_l10n.t('modeProject')),
                  ),
                  ButtonSegment(
                    value: ReportMode.goal,
                    label: Text(_l10n.t('modeGoal')),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() {
                  _mode = s.first;
                  _goalMessage = null;
                }),
              ),
              const SizedBox(height: 8),
              Text(
                _mode == ReportMode.goal
                    ? _l10n.t('modeGoalSubtitle')
                    : _l10n.t('modeProjectSubtitle'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (isWide)
                LayoutBuilder(
                  builder: (context, rowConstraints) {
                    const gap = 12.0;
                    final fieldWidth = (rowConstraints.maxWidth - gap * 2) / 3;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: _principalField(),
                        ),
                        const SizedBox(width: gap),
                        SizedBox(
                          width: fieldWidth,
                          child: CurrencyField(
                            l10n: _l10n,
                            label: _l10n.t('investCurrency'),
                            code: _investCurrency,
                            onChanged: _setInvestCurrency,
                          ),
                        ),
                        const SizedBox(width: gap),
                        SizedBox(
                          width: fieldWidth,
                          child: CurrencyField(
                            l10n: _l10n,
                            label: _l10n.t('referenceCurrency'),
                            code: _referenceCurrency,
                            onChanged: _setReferenceCurrency,
                          ),
                        ),
                      ],
                    );
                  },
                )
              else ...[
                Row(
                  children: [
                    Expanded(flex: 2, child: _principalField()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CurrencyField(
                        l10n: _l10n,
                        label: _l10n.t('investCurrency'),
                        code: _investCurrency,
                        onChanged: _setInvestCurrency,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CurrencyField(
                  l10n: _l10n,
                  label: _l10n.t('referenceCurrency'),
                  code: _referenceCurrency,
                  onChanged: _setReferenceCurrency,
                ),
              ],
              if (_needsFx) ...[
                const SizedBox(height: 10),
                _buildRateRow(context),
                const SizedBox(height: 8),
                _dualCurrencyBanner(context),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rateCtrl,
                      textAlign: TextAlign.right,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onTapOutside: (_) => _dismissKeyboard(),
                      decoration: InputDecoration(
                        labelText: _l10n.t('annualRate'),
                        hintText: '0',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => _requiredNumber(v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _yearsCtrl,
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onTapOutside: (_) => _dismissKeyboard(),
                      onFieldSubmitted: (_) => _dismissKeyboard(),
                      decoration: InputDecoration(
                        labelText: _l10n.t('numberOfYears'),
                        hintText: '0',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final err = _requiredNumber(v, allowZero: false);
                        if (err != null) return err;
                        if (int.tryParse(v!.replaceAll(',', '')) == null) {
                          return _l10n.t('wholeNumber');
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CompoundingFrequency>(
                initialValue: _compounding,
                decoration: InputDecoration(
                  labelText: _l10n.t('compoundingFrequency'),
                  border: const OutlineInputBorder(),
                ),
                items: CompoundingFrequency.values
                    .map((f) => DropdownMenuItem(
                        value: f, child: Text(_compoundingLabel(f))))
                    .toList(),
                onChanged: (v) => setState(() => _compounding = v!),
              ),
              if (_mode == ReportMode.goal) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _targetCtrl,
                  textAlign: TextAlign.right,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [ThousandsInputFormatter()],
                  decoration: InputDecoration(
                    labelText: _l10n.t('targetBalance'),
                    hintText: '0',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => _mode == ReportMode.goal
                      ? _requiredNumber(v, allowZero: false)
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ContributionFrequency>(
                  initialValue: _contributionFrequency,
                  decoration: InputDecoration(
                    labelText: _l10n.t('frequency'),
                    border: const OutlineInputBorder(),
                  ),
                  items: ContributionFrequency.values
                      .map((f) => DropdownMenuItem(
                          value: f, child: Text(_contribFreqLabel(f))))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _contributionFrequency = v!),
                ),
              ] else ...[
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_l10n.t('addContributions')),
                  subtitle: Text(_l10n.t('addContributionsSubtitle')),
                  value: _addContributions,
                  onChanged: (v) => setState(() => _addContributions = v),
                ),
                if (_addContributions) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _contributionCtrl,
                          textAlign: TextAlign.right,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [ThousandsInputFormatter()],
                          decoration: InputDecoration(
                            labelText: _l10n.t('contributionAmount'),
                            hintText: '0',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              _addContributions ? _requiredNumber(v) : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<ContributionFrequency>(
                          initialValue: _contributionFrequency,
                          decoration: InputDecoration(
                            labelText: _l10n.t('frequency'),
                            border: const OutlineInputBorder(),
                          ),
                          items: ContributionFrequency.values
                              .map((f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(_contribFreqLabel(f))))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _contributionFrequency = v!),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _buildReport(),
                  icon: const Icon(Icons.assignment_outlined),
                  label: Text(_l10n.t('calculate')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _principalField() {
    return TextFormField(
      controller: _principalCtrl,
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onTapOutside: (_) => _dismissKeyboard(),
      inputFormatters: [ThousandsInputFormatter()],
      decoration: InputDecoration(
        labelText: _l10n.t('initialInvestment'),
        hintText: '0',
        border: const OutlineInputBorder(),
      ),
      validator: (v) => _requiredNumber(v, allowZero: false),
    );
  }

  Widget _dualCurrencyBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = _l10n
        .t('dualCurrencyBanner')
        .replaceAll('{from}', _investCurrency)
        .replaceAll('{to}', _referenceCurrency);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _card(BuildContext context, {required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _buildRateRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_fxLoading) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(_l10n.t('exchangeRate'),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }
    if (_fxError != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '${_l10n.t('exchangeUnavailable')}\n$_fxError',
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: _l10n.t('exchangeRate'),
            onPressed: _refreshRate,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ],
      );
    }
    final quote = _quote;
    if (quote == null) return const SizedBox.shrink();
    final date = DateFormat('yyyy-MM-dd').format(quote.asOf);
    return Row(
      children: [
        Expanded(
          child: Text(
            '1 ${quote.from} = ${MoneyFormat.number.format(quote.rate)} ${quote.to}  ·  $date',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        IconButton(
          tooltip: _l10n.t('exchangeRate'),
          onPressed: _refreshRate,
          icon: const Icon(Icons.refresh, size: 20),
        ),
      ],
    );
  }
}
