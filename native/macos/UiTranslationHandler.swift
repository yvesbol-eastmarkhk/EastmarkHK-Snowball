import FlutterMacOS
import Foundation
#if canImport(Translation)
import Translation
#endif
#if canImport(SwiftUI)
import SwiftUI
import AppKit
#endif

/// Bridge to Apple's Translation framework (macOS 15+) for the on-demand
/// UI packs. If Translation is unavailable, the Dart side falls back to
/// Mistral. Ported from the EastmarkHK e-Invoicing app's UiTranslationHandler.
class UiTranslationHandler: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.eastmarkhk.snowball/ui_translation",
      binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(UiTranslationHandler(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      guard let args = call.arguments as? [String: Any],
            let source = args["source"] as? String,
            let target = args["target"] as? String
      else {
        result(false)
        return
      }
      Task {
        let ok = await Self.checkAvailable(source: source, target: target)
        result(ok)
      }

    case "translateBatch":
      guard let args = call.arguments as? [String: Any],
            let source = args["source"] as? String,
            let target = args["target"] as? String,
            let ids = args["ids"] as? [String],
            let texts = args["texts"] as? [String],
            ids.count == texts.count
      else {
        result(FlutterError(code: "bad_args", message: "ids/texts mismatch", details: nil))
        return
      }
      Task {
        do {
          let map = try await Self.translateBatch(
            source: source, target: target, ids: ids, texts: texts)
          result(map)
        } catch {
          NSLog("UiTranslation translateBatch error: %@", error.localizedDescription)
          result(FlutterError(
            code: "translate_failed",
            message: error.localizedDescription,
            details: nil))
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func normalizeLang(_ code: String) -> String {
    code.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "_", with: "-")
  }

  static func checkAvailable(source: String, target: String) async -> Bool {
#if canImport(Translation)
    if #available(macOS 15.0, *) {
      return await Self._checkAvailable15(source: source, target: target)
    }
#endif
    return false
  }

  static func translateBatch(
    source: String,
    target: String,
    ids: [String],
    texts: [String]
  ) async throws -> [String: String] {
#if canImport(Translation)
    if #available(macOS 15.0, *) {
      return try await Self._translateBatch15(
        source: source, target: target, ids: ids, texts: texts)
    }
#endif
    throw NSError(
      domain: "UiTranslation",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Apple Translation unavailable"])
  }
}

#if canImport(Translation)
@available(macOS 15.0, *)
extension UiTranslationHandler {
  static func languageCandidates(_ code: String) -> [Locale.Language] {
    let n = normalizeLang(code)
    var ids = [n]
    let base = n.split(separator: "-").first.map(String.init) ?? n
    if base != n { ids.append(base) }
    let regionHints: [String: String] = [
      "en": "en-US", "fr": "fr-FR", "de": "de-DE", "es": "es-ES", "it": "it-IT",
      "nl": "nl-NL", "pt": "pt-PT", "zh": "zh-Hans", "zh-HK": "zh-Hant-HK",
      "zh-TW": "zh-Hant-TW", "ja": "ja-JP", "ko": "ko-KR", "ar": "ar-SA",
      "ru": "ru-RU", "pl": "pl-PL", "tr": "tr-TR", "vi": "vi-VN", "th": "th-TH",
      "id": "id-ID", "sv": "sv-SE", "da": "da-DK", "fi": "fi-FI", "el": "el-GR",
      "nb": "nb-NO", "uk": "uk-UA", "he": "he-IL", "hi": "hi-IN",
    ]
    if let hint = regionHints[n] ?? regionHints[base] {
      ids.append(hint)
    }
    var seen = Set<String>()
    return ids.compactMap { id in
      let k = id.lowercased()
      if seen.contains(k) { return nil }
      seen.insert(k)
      return Locale.Language(identifier: id)
    }
  }

  static func _checkAvailable15(source: String, target: String) async -> Bool {
    let availability = LanguageAvailability()
    for from in languageCandidates(source) {
      for to in languageCandidates(target) {
        let status = await availability.status(from: from, to: to)
        switch status {
        case .installed, .supported:
          return true
        default:
          break
        }
      }
    }
    return true
  }

  static func _translateBatch15(
    source: String,
    target: String,
    ids: [String],
    texts: [String]
  ) async throws -> [String: String] {
    let availability = LanguageAvailability()
    var bestFrom = languageCandidates(source).first!
    var bestTo = languageCandidates(target).first!
    var bestStatus = LanguageAvailability.Status.unsupported

    for from in languageCandidates(source) {
      for to in languageCandidates(target) {
        let status = await availability.status(from: from, to: to)
        if status == .installed {
          bestFrom = from
          bestTo = to
          bestStatus = status
          break
        }
        if status == .supported && bestStatus != .installed {
          bestFrom = from
          bestTo = to
          bestStatus = status
        }
      }
      if bestStatus == .installed { break }
    }

    if bestStatus == .installed {
      if #available(macOS 26.0, *) {
        do {
          let session = TranslationSession(installedSource: bestFrom, target: bestTo)
          return try await runSession(session, ids: ids, texts: texts)
        } catch {
          NSLog("UiTranslation installed session failed: %@", error.localizedDescription)
        }
      }
    }

#if canImport(SwiftUI)
    return try await translateViaSwiftUIBridge(
      source: normalizeLang(source), target: normalizeLang(target), ids: ids, texts: texts)
#else
    throw NSError(
      domain: "UiTranslation", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Apple Translation SwiftUI unavailable"])
#endif
  }

  static func runSession(
    _ session: TranslationSession,
    ids: [String],
    texts: [String]
  ) async throws -> [String: String] {
    let requests = zip(ids, texts).map { id, text in
      TranslationSession.Request(sourceText: text, clientIdentifier: id)
    }
    let responses = try await session.translations(from: requests)
    var map: [String: String] = [:]
    for (i, response) in responses.enumerated() {
      let key = response.clientIdentifier ?? (i < ids.count ? ids[i] : "\(i)")
      map[key] = response.targetText
    }
    return map
  }
}
#endif

#if canImport(Translation) && canImport(SwiftUI)
@available(macOS 15.0, *)
enum TranslationBridgeRegistry {
  static var active: [UUID: TranslationBridgeHost] = [:]
}

@available(macOS 15.0, *)
final class TranslationBridgeHost {
  private let source: String
  private let target: String
  private let ids: [String]
  private let texts: [String]
  private let completion: (Result<[String: String], Error>) -> Void
  private var panel: NSPanel?
  private var finished = false
  private let id = UUID()

  init(
    source: String, target: String, ids: [String], texts: [String],
    completion: @escaping (Result<[String: String], Error>) -> Void
  ) {
    self.source = source
    self.target = target
    self.ids = ids
    self.texts = texts
    self.completion = completion
  }

  func start() {
    TranslationBridgeRegistry.active[id] = self

    let root = TranslationBridgeView(
      source: source, target: target, ids: ids, texts: texts,
      onDone: { [weak self] result in self?.finish(result) }
    )
    let hosting = NSHostingController(rootView: root)
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 32, height: 32),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false)
    panel.isFloatingPanel = true
    panel.alphaValue = 0.02
    panel.level = .floating
    panel.contentViewController = hosting
    if let main = NSApp.mainWindow ?? NSApp.windows.first {
      panel.setFrameOrigin(NSPoint(x: main.frame.minX + 4, y: main.frame.minY + 4))
    }
    panel.orderFrontRegardless()
    self.panel = panel

    DispatchQueue.main.asyncAfter(deadline: .now() + 90) { [weak self] in
      self?.finish(.failure(NSError(
        domain: "UiTranslation", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Apple Translation timeout"])))
    }
  }

  private func finish(_ result: Result<[String: String], Error>) {
    guard !finished else { return }
    finished = true
    panel?.orderOut(nil)
    panel = nil
    TranslationBridgeRegistry.active.removeValue(forKey: id)
    completion(result)
  }
}

@available(macOS 15.0, *)
extension UiTranslationHandler {
  static func translateViaSwiftUIBridge(
    source: String, target: String, ids: [String], texts: [String]
  ) async throws -> [String: String] {
    try await withCheckedThrowingContinuation { cont in
      DispatchQueue.main.async {
        let host = TranslationBridgeHost(
          source: source, target: target, ids: ids, texts: texts
        ) { result in cont.resume(with: result) }
        host.start()
      }
    }
  }
}

@available(macOS 15.0, *)
struct TranslationBridgeView: View {
  let source: String
  let target: String
  let ids: [String]
  let texts: [String]
  let onDone: (Result<[String: String], Error>) -> Void

  @State private var configuration: TranslationSession.Configuration?
  @State private var started = false

  var body: some View {
    Color.clear
      .frame(width: 8, height: 8)
      .translationTask(configuration) { session in
        guard !started else { return }
        started = true
        Task {
          do {
            let map = try await UiTranslationHandler.runSession(session, ids: ids, texts: texts)
            onDone(.success(map))
          } catch {
            onDone(.failure(error))
          }
        }
      }
      .onAppear {
        configuration = TranslationSession.Configuration(
          source: Locale.Language(identifier: source),
          target: Locale.Language(identifier: target)
        )
      }
  }
}
#endif
