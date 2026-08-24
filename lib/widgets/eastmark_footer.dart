import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/eastmark_brand.dart';

/// Fixed, minimal-height footer: © year + EastmarkHK, tap to open the
/// company site. Ported from the EastmarkHK e-Invoicing app so every
/// EastmarkHK app shares the same footer, just re-themed to this app's own
/// color scheme instead of a hardcoded palette.
class EastmarkFooter extends StatelessWidget {
  const EastmarkFooter({
    super.key,
    this.includeBottomSafeArea = false,
  });

  /// Only turn this on if the footer is the very last thing on the screen
  /// (e.g. a single-screen app like this one). Leave false above a nav bar.
  final bool includeBottomSafeArea;

  static const double contentHeight = 26;

  Future<void> _openSite() async {
    final uri = Uri.parse(EastmarkBrand.websiteUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final year = DateTime.now().year;
    final bottomInset =
        includeBottomSafeArea ? MediaQuery.paddingOf(context).bottom : 0.0;

    return Material(
      color: scheme.surface,
      elevation: 0,
      child: SizedBox(
        width: double.infinity,
        height: contentHeight + bottomInset,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border:
                  Border(top: BorderSide(color: scheme.outlineVariant, width: 0.5)),
            ),
            child: Center(
              // Tap only on the text, not the whole width, so it doesn't
              // steal taps from neighboring widgets.
              child: InkWell(
                onTap: _openSite,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '© $year ',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1,
                            color: scheme.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                        TextSpan(
                          text: EastmarkBrand.companyName,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1,
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
