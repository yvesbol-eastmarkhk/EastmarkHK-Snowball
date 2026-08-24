import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/secrets.dart';

/// Minimal Mistral client for Snowball — UI-string translation only.
/// The customer key is stored on this device (Application Support).
/// A compile-time dart-define is only a developer fallback.
class MistralAiService {
  MistralAiService._();

  /// Opens the Mistral console on the API-keys dialog (create / copy a key).
  static final Uri apiKeysConsoleUri = Uri.parse(
    'https://console.mistral.ai/?profile_dialog=api-keys',
  );

  static const _fallbackFileName = '.mistral_secret';
  static const _endpoint = 'https://api.mistral.ai/v1/chat/completions';
  static const _model = 'mistral-small-latest';

  /// Key saved on this device, or the optional compile-time fallback.
  static Future<String> loadApiKey() async {
    final stored = await loadStoredApiKey();
    if (stored.isNotEmpty) return stored;
    return compileTimeMistralApiKey.trim();
  }

  /// Key the customer pasted in Settings — never the dart-define.
  static Future<String> loadStoredApiKey() async => _readFallback();

  static Future<bool> hasStoredApiKey() async {
    return (await loadStoredApiKey()).isNotEmpty;
  }

  static void _assertPlausibleApiKey(String v) {
    if (v.contains(RegExp(r'\s')) || v.runes.any((r) => r > 127)) {
      throw Exception('Invalid Mistral API key');
    }
  }

  static Future<void> saveApiKey(String key) async {
    final v = key.trim();
    if (v.isEmpty) {
      await _deleteFallback();
      return;
    }
    _assertPlausibleApiKey(v);
    await _writeFallback(v);
  }

  /// Checks the key against Mistral before saving it.
  static Future<void> validateAndSaveApiKey(String key) async {
    final v = key.trim();
    _assertPlausibleApiKey(v);
    final response = await http
        .get(
          Uri.parse('https://api.mistral.ai/v1/models'),
          headers: {'Authorization': 'Bearer $v'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Invalid Mistral API key');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Mistral error ${response.statusCode}: ${response.body}');
    }
    await saveApiKey(v);
  }

  static Future<File> _fallbackFile() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File(p.join(dir.path, _fallbackFileName));
  }

  static Future<void> _writeFallback(String key) async {
    final file = await _fallbackFile();
    await file.writeAsString(base64Encode(utf8.encode(key)), flush: true);
  }

  static Future<String> _readFallback() async {
    try {
      final file = await _fallbackFile();
      if (!await file.exists()) return '';
      final raw = (await file.readAsString()).trim();
      if (raw.isEmpty) return '';
      return utf8.decode(base64Decode(raw));
    } catch (e) {
      debugPrint('MistralAiService stored-key read failed: $e');
      return '';
    }
  }

  static Future<void> _deleteFallback() async {
    try {
      final file = await _fallbackFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Translates a batch of UI strings (key → English text) into
  /// [targetLanguageName]. Markers like `⟦Tn⟧` and `{placeholders}` must
  /// come back unchanged — the caller protects/restores them.
  static Future<Map<String, String>> translateUiJsonMap({
    required Map<String, String> entries,
    required String targetLanguageName,
    required String targetLocaleCode,
  }) async {
    final apiKey = await loadApiKey();
    if (apiKey.isEmpty) {
      throw Exception('Mistral API key missing');
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
      apiKey: apiKey,
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
    required String apiKey,
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
            'Authorization': 'Bearer $apiKey',
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

bool isMistralApiKeyMissingError(Object error) {
  final s = '$error'.toLowerCase();
  return s.contains('mistral api key missing') ||
      s.contains('api key missing') ||
      s.contains('invalid mistral api key') ||
      s.contains('invalid http header') ||
      (s.contains('formatexception') && s.contains('bearer'));
}
