import 'package:flutter/material.dart';

import '../calculator.dart';
import '../l10n/l10n_controller.dart';
import '../utils/money_format.dart';
import 'growth_chart.dart';

/// Results for a built client report: headline, chart, month table, PDF.
class ReportResults extends StatelessWidget {
  const ReportResults({
    super.key,
    required this.l10n,
    required this.result,
    required this.investCurrency,
    required this.referenceCurrency,
    required this.toReference,
    required this.onViewPdf,
    this.goalBanner,
  });

  final L10nController l10n;
  final CalculationResult? result;
  final String investCurrency;
  final String referenceCurrency;
  final double? Function(double value) toReference;
  final VoidCallback onViewPdf;
  final Widget? goalBanner;

  String _fmt(double value, {String? code}) =>
      MoneyFormat.amount(value, code ?? investCurrency);

  @override
  Widget build(BuildContext context) {
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
              l10n.t('emptyResultsHint'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final r = result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (goalBanner != null) ...[
          goalBanner!,
          const SizedBox(height: 16),
        ],
        Card(
          elevation: 0,
          color: scheme.primaryContainer,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('finalBalance'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _fmt(r.finalBalance),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (toReference(r.finalBalance) != null) ...[
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '~ ${_fmt(toReference(r.finalBalance)!, code: referenceCurrency)}',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimaryContainer
                                .withValues(alpha: 0.85),
                          ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _statRow(context, l10n.t('initialInvestment'), r.totalPrincipal),
                if (r.totalContributions > 0)
                  _statRow(
                    context,
                    l10n.t('totalContributions'),
                    r.totalContributions,
                  ),
                _statRow(
                  context,
                  l10n.t('totalInterestEarned'),
                  r.totalInterest,
                ),
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
                Text(
                  l10n.t('growthOverTime'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                GrowthChart(yearly: r.yearly, principal: r.totalPrincipal),
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
                Text(
                  l10n.t('monthByMonthBreakdown'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
                        _tableHead(l10n.t('year')),
                        _tableHead(l10n.t('month')),
                        _tableHead(l10n.t('contributed'), alignEnd: true),
                        _tableHead(l10n.t('interest'), alignEnd: true),
                        _tableHead(l10n.t('balance'), alignEnd: true),
                      ],
                    ),
                    ...breakdownTableRows(r).map((row) {
                      return TableRow(
                        decoration: row.isYearTotal
                            ? const BoxDecoration(color: Color(0xFFE8EAF6))
                            : null,
                        children: [
                          _tableCell('${row.year}', yearTotal: row.isYearTotal),
                          _tableCell(
                            row.isYearTotal
                                ? l10n.t('yearTotal')
                                : '${row.month}',
                            yearTotal: row.isYearTotal,
                          ),
                          _moneyCell(row.contributions,
                              yearTotal: row.isYearTotal),
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
            onPressed: onViewPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(l10n.t('viewReport')),
          ),
        ),
        const SizedBox(height: 16),
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
    final converted = toReference(value);
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
              '~ ${_fmt(converted, code: referenceCurrency)}',
              textAlign: TextAlign.right,
              style: yearTotal
                  ? const TextStyle(
                      color: indigo,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    )
                  : const TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _statRow(BuildContext context, String label, double value) {
    final scheme = Theme.of(context).colorScheme;
    final converted = toReference(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmt(value),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (converted != null)
                Text(
                  '~ ${_fmt(converted, code: referenceCurrency)}',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            scheme.onPrimaryContainer.withValues(alpha: 0.75),
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
