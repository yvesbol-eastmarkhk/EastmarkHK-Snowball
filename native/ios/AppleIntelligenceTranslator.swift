import Flutter
import UIKit

#if canImport(FoundationModels)
import FoundationModels
#endif

/// iOS counterpart of macos/AppleIntelligenceTranslator.swift — see that
/// file for the full explanation. Same best-effort caveat applies.
///
/// SETUP: copy into ios/Runner/ after `flutter create`, then in
/// ios/Runner/AppDelegate.swift, inside `application(_:didFinishLaunchingWithOptions:)`
/// (after the FlutterViewController is created), add:
///
///   if let controller = window?.rootViewController as? FlutterViewController {
///     AppleIntelligenceTranslator.register(with: controller)
///   }
final class AppleIntelligenceTranslator: NSObject {
  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.eastmarkhk.snowball/apple_intelligence",
      binaryMessenger: controller.binaryMessenger
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
    if #available(iOS 18.1, *) {
      return SystemLanguageModel.default.availability == .available
    }
    #endif
    return false
  }

  static func translate(strings: [String: String], targetLanguage: String) async -> [String: String]? {
    #if canImport(FoundationModels)
    guard #available(iOS 18.1, *), isAvailable() else { return nil }
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
