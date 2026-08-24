import Flutter
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device Apple Intelligence (Foundation Models, iOS 26+) for UI-string
/// translation. Nothing is sent to a server. If the model is unavailable
/// (older iOS, device not eligible, or Apple Intelligence off), Dart falls
/// back to Apple Translation, then Mistral.
class AppleIntelligenceHandler: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.eastmarkhk.snowball/apple_intelligence",
      binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(AppleIntelligenceHandler(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(Self.isAvailable())

    case "translate":
      guard let args = call.arguments as? [String: Any],
            let targetLanguage = args["targetLanguage"] as? String,
            let strings = args["strings"] as? [String: String]
      else {
        result(nil)
        return
      }
      Task {
        let translated = await Self.translate(
          strings: strings, targetLanguage: targetLanguage)
        await MainActor.run { result(translated) }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func isAvailable() -> Bool {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      return SystemLanguageModel.default.availability == .available
    }
    #endif
    return false
  }

  static func translate(
    strings: [String: String], targetLanguage: String
  ) async -> [String: String]? {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      guard isAvailable() else { return nil }
      do {
        let keys = Array(strings.keys)
        let jsonInput = try JSONSerialization.data(withJSONObject: strings)
        let jsonString = String(data: jsonInput, encoding: .utf8) ?? "{}"
        let model = SystemLanguageModel(
          guardrails: .permissiveContentTransformations)
        let session = LanguageModelSession(
          model: model,
          instructions: """
            You translate short UI strings for a finance calculator. \
            Return only a JSON object. Keep every key unchanged. \
            Translate each value into \(targetLanguage). \
            No markdown fences, no commentary.
            """
        )
        let response = try await session.respond(to: jsonString)
        return parseJsonMap(response.content, expectedKeys: keys)
      } catch {
        return nil
      }
    }
    #endif
    return nil
  }

  static func parseJsonMap(_ raw: String, expectedKeys: [String]) -> [String: String]? {
    var content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if content.hasPrefix("```") {
      content = content.replacingOccurrences(
        of: #"^```(?:json)?\s*"#, with: "", options: .regularExpression)
      content = content.replacingOccurrences(
        of: #"\s*```$"#, with: "", options: .regularExpression)
    }
    guard let data = content.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }
    var decoded: [String: String] = [:]
    for (key, value) in object {
      decoded[key] = String(describing: value)
    }
    guard Set(decoded.keys) == Set(expectedKeys) else { return nil }
    return decoded
  }
}
