import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n_controller.dart';
import '../services/mistral_ai_service.dart';
import '../widgets/eastmark_footer.dart';
import '../widgets/language_dropdown.dart';

class SettingsScreen extends StatefulWidget {
  final L10nController l10n;
  const SettingsScreen({super.key, required this.l10n});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _hasStored = false;
  String? _status;
  String? _statusError;

  L10nController get l10n => widget.l10n;

  @override
  void initState() {
    super.initState();
    _loadStoredKey();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStoredKey() async {
    final stored = await MistralAiService.loadStoredApiKey();
    if (!mounted) return;
    setState(() {
      _keyCtrl.text = stored;
      _hasStored = stored.isNotEmpty;
      _status = stored.isNotEmpty
          ? l10n.t('settingsMistralKeySaved')
          : l10n.t('settingsMistralKeyMissing');
      _statusError = null;
    });
  }

  Future<void> _openConsole() async {
    await launchUrl(
      MistralAiService.apiKeysConsoleUri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _saveKey() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _statusError = l10n.t('settingsMistralKeyInvalid'));
      return;
    }
    setState(() {
      _saving = true;
      _status = l10n.t('settingsMistralSaving');
      _statusError = null;
    });
    try {
      await MistralAiService.validateAndSaveApiKey(key);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _hasStored = true;
        _status = l10n.t('settingsMistralKeySaved');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _statusError = isMistralApiKeyMissingError(e)
            ? l10n.t('settingsMistralKeyInvalid')
            : '$e';
        _status = l10n.t('settingsMistralKeyMissing');
      });
    }
  }

  Future<void> _clearKey() async {
    await MistralAiService.saveApiKey('');
    if (!mounted) return;
    setState(() {
      _keyCtrl.clear();
      _hasStored = false;
      _status = l10n.t('settingsMistralKeyCleared');
      _statusError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: l10n,
      builder: (context, _) {
        final error = l10n.lastError;
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: Text(l10n.t('settings'))),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              LanguageDropdown(l10n: l10n),
              if (error != null) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.t('translationUnavailable'),
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.t('translationProblem'),
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: l10n.isTranslating
                      ? null
                      : () => l10n.setLanguage(
                            l10n.languageCode,
                            l10n.languageName,
                            force: true,
                          ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.t('retranslate')),
                ),
              ],
              const SizedBox(height: 28),
              Text(
                l10n.t('settingsMistralApiKey'),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.t('settingsMistralApiKeyHint'),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.t('settingsMistralStepsTitle'),
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Text(l10n.t('settingsMistralStep1'),
                  style: theme.textTheme.bodySmall),
              Text(l10n.t('settingsMistralStep2'),
                  style: theme.textTheme.bodySmall),
              Text(l10n.t('settingsMistralStep3'),
                  style: theme.textTheme.bodySmall),
              Text(l10n.t('settingsMistralStep4'),
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openConsole,
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.t('settingsMistralCreateKey')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _keyCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: l10n.t('settingsMistralApiKey'),
                  border: const OutlineInputBorder(),
                  errorText: _statusError,
                  suffixIcon: IconButton(
                    tooltip: _obscure
                        ? l10n.t('settingsShowKey')
                        : l10n.t('settingsHideKey'),
                    icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _saveKey(),
              ),
              const SizedBox(height: 8),
              if (_status != null)
                Text(
                  _status!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _hasStored
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton(
                    onPressed: _saving ? null : _saveKey,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.t('save')),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _saving || !_hasStored ? null : _clearKey,
                    child: Text(l10n.t('clear')),
                  ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: const EastmarkFooter(includeBottomSafeArea: true),
        );
      },
    );
  }
}
