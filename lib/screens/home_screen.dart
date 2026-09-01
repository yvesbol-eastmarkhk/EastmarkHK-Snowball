import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n_controller.dart';
import '../models/client_report.dart';
import '../services/client_report_store.dart';
import '../utils/money_format.dart';
import '../widgets/eastmark_footer.dart';
import 'compare_screen.dart';
import 'report_editor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final L10nController l10n;
  const HomeScreen({super.key, required this.l10n});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ClientReport> _reports = [];
  bool _loading = true;

  L10nController get _l10n => widget.l10n;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final reports = await ClientReportStore.load();
    if (!mounted) return;
    setState(() {
      _reports = reports;
      _loading = false;
    });
  }

  Future<void> _openEditor({ClientReport? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ReportEditorScreen(l10n: _l10n, existing: existing),
      ),
    );
    await _reload();
  }

  Future<void> _duplicate(ClientReport report) async {
    final copy = report.duplicated(copySuffix: _l10n.t('copySuffix'));
    await ClientReportStore.upsert(copy);
    await _openEditor(existing: copy);
  }

  Future<void> _delete(ClientReport report) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_l10n.t('deleteReport')),
        content: Text(_l10n.t('deleteReportConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_l10n.t('deleteReport')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ClientReportStore.delete(report.id);
    await _reload();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettingsScreen(l10n: _l10n)),
    );
  }

  void _openCompare() {
    if (_reports.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.t('compareNeedTwo'))),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompareScreen(l10n: _l10n, reports: _reports),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.compare_arrows),
            tooltip: _l10n.t('compareReports'),
            onPressed: _openCompare,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: _l10n.t('settings'),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.primary,
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _l10n.t('appTagline'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                    ? _emptyState(context)
                    : _list(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(_l10n.t('newClientReport')),
      ),
      bottomNavigationBar: const EastmarkFooter(includeBottomSafeArea: true),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_shared_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _l10n.t('emptyWorkspaceTitle'),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _l10n.t('emptyWorkspaceBody'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(_l10n.t('newClientReport')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final hasSample = _reports.any((r) => r.isSample);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: _reports.length + (hasSample ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (hasSample && index == 0) {
          return _hintBanner(context);
        }
        final report = _reports[hasSample ? index - 1 : index];
        return _ReportCard(
          l10n: _l10n,
          report: report,
          onOpen: () => _openEditor(existing: report),
          onDuplicate: () => _duplicate(report),
          onDelete: () => _delete(report),
        );
      },
    );
  }

  Widget _hintBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: scheme.onPrimaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _l10n.t('openSampleHint'),
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.l10n,
    required this.report,
    required this.onOpen,
    required this.onDuplicate,
    required this.onDelete,
  });

  final L10nController l10n;
  final ClientReport report;
  final VoidCallback onOpen;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = DateFormat('yyyy-MM-dd').format(report.updatedAt);
    final pair = report.isDualCurrency
        ? '${report.investCurrency} → ${report.referenceCurrency}'
        : report.investCurrency;
    final summary =
        '${MoneyFormat.amount(report.principal, report.investCurrency)} · ${report.years} ${l10n.t('year').toLowerCase()} · ${MoneyFormat.number.format(report.annualRatePercent)}%';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  report.clientName.isEmpty
                      ? '?'
                      : report.clientName.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            report.clientName,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (report.isSample) ...[
                          const SizedBox(width: 8),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(l10n.t('sampleChip')),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pair,
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(summary, style: Theme.of(context).textTheme.bodySmall),
                    Text(date, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'duplicate') onDuplicate();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'duplicate',
                    child: Text(l10n.t('duplicateReport')),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(l10n.t('deleteReport')),
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
