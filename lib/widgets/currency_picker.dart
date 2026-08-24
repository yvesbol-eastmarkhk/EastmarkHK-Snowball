import 'package:flutter/material.dart';

import '../data/currencies.dart';
import '../l10n/l10n_controller.dart';
import 'country_flag_icon.dart';

/// Field that opens a compact flagged currency modal.
class CurrencyField extends StatelessWidget {
  const CurrencyField({
    super.key,
    required this.l10n,
    required this.label,
    required this.code,
    required this.onChanged,
  });

  final L10nController l10n;
  final String label;
  final String code;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final option = currencyByCode(code);
    return SizedBox(
      width: double.infinity,
      child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _open(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
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
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                option == null ? code : '${option.code}  ${option.symbol}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _CurrencyPickerModal(
        l10n: l10n,
        selected: code,
      ),
    );
    if (picked != null && picked != code) onChanged(picked);
  }
}

class _CurrencyPickerModal extends StatefulWidget {
  const _CurrencyPickerModal({required this.l10n, required this.selected});

  final L10nController l10n;
  final String selected;

  @override
  State<_CurrencyPickerModal> createState() => _CurrencyPickerModalState();
}

class _CurrencyPickerModalState extends State<_CurrencyPickerModal> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final q = _query.toLowerCase();
    final filtered = supportedCurrencies.where((c) {
      if (q.isEmpty) return true;
      return c.code.toLowerCase().contains(q) ||
          c.name.toLowerCase().contains(q) ||
          c.symbol.toLowerCase().contains(q);
    }).toList();

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
                  Icon(Icons.payments_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.t('currency'),
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
                  hintText: l10n.t('searchCurrency'),
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
                  for (final c in filtered)
                    ListTile(
                      leading: CountryFlagIcon(
                        countryCode: c.flagCountry,
                        width: 28,
                        height: 20,
                      ),
                      title: Text('${c.code} — ${c.name}'),
                      subtitle: Text(c.symbol),
                      trailing: c.code == widget.selected
                          ? Icon(Icons.check,
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () => Navigator.pop(context, c.code),
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
