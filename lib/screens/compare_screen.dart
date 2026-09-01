import 'package:flutter/material.dart';

import '../l10n/l10n_controller.dart';
import '../models/client_report.dart';
import '../services/exchange_rate_service.dart';
import '../utils/money_format.dart';
import '../widgets/eastmark_footer.dart';
import '../widgets/growth_chart.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({
    super.key,
    required this.l10n,
    required this.reports,
  });

  final L10nController l10n;
  final List<ClientReport> reports;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  late String? _idA;
  late String? _idB;
  ExchangeQuote? _quoteA;
  ExchangeQuote? _quoteB;

  L10nController get _l10n => widget.l10n;

  @override
  void initState() {
    super.initState();
    _idA = widget.reports[0].id;
    _idB = widget.reports.length > 1 ? widget.reports[1].id : null;
    _loadQuotes();
  }

  ClientReport? _byId(String? id) {
    if (id == null) return null;
    for (final r in widget.reports) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> _loadQuotes() async {
    final a = _byId(_idA);
    final b = _byId(_idB);
    final quoteA = a == null ? null : await _quoteFor(a);
    final quoteB = b == null ? null : await _quoteFor(b);
    if (!mounted) return;
    setState(() {
      _quoteA = quoteA;
      _quoteB = quoteB;
    });
  }

  Future<ExchangeQuote?> _quoteFor(ClientReport report) async {
    if (!report.isDualCurrency) return null;
    try {
      return await ExchangeRateService.quote(
        from: report.investCurrency,
        to: report.referenceCurrency,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _byId(_idA);
    final b = _byId(_idB);
    return Scaffold(
      appBar: AppBar(title: Text(_l10n.t('compareTitle'))),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 760;
            final pickers = _pickers();
            final columns = wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: a == null ? const SizedBox.shrink() : _column(a, _quoteA)),
                      const SizedBox(width: 16),
                      Expanded(child: b == null ? const SizedBox.shrink() : _column(b, _quoteB)),
                    ],
                  )
                : Column(
                    children: [
                      if (a != null) _column(a, _quoteA),
                      if (a != null && b != null) const SizedBox(height: 16),
                      if (b != null) _column(b, _quoteB),
                    ],
                  );
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                pickers,
                const SizedBox(height: 16),
                columns,
                if (a != null && b != null) ...[
                  const SizedBox(height: 16),
                  _deltaCard(a, b),
                ],
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const EastmarkFooter(includeBottomSafeArea: true),
    );
  }

  Widget _pickers() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('a-$_idA'),
              initialValue: _idA,
              decoration: InputDecoration(
                labelText: _l10n.t('comparePickA'),
                border: const OutlineInputBorder(),
              ),
              items: widget.reports
                  .map((r) => DropdownMenuItem(
                        value: r.id,
                        child: Text(r.clientName, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (id) {
                setState(() => _idA = id);
                _loadQuotes();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('b-$_idB'),
              initialValue: _idB,
              decoration: InputDecoration(
                labelText: _l10n.t('comparePickB'),
                border: const OutlineInputBorder(),
              ),
              items: widget.reports
                  .map((r) => DropdownMenuItem(
                        value: r.id,
                        child: Text(r.clientName, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (id) {
                setState(() => _idB = id);
                _loadQuotes();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _column(ClientReport report, ExchangeQuote? quote) {
    final result = report.calculate();
    final scheme = Theme.of(context).colorScheme;
    double? toRef(double v) {
      if (quote == null || !report.isDualCurrency) return null;
      return v * quote.rate;
    }

    Widget money(String label, double value) {
      final converted = toRef(value);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  MoneyFormat.amount(value, report.investCurrency),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (converted != null)
                  Text(
                    '~ ${MoneyFormat.amount(converted, report.referenceCurrency)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.clientName,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              report.isDualCurrency
                  ? '${report.investCurrency} → ${report.referenceCurrency}'
                  : report.investCurrency,
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            money(_l10n.t('finalBalance'), result.finalBalance),
            money(_l10n.t('totalContributions'), result.totalContributions),
            money(_l10n.t('totalInterestEarned'), result.totalInterest),
            const SizedBox(height: 12),
            Text(_l10n.t('growthOverTime'),
                style: Theme.of(context).textTheme.titleSmall),
            GrowthChart(
              yearly: result.yearly,
              principal: result.totalPrincipal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _deltaCard(ClientReport a, ClientReport b) {
    final ra = a.calculate();
    final rb = b.calculate();
    final sameCcy = a.investCurrency == b.investCurrency;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _l10n.t('compareDelta'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            if (sameCcy) ...[
              _deltaRow(
                _l10n.t('finalBalance'),
                rb.finalBalance - ra.finalBalance,
                a.investCurrency,
              ),
              _deltaRow(
                _l10n.t('totalInterestEarned'),
                rb.totalInterest - ra.totalInterest,
                a.investCurrency,
              ),
            ] else
              Text(
                '${a.clientName}: ${MoneyFormat.amount(ra.finalBalance, a.investCurrency)}'
                '   ·   ${b.clientName}: ${MoneyFormat.amount(rb.finalBalance, b.investCurrency)}',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
          ],
        ),
      ),
    );
  }

  Widget _deltaRow(String label, double value, String code) {
    final sign = value >= 0 ? '+' : '−';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '$sign ${MoneyFormat.amount(value.abs(), code)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
