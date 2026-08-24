import 'package:flutter/services.dart';

/// Bridges to a small native Swift helper (macOS/iOS only, see
/// native/macos and native/ios in the project root) that uses Apple's
/// on-device Foundation Models framework ("Apple Intelligence") to
/// translate the app's UI strings, when the framework and a compatible,
/// enabled device are available.
///
/// The native side is optional: if it hasn't been wired into the Xcode
/// project, or Apple Intelligence isn't available/enabled on this Mac or
/// iPhone, both methods fail safely and TranslationService falls back to
/// Mistral automatically. Nothing here ever throws out to the caller.
class AppleIntelligenceChannel {
  static const _channel =
      MethodChannel('com.eastmarkhk.snowball/apple_intelligence');

  static Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Returns the translated map, or null if Apple Intelligence couldn't do
  /// it (not available, native side missing, or any other failure).
  static Future<Map<String, String>?> translate({
    required Map<String, String> source,
    required String targetLanguageName,
  }) async {
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('translate', {
        'targetLanguage': targetLanguageName,
        'strings': source,
      });
      if (result == null) return null;
      return result.map((k, v) => MapEntry(k, v.toString()));
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
