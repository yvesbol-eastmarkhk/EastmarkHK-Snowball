import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n_controller.dart';
import '../services/mistral_ai_service.dart';

/// Missing / invalid Mistral key → open the console + paste / save.
/// Returns `true` if a non-empty key was stored on this device.
Future<bool> showMistralApiKeyDialog(
  BuildContext context, {
  required L10nController l10n,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _MistralApiKeyDialog(l10n: l10n),
  );
  return result == true;
}

class _MistralApiKeyDialog extends StatefulWidget {
  final L10nController l10n;
  const _MistralApiKeyDialog({required this.l10n});

  @override
  State<_MistralApiKeyDialog> createState() => _MistralApiKeyDialogState();
}

class _MistralApiKeyDialogState extends State<_MistralApiKeyDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = false;
  bool _saving = false;
  String? _error;

  L10nController get l10n => widget.l10n;

  @override
  void initState() {
    super.initState();
    MistralAiService.loadStoredApiKey().then((k) {
      if (!mounted || k.isEmpty) return;
      _ctrl.text = k;
      _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: k.length);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _openConsole() async {
    await launchUrl(
      MistralAiService.apiKeysConsoleUri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _saveAndContinue() async {
    final key = _ctrl.text.trim();
    if (key.isEmpty) {
      setState(() => _error = l10n.t('settingsMistralApiKey'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await MistralAiService.validateAndSaveApiKey(key);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = isMistralApiKeyMissingError(e)
            ? l10n.t('settingsMistralKeyInvalid')
            : '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(l10n.t('settingsMistralApiKey')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.t('settingsMistralKeyNeeded'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(l10n.t('settingsMistralStep1'),
                  style: Theme.of(context).textTheme.bodySmall),
              Text(l10n.t('settingsMistralStep2'),
                  style: Theme.of(context).textTheme.bodySmall),
              Text(l10n.t('settingsMistralStep3'),
                  style: Theme.of(context).textTheme.bodySmall),
              Text(l10n.t('settingsMistralStep4'),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openConsole,
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.t('settingsMistralCreateKey')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                obscureText: _obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.t('settingsMistralApiKey'),
                  border: const OutlineInputBorder(),
                  errorText: _error,
                  suffixIcon: IconButton(
                    tooltip: _obscure
                        ? l10n.t('settingsShowKey')
                        : l10n.t('settingsHideKey'),
                    icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _saveAndContinue(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.t('cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _saveAndContinue,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.t('save')),
        ),
      ],
    );
  }
}
