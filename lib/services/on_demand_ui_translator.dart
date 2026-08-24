import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import 'apple_intelligence_channel.dart';
import 'mistral_ai_service.dart';
import 'ui_translation_store.dart';

typedef UiTranslateProgress = void Function(int done, int total, String engine);

/// Translates the English UI catalog into a target language.
/// 1) Apple Intelligence (on-device Foundation Models), if enabled.
/// 2) Apple's on-device Translation framework, if available.
/// 3) Otherwise Mistral.
///
/// Ported from the same OnDemandUiTranslator used in the EastmarkHK
/// e-Invoicing app, trimmed down to just UI-string translation.
class OnDemandUiTranslator {
  OnDemandUiTranslator._();

  static const _channel = MethodChannel('com.eastmarkhk.snowball/ui_translation');
  static const _chunk = 40;

  /// Protects `{placeholder}` tokens during translation.
  static (String, List<String>) _protect(String input) {
    final tokens = <String>[];
    final out = input.replaceAllMapped(RegExp(r'\{[a-zA-Z_][a-zA-Z0-9_]*\}'), (m) {
      final i = tokens.length;
      tokens.add(m.group(0)!);
      return '⟦T$i⟧';
    });
    return (out, tokens);
  }

  static String _restore(String input, List<String> tokens) {
    var s = input;
    for (var i = 0; i < tokens.length; i++) {
      for (final marker in ['⟦T$i⟧', '<T$i>', '[T$i]', '(T$i)']) {
        s = s.replaceAll(marker, tokens[i]);
      }
    }
    return s;
  }

  static Future<bool> appleAvailable(String targetCode) async {
    if (kIsWeb || !(Platform.isMacOS || Platform.isIOS)) return false;
    final targets = <String>{
      targetCode.replaceAll('_', '-'),
      targetCode.split(RegExp(r'[_-]')).first,
    };
    for (final t in targets) {
      if (t.isEmpty) continue;
      try {
        final ok = await _channel.invokeMethod<bool>('isAvailable', {
          'source': 'en',
          'target': t,
        });
        if (ok == true) return true;
      } catch (_) {
        // Native side missing or unavailable — try next candidate / Mistral.
      }
    }
    return false;
  }

  static Future<Map<String, String>?> _translateAppleIntelligence({
    required String languageName,
    required UiTranslateProgress? onProgress,
  }) async {
    if (kIsWeb || !(Platform.isMacOS || Platform.isIOS)) return null;
    if (!await AppleIntelligenceChannel.isAvailable()) return null;

    final keys = AppStrings.en.keys.toList()..sort();
    final result = <String, String>{};
    onProgress?.call(0, keys.length, 'Apple Intelligence');

    for (var i = 0; i < keys.length; i += _chunk) {
      final chunk = keys.sublist(i, (i + _chunk).clamp(0, keys.length));
      final payload = <String, String>{};
      final tokensByKey = <String, List<String>>{};
      for (final k in chunk) {
        final (p, tokens) = _protect(AppStrings.en[k] ?? '');
        payload[k] = p;
        tokensByKey[k] = tokens;
      }
      final translated = await AppleIntelligenceChannel.translate(
        source: payload,
        targetLanguageName: languageName,
      );
      if (translated == null) return null;
      for (final k in chunk) {
        final t = translated[k];
        if (t != null && t.trim().isNotEmpty) {
          result[k] = _restore(t, tokensByKey[k] ?? const []);
        }
      }
      onProgress?.call(result.length, keys.length, 'Apple Intelligence');
    }

    if (result.length < (keys.length * 0.5).floor()) return null;

    for (final e in AppStrings.en.entries) {
      result.putIfAbsent(e.key, () => e.value);
    }
    return result;
  }

  static Future<Map<String, String>?> _translateApple({
    required String targetCode,
    required UiTranslateProgress? onProgress,
  }) async {
    final keys = AppStrings.en.keys.toList()..sort();
    final result = <String, String>{};
    onProgress?.call(0, keys.length, 'Apple Translation');

    final target = targetCode.replaceAll('_', '-');

    for (var i = 0; i < keys.length; i += _chunk) {
      final chunk = keys.sublist(i, (i + _chunk).clamp(0, keys.length));
      final protected = <String, List<String>>{};
      final texts = <String>[];
      final ids = <String>[];
      for (final k in chunk) {
        final (p, tokens) = _protect(AppStrings.en[k] ?? '');
        protected[k] = tokens;
        ids.add(k);
        texts.add(p);
      }
      try {
        final raw = await _channel.invokeMethod<dynamic>(
          'translateBatch',
          {'source': 'en', 'target': target, 'ids': ids, 'texts': texts},
        ).timeout(const Duration(seconds: 100));
        if (raw is! Map) return null;
        for (final k in chunk) {
          final t = raw[k];
          if (t is String && t.trim().isNotEmpty) {
            result[k] = _restore(t, protected[k] ?? const []);
          }
        }
      } catch (_) {
        return null;
      }
      onProgress?.call(result.length, keys.length, 'Apple Translation');
    }

    if (result.length < (keys.length * 0.5).floor()) return null;

    for (final e in AppStrings.en.entries) {
      result.putIfAbsent(e.key, () => e.value);
    }
    return result;
  }

  static Future<Map<String, String>> _translateMistral({
    required String targetCode,
    required String languageName,
    required UiTranslateProgress? onProgress,
  }) async {
    final keys = AppStrings.en.keys.toList()..sort();
    final result = <String, String>{};
    onProgress?.call(0, keys.length, 'Mistral AI');

    for (var i = 0; i < keys.length; i += _chunk) {
      final chunk = keys.sublist(i, (i + _chunk).clamp(0, keys.length));
      final payload = <String, String>{};
      final tokensByKey = <String, List<String>>{};
      for (final k in chunk) {
        final (p, tokens) = _protect(AppStrings.en[k] ?? '');
        payload[k] = p;
        tokensByKey[k] = tokens;
      }

      final translated = await MistralAiService.translateUiJsonMap(
        entries: payload,
        targetLanguageName: languageName,
        targetLocaleCode: targetCode,
      );
      for (final k in chunk) {
        final t = translated[k];
        result[k] = t != null && t.trim().isNotEmpty
            ? _restore(t, tokensByKey[k] ?? const [])
            : (AppStrings.en[k] ?? k);
      }
      onProgress?.call(result.length, keys.length, 'Mistral AI');
    }

    for (final e in AppStrings.en.entries) {
      result.putIfAbsent(e.key, () => e.value);
    }
    return result;
  }

  /// Ensures a translated pack exists on disk for [code] (e.g. `fr`,
  /// `pt_BR`). [force] ignores the cache and re-translates.
  static Future<void> ensurePack({
    required String code,
    required String languageName,
    UiTranslateProgress? onProgress,
    bool force = false,
  }) async {
    final normalized = code.trim().replaceAll('-', '_');
    if (UiTranslationStore.isEnglish(normalized)) return;

    if (force) {
      await UiTranslationStore.deletePack(normalized);
    } else if (await UiTranslationStore.hasReadyPack(normalized)) {
      return;
    }

    Map<String, String>? pack;
    Object? appleError;

    try {
      pack = await _translateAppleIntelligence(
        languageName: languageName,
        onProgress: onProgress,
      );
    } catch (e) {
      appleError = e;
      debugPrint('Apple Intelligence failed, trying Apple Translation: $e');
    }

    if (pack == null && await appleAvailable(normalized)) {
      onProgress?.call(0, 1, 'Apple Translation');
      try {
        pack = await _translateApple(
          targetCode: normalized,
          onProgress: onProgress,
        );
      } catch (e) {
        appleError ??= e;
        debugPrint('Apple Translation failed, falling back to Mistral: $e');
      }
    }

    if (pack == null) {
      try {
        pack = await _translateMistral(
          targetCode: normalized,
          languageName: languageName,
          onProgress: onProgress,
        );
      } catch (e) {
        final appleBit = appleError == null
            ? 'Apple Intelligence / Translation was not used on this device.'
            : 'Apple on-device translation failed: $appleError';
        throw Exception(
          '$appleBit Mistral fallback failed: $e',
        );
      }
    }

    await UiTranslationStore.save(normalized, pack);
  }
}
