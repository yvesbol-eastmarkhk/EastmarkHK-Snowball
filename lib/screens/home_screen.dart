import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../calculator.dart';
import '../data/currencies.dart';
import '../l10n/l10n_controller.dart';
import '../services/exchange_rate_service.dart';
import '../widgets/currency_picker.dart';
import '../widgets/eastmark_footer.dart';
import '../widgets/growth_chart.dart';
import '../widgets/pdf_report_modal.dart';
import '../widgets/thousands_input_formatter.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final L10nController l10n;
  const HomeScreen({super.key, required this.l10n});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();

  // Empty by default — the "0" the user sees is just a hint in the field,
  // not a real value they need to delete before typing.
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  final _contributionCtrl = TextEditingController();

  CompoundingFrequency _compounding = CompoundingFrequency.annually;
  ContributionFrequency _contributionFrequency = ContributionFrequency.monthly;
  bool _addContributions = false;
  String _investCurrency = 'HKD';
  String _referenceCurrency = 'HKD';
  ExchangeQuote? _quote;
  Object? _fxError;
  bool _fxLoading = false;
  int _fxRequestId = 0;

  CalculationResult? _result;

  static const _prefInvestCcy = 'invest_currency';
  static const _prefRefCcy = 'reference_currency';

  L10nController get _l10n => widget.l10n;

  bool get _needsFx => _investCurrency != _referenceCurrency;

  @override
  void initState() {
    super.initState();
    _restoreCurrencies();
  }

  Future<void> _restoreCurrencies() async {
    final prefs = await SharedPreferences.getInstance();
    final invest = prefs.getString(_prefInvestCcy);
    final reference = prefs.getString(_prefRefCcy);
    if (!mounted) return;
    setState(() {
      if (invest != null && currencyByCode(invest) != null) {
        _investCurrency = invest;
      }
      if (reference != null && currencyByCode(reference) != null) {
        _referenceCurrency = reference;
      }
    });
    await _refreshRate();
  }

  Future<void> _saveCurrencies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefInvestCcy, _investCurrency);
    await prefs.setString(_prefRefCcy, _referenceCurrency);
  }

  Future<void> _setInvestCurrency(String code) async {
    if (code == _investCurrency) return;
    setState(() {
      _investCurrency = code;
      _quote = null;
      _fxError = null;
    });
    await _saveCurrencies();
    await _refreshRate();
  }

  Future<void> _setReferenceCurrency(String code) async {
    if (code == _referenceCurrency) return;
    setState(() {
      _referenceCurrency = code;
      _quote = null;
      _fxError = null;
    });
    await _saveCurrencies();
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

  @override
  void dispose() {
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    _contributionCtrl.dispose();
    super.dispose();
  }

  // Always comma for thousands, dot for decimals — regardless of the
  // device's own locale settings.
  static final NumberFormat _numberFormat = NumberFormat('#,##0.00', 'en_US');

  String _fmt(double value, {String? code}) {
    final symbol = currencySymbol(code ?? _investCurrency);
    return '$symbol ${_numberFormat.format(value)}';
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

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;
    final principal = parseFormattedNumber(_principalCtrl.text) ?? 0;
    final rate = parseFormattedNumber(_rateCtrl.text) ?? 0;
    final years = int.parse(_yearsCtrl.text.replaceAll(',', ''));
    final contribution = _addContributions
        ? (parseFormattedNumber(_contributionCtrl.text) ?? 0)
        : 0.0;

    setState(() {
      _result = calculateCompoundGrowth(
        principal: principal,
        annualRatePercent: rate,
        years: years,
        compounding: _compounding,
        contributionAmount: contribution,
        contributionFrequency: _contributionFrequency,
      );
    });
    _refreshRate();
  }

  String? _requiredNumber(String? v, {bool allowZero = true}) {
    if (v == null || v.trim().isEmpty) return _l10n.t('required');
    final n = parseFormattedNumber(v);
    if (n == null) return _l10n.t('enterValidNumber');
    if (n < 0) return _l10n.t('mustBePositive');
    if (!allowZero && n == 0) return _l10n.t('mustBeGreaterThanZero');
    return null;
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => SettingsScreen(l10n: _l10n)),
    );
  }

  void _openReport() {
    final result = _result;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.t('reportNoDataYet'))),
      );
      return;
    }
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        centerTitle: true,
        titleSpacing: 0,
        leadingWidth: 220,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Image.asset(
              'assets/logo.png',
              height: 52,
              fit: BoxFit.contain,
            ),
          ),
        ),
        title: Text(_l10n.t('appTitle')),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: _l10n.t('viewReport'),
            onPressed: _openReport,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: _l10n.t('settings'),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 760;
            final form = _buildForm(context, isWide: isWide);
            final results = _buildResults(context, result);

            if (isWide) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SingleChildScrollView(child: form)),
                    const SizedBox(width: 24),
                    Expanded(
                      child: SingleChildScrollView(child: results),
                    ),
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
    );
  }

  Widget _buildForm(BuildContext context, {required bool isWide}) {
    return Form(
      key: _formKey,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_l10n.t('yourInvestment'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              if (isWide)
                LayoutBuilder(
                  builder: (context, rowConstraints) {
                    const gap = 12.0;
                    final fieldWidth =
                        (rowConstraints.maxWidth - gap * 2) / 3;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: TextFormField(
                            controller: _principalCtrl,
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [ThousandsInputFormatter()],
                            decoration: InputDecoration(
                              labelText: _l10n.t('initialInvestment'),
                              hintText: '0',
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                _requiredNumber(v, allowZero: false),
                          ),
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
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _principalCtrl,
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [ThousandsInputFormatter()],
                        decoration: InputDecoration(
                          labelText: _l10n.t('initialInvestment'),
                          hintText: '0',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => _requiredNumber(v, allowZero: false),
                      ),
                    ),
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
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rateCtrl,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                                value: f, child: Text(_contribFreqLabel(f))))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _contributionFrequency = v!),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _calculate,
                  icon: const Icon(Icons.calculate_outlined),
                  label: Text(_l10n.t('calculate')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, CalculationResult? result) {
    final scheme = Theme.of(context).colorScheme;
    if (result == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              _l10n.t('emptyResultsHint'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          color: scheme.primaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_l10n.t('finalBalance'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                        )),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _fmt(result.finalBalance),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (_toReference(result.finalBalance) != null) ...[
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '≈ ${_fmt(_toReference(result.finalBalance)!, code: _referenceCurrency)}',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                          ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _statRow(context, _l10n.t('initialInvestment'), result.totalPrincipal),
                if (result.totalContributions > 0)
                  _statRow(context, _l10n.t('totalContributions'),
                      result.totalContributions),
                _statRow(context, _l10n.t('totalInterestEarned'), result.totalInterest),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_l10n.t('growthOverTime'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                GrowthChart(yearly: result.yearly, principal: result.totalPrincipal),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_l10n.t('monthByMonthBreakdown'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(0.7),
                    1: FlexColumnWidth(0.7),
                    2: FlexColumnWidth(1.4),
                    3: FlexColumnWidth(1.4),
                    4: FlexColumnWidth(1.6),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                      children: [
                        _tableHead(_l10n.t('year')),
                        _tableHead(_l10n.t('month')),
                        _tableHead(_l10n.t('contributed'), alignEnd: true),
                        _tableHead(_l10n.t('interest'), alignEnd: true),
                        _tableHead(_l10n.t('balance'), alignEnd: true),
                      ],
                    ),
                    ...breakdownTableRows(result).map((row) {
                      return TableRow(
                        decoration: row.isYearTotal
                            ? const BoxDecoration(color: Color(0xFFE8EAF6))
                            : null,
                        children: [
                          _tableCell('${row.year}', yearTotal: row.isYearTotal),
                          _tableCell(
                            row.isYearTotal
                                ? _l10n.t('yearTotal')
                                : '${row.month}',
                            yearTotal: row.isYearTotal,
                          ),
                          _moneyCell(row.contributions, yearTotal: row.isYearTotal),
                          _moneyCell(row.interest, yearTotal: row.isYearTotal),
                          _moneyCell(row.balance, yearTotal: row.isYearTotal),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _openReport,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_l10n.t('viewReport')),
          ),
        ),
        const SizedBox(height: 16),
      ],
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
          Text(_l10n.t('exchangeRate'), style: Theme.of(context).textTheme.bodySmall),
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
            '1 ${quote.from} = ${_numberFormat.format(quote.rate)} ${quote.to}  ·  $date',
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

  Widget _tableHead(String text, {bool alignEnd = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        text,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _tableCell(String text, {bool alignEnd = false, bool yearTotal = false}) {
    const indigo = Color(0xFF3F51B5);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Text(
        text,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        style: yearTotal
            ? const TextStyle(color: indigo, fontWeight: FontWeight.bold)
            : null,
      ),
    );
  }

  Widget _moneyCell(double value, {bool yearTotal = false}) {
    const indigo = Color(0xFF3F51B5);
    final converted = _toReference(value);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _fmt(value),
            textAlign: TextAlign.right,
            style: yearTotal
                ? const TextStyle(color: indigo, fontWeight: FontWeight.bold)
                : null,
          ),
          if (converted != null)
            Text(
              '≈ ${_fmt(converted, code: _referenceCurrency)}',
              textAlign: TextAlign.right,
              style: yearTotal
                  ? const TextStyle(
                      color: indigo,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    )
                  : Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _statRow(BuildContext context, String label, double value) {
    final scheme = Theme.of(context).colorScheme;
    final converted = _toReference(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onPrimaryContainer.withValues(alpha: 0.85))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmt(value),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      )),
              if (converted != null)
                Text(
                  '≈ ${_fmt(converted, code: _referenceCurrency)}',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
