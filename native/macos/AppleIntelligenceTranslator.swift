import Cocoa
import FlutterMacOS

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Optional native helper: uses Apple's on-device Foundation Models
/// framework ("Apple Intelligence") to translate the app's UI strings when
/// it's available on this Mac. Entirely best-effort — if Apple Intelligence
/// isn't available/enabled, or this file isn't wired in at all, the Dart
/// side (AppleIntelligenceChannel) falls back to Mistral automatically.
///
/// SETUP: copy this file into macos/Runner/ after running `flutter create`,
/// then in macos/Runner/AppDelegate.swift, inside
/// `applicationDidFinishLaunching` (after the FlutterViewController exists),
/// add:
///
///   AppleIntelligenceTranslator.register(with: flutterViewController)
///
/// (replace `flutterViewController` with however your AppDelegate refers to
/// the main FlutterViewController / window's contentViewController).
///
/// NOTE: the exact FoundationModels API (SystemLanguageModel,
/// LanguageModelSession, etc.) was introduced with Apple Intelligence and
/// may have evolved since this was written. If it doesn't compile against
/// your SDK, check Apple's current FoundationModels documentation and
/// adjust the two methods below — everything else in the app works fine
/// without this file.
final class AppleIntelligenceTranslator: NSObject {
  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.eastmarkhk.snowball/apple_intelligence",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isAvailable":
        result(isAvailable())
      case "translate":
        guard
          let args = call.arguments as? [String: Any],
          let targetLanguage = args["targetLanguage"] as? String,
          let strings = args["strings"] as? [String: String]
        else {
          result(nil)
          return
        }
        Task {
          let translated = await translate(strings: strings, targetLanguage: targetLanguage)
          result(translated)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  static func isAvailable() -> Bool {
    #if canImport(FoundationModels)
    if #available(macOS 15.1, *) {
      return SystemLanguageModel.default.availability == .available
    }
    #endif
    return false
  }

  static func translate(strings: [String: String], targetLanguage: String) async -> [String: String]? {
    #if canImport(FoundationModels)
    guard #available(macOS 15.1, *), isAvailable() else { return nil }
    do {
      let session = LanguageModelSession()
      let keys = Array(strings.keys)
      let jsonInput = try JSONSerialization.data(withJSONObject: strings)
      let jsonString = String(data: jsonInput, encoding: .utf8) ?? "{}"
      let prompt = """
      Translate every value in this JSON object into \(targetLanguage). \
      Keep the keys exactly the same. Return ONLY a valid JSON object, no \
      commentary, no markdown fences.

      \(jsonString)
      """
      let response = try await session.respond(to: prompt)
      guard
        let data = response.content.data(using: .utf8),
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: String]
      else {
        return nil
      }
      // Sanity check: same key set as what we asked for.
      guard Set(decoded.keys) == Set(keys) else { return nil }
      return decoded
    } catch {
      return nil
    }
    #else
    return nil
    #endif
  }
}
