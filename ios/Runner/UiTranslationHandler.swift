import Flutter
import Foundation
#if canImport(Translation)
import Translation
#endif
#if canImport(SwiftUI)
import SwiftUI
import UIKit
#endif

/// iOS counterpart of macos/UiTranslationHandler.swift — see that file's
/// header comment. Ported from the EastmarkHK e-Invoicing app.
class UiTranslationHandler: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.eastmarkhk.snowball/ui_translation",
      binaryMessenger: registrar.messenger())
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
        await MainActor.run { result(ok) }
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
          await MainActor.run { result(map) }
        } catch {
          await MainActor.run {
            result(FlutterError(
              code: "translate_failed",
              message: error.localizedDescription,
              details: nil))
          }
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

  static func languageCandidates(_ code: String) -> [String] {
    let n = normalizeLang(code)
    var ids = [n]
    let base = n.split(separator: "-").first.map(String.init) ?? n
    if base != n { ids.append(base) }
    let regionHints: [String: String] = [
      "en": "en-US", "fr": "fr-FR", "de": "de-DE", "es": "es-ES", "it": "it-IT",
      "nl": "nl-NL", "pt": "pt-BR", "pt-BR": "pt-BR", "pt-PT": "pt-PT",
      "zh": "zh-Hans", "ja": "ja-JP", "ko": "ko-KR",
    ]
    if let hint = regionHints[n] ?? regionHints[base] {
      ids.append(hint)
    }
    var seen = Set<String>()
    return ids.filter { seen.insert($0.lowercased()).inserted }
  }

  static func checkAvailable(source: String, target: String) async -> Bool {
#if canImport(Translation)
    if #available(iOS 18.0, *) {
      let availability = LanguageAvailability()
      for fromId in languageCandidates(source) {
        for toId in languageCandidates(target) {
          let status = await availability.status(
            from: Locale.Language(identifier: fromId),
            to: Locale.Language(identifier: toId)
          )
          switch status {
          case .installed, .supported:
            return true
          default:
            break
          }
        }
      }
      // Same as macOS: still try. The SwiftUI session can download the pack.
      return true
    }
#endif
    return false
  }

  static func translateBatch(
    source: String, target: String, ids: [String], texts: [String]
  ) async throws -> [String: String] {
#if canImport(Translation)
    if #available(iOS 18.0, *) {
      return try await Self.translateBatch18(
        source: source, target: target, ids: ids, texts: texts)
    }
#endif
    throw NSError(
      domain: "UiTranslation", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Apple Translation unavailable"])
  }

#if canImport(Translation)
  @available(iOS 18.0, *)
  static func translateBatch18(
    source: String, target: String, ids: [String], texts: [String]
  ) async throws -> [String: String] {
    let availability = LanguageAvailability()
    var bestFrom = languageCandidates(source).first ?? source
    var bestTo = languageCandidates(target).first ?? target
    var installed = false
    for fromId in languageCandidates(source) {
      for toId in languageCandidates(target) {
        let status = await availability.status(
          from: Locale.Language(identifier: fromId),
          to: Locale.Language(identifier: toId)
        )
        if status == .installed {
          bestFrom = fromId
          bestTo = toId
          installed = true
          break
        }
        if status == .supported && !installed {
          bestFrom = fromId
          bestTo = toId
        }
      }
      if installed { break }
    }

    if installed {
      if #available(iOS 26.0, *) {
        do {
          let session = TranslationSession(
            installedSource: Locale.Language(identifier: bestFrom),
            target: Locale.Language(identifier: bestTo)
          )
          return try await runSession(session, ids: ids, texts: texts)
        } catch {
          // Fall through to the SwiftUI session, which can prompt a download.
        }
      }
    }

#if canImport(SwiftUI)
    return try await withCheckedThrowingContinuation { cont in
      DispatchQueue.main.async {
        TranslationBridgeHost(
          source: bestFrom, target: bestTo, ids: ids, texts: texts
        ) { result in cont.resume(with: result) }.start()
      }
    }
#else
    throw NSError(
      domain: "UiTranslation", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Apple Translation SwiftUI unavailable"])
#endif
  }

  @available(iOS 18.0, *)
  static func runSession(
    _ session: TranslationSession, ids: [String], texts: [String]
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
#endif
}

#if canImport(Translation) && canImport(SwiftUI)
@available(iOS 18.0, *)
final class TranslationBridgeHost {
  private let source: String
  private let target: String
  private let ids: [String]
  private let texts: [String]
  private let completion: (Result<[String: String], Error>) -> Void
  private var host: UIViewController?
  private var finished = false

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
    let root = TranslationBridgeView(
      source: source, target: target, ids: ids, texts: texts,
      onDone: { [weak self] result in self?.finish(result) }
    )
    let hosting = UIHostingController(rootView: root)
    hosting.view.backgroundColor = .clear
    hosting.view.isOpaque = false
    hosting.view.isUserInteractionEnabled = true
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let rootVC = scene.windows.first?.rootViewController {
      rootVC.addChild(hosting)
      hosting.view.frame = rootVC.view.bounds
      hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      rootVC.view.addSubview(hosting.view)
      hosting.didMove(toParent: rootVC)
      host = hosting
    } else {
      finish(.failure(NSError(
        domain: "UiTranslation", code: 3,
        userInfo: [NSLocalizedDescriptionKey: "No root view controller"])))
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
      self?.finish(.failure(NSError(
        domain: "UiTranslation", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Apple Translation timeout"])))
    }
  }

  private func finish(_ result: Result<[String: String], Error>) {
    guard !finished else { return }
    finished = true
    host?.willMove(toParent: nil)
    host?.view.removeFromSuperview()
    host?.removeFromParent()
    host = nil
    completion(result)
  }
}

@available(iOS 18.0, *)
struct TranslationBridgeView: View {
  let source: String
  let target: String
  let ids: [String]
  let texts: [String]
  let onDone: (Result<[String: String], Error>) -> Void

  @State private var configuration: TranslationSession.Configuration?

  var body: some View {
    Color.clear
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
      .translationTask(configuration) { session in
        Task {
          do {
            let requests = zip(ids, texts).map { id, text in
              TranslationSession.Request(sourceText: text, clientIdentifier: id)
            }
            let responses = try await session.translations(from: requests)
            var map: [String: String] = [:]
            for (i, response) in responses.enumerated() {
              let key = response.clientIdentifier ?? (i < ids.count ? ids[i] : "\(i)")
              map[key] = response.targetText
            }
            onDone(.success(map))
          } catch {
            onDone(.failure(error))
          }
        }
      }
      .onAppear {
        let from = UiTranslationHandler.languageCandidates(source).first ?? source
        let to = UiTranslationHandler.languageCandidates(target).first ?? target
        configuration = TranslationSession.Configuration(
          source: Locale.Language(identifier: from),
          target: Locale.Language(identifier: to)
        )
      }
  }
}
#endif
