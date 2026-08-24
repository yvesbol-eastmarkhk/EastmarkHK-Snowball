import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let appleIntelligenceRegistrar =
        engineBridge.pluginRegistry.registrar(forPlugin: "AppleIntelligenceHandler") {
      AppleIntelligenceHandler.register(with: appleIntelligenceRegistrar)
    }
    if let uiTranslationRegistrar =
        engineBridge.pluginRegistry.registrar(forPlugin: "UiTranslationHandler") {
      UiTranslationHandler.register(with: uiTranslationRegistrar)
    }
  }
}
