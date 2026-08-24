import 'package:flutter/material.dart';

import '../l10n/l10n_controller.dart';
import '../widgets/eastmark_footer.dart';
import '../widgets/language_dropdown.dart';

class SettingsScreen extends StatelessWidget {
  final L10nController l10n;
  const SettingsScreen({super.key, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: l10n,
      builder: (context, _) {
        final error = l10n.lastError;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.t('settings'))),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LanguageDropdown(l10n: l10n),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.t('translationUnavailable'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.t('translationProblem'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    error,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
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
              ],
            ),
          ),
          bottomNavigationBar: const EastmarkFooter(includeBottomSafeArea: true),
        );
      },
    );
  }
}
