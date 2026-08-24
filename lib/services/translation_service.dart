import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import 'apple_intelligence_channel.dart';

enum TranslationEngine { appleIntelligence, mistral }

class TranslationResult {
  final Map<String, String> strings;
  final TranslationEngine engine;
  const TranslationResult(this.strings, this.engine);
}

/// Translates the app's UI strings using on-device Apple Intelligence when
/// it's available (macOS/iOS), falling back to the Mistral API everywhere
/// else (Windows, Android, or an Apple device without Apple Intelligence).
///
/// This is only ever called once per language — L10nController caches the
/// result — so AI usage stays minimal, as intended.
class TranslationService {
  Future<TranslationResult> translate({
    required Map<String, String> source,
    required String targetLanguageName,
  }) async {
    if (!kIsWeb && (Platform.isMacOS || Platform.isIOS)) {
      try {
        final available = await AppleIntelligenceChannel.isAvailable();
        if (available) {
          final translated = await AppleIntelligenceChannel.translate(
            source: source,
            targetLanguageName: targetLanguageName,
          );
          if (translated != null && translated.length == source.length) {
            return TranslationResult(
                translated, TranslationEngine.appleIntelligence);
          }
        }
      } catch (_) {
        // Fall through to Mistral below.
      }
    }

    final translated = await _translateWithMistral(source, targetLanguageName);
    return TranslationResult(translated, TranslationEngine.mistral);
  }

  Future<Map<String, String>> _translateWithMistral(
    Map<String, String> source,
    String targetLanguageName,
  ) async {
    final uri = Uri.parse('https://api.mistral.ai/v1/chat/completions');

    final prompt = '''
Translate every value in this JSON object into $targetLanguageName. Keep the
keys exactly as they are — only translate the values. This is UI text for a
compound-interest calculator finance app, so keep translations short and
natural for buttons, labels, and form fields. Return ONLY a valid JSON
object with the same keys, no markdown fences, no commentary.

${jsonEncode(source)}
''';

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $mistralApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'mistral-small-latest',
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.1,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Mistral translation failed: ${response.statusCode} ${response.body}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final content = body['choices'][0]['message']['content'] as String;
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v.toString()));
  }
}
