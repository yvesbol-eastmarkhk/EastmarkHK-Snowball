import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/secrets.dart';

/// Minimal Mistral client for Snowball — just UI-string translation, no
/// invoice/email features. Same request shape and system-prompt style as
/// the EastmarkHK e-Invoicing app's MistralAiService.translateUiJsonMap.
class MistralAiService {
  MistralAiService._();

  static const _endpoint = 'https://api.mistral.ai/v1/chat/completions';
  static const _model = 'mistral-small-latest';

  /// Translates a batch of UI strings (key → English text) into
  /// [targetLanguageName]. Markers like `⟦Tn⟧` and `{placeholders}` must
  /// come back unchanged — the caller protects/restores them.
  static Future<Map<String, String>> translateUiJsonMap({
    required Map<String, String> entries,
    required String targetLanguageName,
    required String targetLocaleCode,
  }) async {
    if (mistralApiKey.isEmpty) {
      throw Exception(
        'Mistral API key missing. Pass --dart-define=MISTRAL_API_KEY=... '
        'or --dart-define-from-file=dart_defines.json',
      );
    }

    final system = '''
You are a professional UI localizer for a personal finance app.
Translate each JSON string value from English to $targetLanguageName (locale $targetLocaleCode).
Rules:
- Return ONE JSON object only: same keys as the input, values translated.
- Keep placeholders like {name}, {count}, {amount} exactly as-is.
- Keep markers like ⟦T0⟧, ⟦T1⟧ exactly as-is (do not translate or alter them).
- Keep the brand name EastmarkHK unchanged.
- Do not add explanations or markdown.
''';

    final raw = await _chat(
      system: system,
      userContent: jsonEncode(entries),
      temperature: 0.1,
      timeout: const Duration(seconds: 120),
    );

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw Exception('Mistral UI translation: expected a JSON object.');
    }
    final out = <String, String>{};
    decoded.forEach((k, v) {
      if (k is String && v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) out[k] = s;
      }
    });
    return out;
  }

  static Future<String> _chat({
    required String system,
    required String userContent,
    required double temperature,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final body = <String, Object?>{
      'model': _model,
      'temperature': temperature,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': userContent},
      ],
    };

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $mistralApiKey',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Mistral error ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final choices = decoded is Map ? decoded['choices'] : null;
    if (choices is! List || choices.isEmpty) {
      throw Exception('Mistral returned no choices.');
    }
    final message = choices.first is Map ? choices.first['message'] : null;
    final content = message is Map ? message['content'] : null;
    final text = (content is String ? content : '$content').trim();
    if (text.isEmpty) {
      throw Exception('Mistral returned empty text.');
    }
    return text;
  }
}
