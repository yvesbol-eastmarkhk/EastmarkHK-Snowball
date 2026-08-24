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
        result(await Self.checkAvailable(source: source, target: target))
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
          result(try await Self.translateBatch(
            source: source, target: target, ids: ids, texts: texts))
        } catch {
          result(FlutterError(
            code: "translate_failed", message: error.localizedDescription, details: nil))
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func checkAvailable(source: String, target: String) async -> Bool {
#if canImport(Translation)
    if #available(iOS 18.0, *) {
      let availability = LanguageAvailability()
      let from = Locale.Language(identifier: source.replacingOccurrences(of: "_", with: "-"))
      let to = Locale.Language(identifier: target.replacingOccurrences(of: "_", with: "-"))
      let status = await availability.status(from: from, to: to)
      switch status {
      case .installed, .supported:
        return true
      default:
        return false
      }
    }
#endif
    return false
  }

  static func translateBatch(
    source: String, target: String, ids: [String], texts: [String]
  ) async throws -> [String: String] {
#if canImport(Translation) && canImport(SwiftUI)
    if #available(iOS 18.0, *) {
      return try await withCheckedThrowingContinuation { cont in
        DispatchQueue.main.async {
          TranslationBridgeHost(
            source: source, target: target, ids: ids, texts: texts
          ) { result in cont.resume(with: result) }.start()
        }
      }
    }
#endif
    throw NSError(
      domain: "UiTranslation", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Apple Translation unavailable"])
  }
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
    hosting.view.alpha = 0.01
    hosting.view.isUserInteractionEnabled = false
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let rootVC = scene.windows.first?.rootViewController {
      rootVC.addChild(hosting)
      rootVC.view.addSubview(hosting.view)
      hosting.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
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
      .frame(width: 1, height: 1)
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
        configuration = TranslationSession.Configuration(
          source: Locale.Language(identifier: source.replacingOccurrences(of: "_", with: "-")),
          target: Locale.Language(identifier: target.replacingOccurrences(of: "_", with: "-"))
        )
      }
  }
}
#endif
