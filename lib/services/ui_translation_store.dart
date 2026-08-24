import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_strings.dart';

/// On-demand UI packs, one JSON file per language: `…/ui_l10n/{code}.json`
/// (key → translated string). English always comes from [AppStrings.en] —
/// never written to disk. Ported from the same system used in the
/// EastmarkHK e-Invoicing app (UiTranslationStore).
class UiTranslationStore {
  UiTranslationStore._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static String codeOf(Locale locale) {
    final c = locale.countryCode;
    if (c == null || c.isEmpty) return locale.languageCode;
    return '${locale.languageCode}_$c';
  }

  static Future<Directory> _dir() async {
    final support = await getApplicationSupportDirectory();
    final d = Directory(p.join(support.path, 'ui_l10n'));
    await d.create(recursive: true);
    return d;
  }

  static Future<File> _file(String code) async {
    final safe = code.trim().replaceAll('-', '_');
    return File(p.join((await _dir()).path, '$safe.json'));
  }

  static bool isEnglish(String code) {
    final c = code.trim().toLowerCase().replaceAll('-', '_');
    return c == 'en' || c.startsWith('en_');
  }

  /// Pack ready: English always is; otherwise a file with (almost) all the
  /// current English keys — forces a re-translation if AppStrings.en has
  /// grown since the pack was last generated.
  static Future<bool> hasReadyPack(String code) async {
    if (isEnglish(code)) return true;
    final pack = await load(code);
    if (pack == null || pack.isEmpty) return false;
    final minCount = (AppStrings.en.length * 0.8).floor();
    return pack.length >= minCount;
  }

  static Future<Map<String, String>?> load(String code) async {
    if (isEnglish(code)) return Map<String, String>.from(AppStrings.en);
    final candidates = <String>{
      code.trim().replaceAll('-', '_'),
      code.trim().split('_').first,
    };
    for (final c in candidates) {
      if (c.isEmpty) continue;
      try {
        final f = await _file(c);
        if (!await f.exists()) continue;
        final decoded = jsonDecode(await f.readAsString());
        if (decoded is! Map) continue;
        final out = <String, String>{};
        decoded.forEach((k, v) {
          if (k is String && v is String && v.isNotEmpty) out[k] = v;
        });
        if (out.isNotEmpty) return out;
      } catch (_) {
        // Corrupt/unreadable pack — treat as missing.
      }
    }
    return null;
  }

  static Future<void> save(String code, Map<String, String> table) async {
    final f = await _file(code.replaceAll('-', '_'));
    final sorted = Map.fromEntries(
      table.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(sorted));
    revision.value++;
  }

  /// Clears the cached pack so it gets re-translated (e.g. to retry after a
  /// failed attempt, or to force a specific engine on the next pass).
  static Future<void> deletePack(String code) async {
    final f = await _file(code.replaceAll('-', '_'));
    if (await f.exists()) await f.delete();
    revision.value++;
  }
}
