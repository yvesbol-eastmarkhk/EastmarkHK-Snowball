import 'package:flutter/material.dart';

import '../l10n/l10n_controller.dart';
import '../l10n/locale_names.dart';
import 'country_flag_icon.dart';

/// Compact language field. Tapping it opens a fixed-size modal with a
/// search box and a flag for each language — same pattern as e-Invoicing.
class LanguageDropdown extends StatelessWidget {
  final L10nController l10n;
  const LanguageDropdown({super.key, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: l10n,
      builder: (context, _) {
        final option = languageOptionForCode(l10n.languageCode);
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openPicker(context),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.t('language'),
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Row(
              children: [
                CountryFlagIcon(
                  countryCode: option?.flagCountry,
                  width: 22,
                  height: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    option?.nativeName ?? l10n.languageName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _LanguagePickerModal(l10n: l10n),
    );
  }
}

class _LanguagePickerModal extends StatefulWidget {
  final L10nController l10n;
  const _LanguagePickerModal({required this.l10n});

  @override
  State<_LanguagePickerModal> createState() => _LanguagePickerModalState();
}

class _LanguagePickerModalState extends State<_LanguagePickerModal> {
  String _query = '';

  Future<void> _pick(String code, String name) async {
    final navigator = Navigator.of(context);
    final rootContext = navigator.context;
    navigator.pop();

    final isReselect = code == widget.l10n.languageCode;
    if (!rootContext.mounted) return;
    await _translateWithProgress(rootContext, code, name, force: isReselect);
  }

  Future<void> _translateWithProgress(
    BuildContext context,
    String code,
    String name, {
    bool force = false,
  }) async {
    if (code == 'en' || code.startsWith('en_')) {
      await widget.l10n.setLanguage(code, name);
      return;
    }

    final future = widget.l10n.setLanguage(code, name, force: force);
    final finishedFast = await Future.any([
      future.then((_) => true),
      Future.delayed(const Duration(milliseconds: 250), () => false),
    ]);
    if (finishedFast) {
      if (context.mounted) _showTranslationProblem(context);
      return;
    }
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AnimatedBuilder(
          animation: widget.l10n,
          builder: (ctx, _) {
            final total =
                widget.l10n.translateTotal <= 0 ? 1 : widget.l10n.translateTotal;
            final done = widget.l10n.translateDone;
            final engine = widget.l10n.translatingEngine;
            final isMistral = engine.contains('Mistral');
            return AlertDialog(
              title: Text('${widget.l10n.t('translating')} $name'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        isMistral ? Icons.cloud_outlined : Icons.auto_awesome,
                        size: 18,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          engine.isEmpty ? '…' : engine,
                          style: Theme.of(ctx)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('$done / $total', style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: done / total),
                ],
              ),
            );
          },
        ),
      ),
    );

    await future;
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _showTranslationProblem(context);
    }
  }

  void _showTranslationProblem(BuildContext context) {
    final problem = widget.l10n.lastError;
    if (problem == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(problem, maxLines: 6, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final q = _query.toLowerCase();
    final filtered = languagesAlphabetical().where((lang) {
      if (q.isEmpty) return true;
      return lang.englishName.toLowerCase().contains(q) ||
          lang.nativeName.toLowerCase().contains(q) ||
          lang.code.toLowerCase().contains(q) ||
          lang.flagCountry.toLowerCase().contains(q);
    }).toList();

    final systemCode = L10nController.systemLanguageCode();
    final systemOption = languageOptionForCode(systemCode);
    final systemName = systemOption?.englishName ?? systemCode;
    final selected = l10n.languageCode;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 480,
        height: 560,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.translate, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.t('language'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.t('reportClose'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.t('languageSearchHint'),
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  if (q.isEmpty)
                    ListTile(
                      leading: const Icon(Icons.smartphone_outlined),
                      title: Text(l10n.t('systemLanguage')),
                      subtitle: Text(systemOption?.nativeName ?? systemName),
                      trailing: selected == systemCode
                          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () => _pick(systemCode, systemName),
                    ),
                  if (q.isEmpty) const Divider(height: 1),
                  for (final lang in filtered)
                    ListTile(
                      leading: CountryFlagIcon(
                        countryCode: lang.flagCountry,
                        width: 28,
                        height: 20,
                      ),
                      title: Text(lang.englishName),
                      subtitle: Text(lang.nativeName),
                      trailing: lang.code == selected
                          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () => _pick(lang.code, lang.englishName),
                    ),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(l10n.t('languageNoneFound'))),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
