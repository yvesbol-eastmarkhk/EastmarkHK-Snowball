import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    setContentSize(NSSize(width: 1280, height: 860))
    minSize = NSSize(width: 1000, height: 720)
    center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    let appleIntelligenceRegistrar =
      flutterViewController.registrar(forPlugin: "AppleIntelligenceHandler")
    AppleIntelligenceHandler.register(with: appleIntelligenceRegistrar)

    let uiTranslationRegistrar =
      flutterViewController.registrar(forPlugin: "UiTranslationHandler")
    UiTranslationHandler.register(with: uiTranslationRegistrar)

    let filesChannel = FlutterMethodChannel(
      name: "com.eastmarkhk.snowball/files",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    filesChannel.setMethodCallHandler { call, result in
      guard call.method == "savePdf" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let args = call.arguments as? [String: Any],
        let fileName = args["fileName"] as? String,
        let typed = args["bytes"] as? FlutterStandardTypedData
      else {
        result(
          FlutterError(
            code: "bad_args",
            message: "savePdf requires fileName and bytes",
            details: nil
          )
        )
        return
      }

      let panel = NSSavePanel()
      panel.canCreateDirectories = true
      panel.isExtensionHidden = false
      panel.allowedContentTypes = [UTType.pdf]
      panel.nameFieldStringValue = fileName
      panel.begin { response in
        guard response == .OK, let url = panel.url else {
          result(nil)
          return
        }
        do {
          try typed.data.write(to: url, options: .atomic)
          result(url.path)
        } catch {
          result(
            FlutterError(
              code: "write_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }

    super.awakeFromNib()
  }
}
