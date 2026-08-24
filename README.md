# EastmarkHK Snowball

A compound-interest calculator built with Flutter, targeting iOS, Android, macOS, and Windows from one codebase.

Enter an initial investment, an annual interest rate, a number of years, and a compounding frequency (annually, semi-annually, quarterly, monthly, weekly, or daily) to see the final balance, total interest earned, a growth chart with per-year markers, a year-by-year breakdown table, and a printable/zoomable PDF report. Optional regular contributions (monthly or annual top-ups) are supported too. The whole UI translates itself into whatever language you pick (or your OS language, automatically, on first launch) — using the same translation system as the EastmarkHK e-Invoicing app.

## If you already ran `flutter create` / `pub get` once

You need to re-run `flutter pub get` (new dependencies: `path_provider`, `path`, `flutter_native_splash`) and **delete 4 now-obsolete files** that an earlier version of this project added, replaced by the files below:

```bash
cd "/Users/yvesbolkaerts/development/EastmarkHK/EastmarkHK Snowball"
rm -f lib/services/apple_intelligence_channel.dart
rm -f lib/services/translation_service.dart
rm -f macos/Runner/AppleIntelligenceTranslator.swift   # only if you'd copied it in
rm -f ios/Runner/AppleIntelligenceTranslator.swift     # only if you'd copied it in
flutter clean
flutter pub get
dart run flutter_native_splash:create
```

Then follow the two macOS entitlement steps below if you haven't already — **this is almost certainly why you saw `Operation not permitted` errors on `fonts.gstatic.com` and `api.mistral.ai`** — and copy in `native/*/UiTranslationHandler.swift` per "Wiring up native translation" below.

## Why you need to run one command first (first-time setup)

This project's Dart/UI code (`lib/`, `pubspec.yaml`) was written for you already. The `ios/`, `android/`, `macos/`, and `windows/` platform folders were **not** generated here, because scaffolding them requires the Flutter tool to download the Dart SDK from Google's servers, which this sandbox can't reach. Your Mac already has Flutter installed (for your other projects), so generating those folders there takes one command and a minute.

```bash
cd "/Users/yvesbolkaerts/development/EastmarkHK/EastmarkHK Snowball"

# Remove the placeholder file left in this folder (first run only)
rm -f "new app"

# Generate the iOS / Android / macOS / Windows platform projects.
# This will NOT overwrite lib/main.dart or pubspec.yaml since flutter create
# only fills in files that are missing.
flutter create --platforms=ios,android,macos,windows \
  --org com.eastmarkhk \
  --project-name eastmarkhk_snowball .

flutter pub get
dart run flutter_native_splash:create
```

## Splash screen

Shows for a minimum of 3 seconds at boot on every platform, using the 3 images you provided (now in `assets/`): `logo_full.png` (the diamond E mark), `splash_mobile.png` (portrait), `splash_desktop.png` (landscape).

- **iOS/Android**: `flutter_native_splash` (configured at the bottom of `pubspec.yaml`) generates the real native splash screens — `splash_mobile.png` as a full-bleed background, plus an Android 12+ variant (`logo_full.png` centered on the brand green, since Android 12's splash API only allows an icon + color, not a full custom image). `dart run flutter_native_splash:create` (from the setup command above) writes the actual platform files — re-run it any time you change these images. `lib/main.dart` calls `FlutterNativeSplash.preserve()` before `runApp()` and only calls `.remove()` once boot work is done **and** at least 3 seconds have passed, whichever is longer, so it won't flash away instantly on a fast device.
- **macOS/Windows/Linux**: there's no OS-level splash API for desktop, so `lib/main.dart` shows `splash_desktop.png` full-screen itself (a `_DesktopSplash` widget) during that same 3-second-minimum boot window, then swaps to the real UI.

If you ever swap in new artwork, just replace the 3 files in `assets/` (keep the same filenames) and re-run `dart run flutter_native_splash:create`.

## macOS: two entitlements you MUST add

Flutter's default macOS sandbox blocks outgoing network requests and printing unless you explicitly allow them. This app needs both — network for Mistral translation and for the PDF report's fonts, printing for the Print button. Open **both** `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements` and add these two keys inside the existing `<dict>`:

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.print</key>
<true/>
```

If you already ran the app once before adding these, do a clean rebuild afterwards — Xcode/Flutter can cache a signed build without the new entitlement:

```bash
flutter clean
flutter pub get
flutter run -d macos
```

Then run it:

```bash
flutter devices          # see what's available
flutter run -d macos     # run on your Mac
flutter run -d ios       # run in the iOS Simulator (or a connected iPhone)
flutter run -d windows   # run on Windows (only works when run from a Windows machine)
```

For Android, open the project in Android Studio or run `flutter run -d android` with an emulator/device attached.

## App icon (optional)

You already have `Icon_eastmarkhk.png` / `main_icon.png` one folder up. To apply it as the app icon on every platform:

```bash
flutter pub add flutter_launcher_icons --dev
```

Then add this to `pubspec.yaml` and run `flutter pub run flutter_launcher_icons`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  macos:
    generate: true
  windows:
    generate: true
  image_path: "../Icon_eastmarkhk.png"
```

## Language / translation — same system as EastmarkHK e-Invoicing

The gear icon opens Settings, where the language field is a dropdown: it shows the current language, and tapping it opens a searchable list (title + search box, "System language" pinned at the top, ~55 languages below) — the exact interaction used by e-Invoicing's language picker.

Translation itself works exactly like e-Invoicing's `OnDemandUiTranslator` / `UiTranslationStore` / `UiTranslationHandler`, ported into this app:

1. **Apple's on-device Translation framework** (macOS 15+ / iOS 18+) — tried first. This is Apple's `Translation` framework (`TranslationSession`), the same one used system-wide for Safari/Mail translation — not a language model, so no "AI hallucination" risk, and it works offline once the language pack is downloaded.
2. **Mistral AI** — the fallback used whenever Apple's framework isn't available (Windows, Android, an older Mac/iPhone, or Apple Intelligence not enabled). Pass the API key at build time with `--dart-define-from-file=dart_defines.json` (see `dart_defines.json.example`).

Strings are translated in batches of 40 with `{placeholder}` tokens protected so they never get mangled, and the finished pack is cached to a JSON file on disk (`Application Support/ui_l10n/{code}.json`) — so each language is translated only once, ever, exactly like e-Invoicing. A small progress dialog (engine name + progress bar) shows while a new pack is being generated; picking a language you've already used loads instantly from disk.

### Wiring up native translation (do this — it's not optional this time)

Unlike the previous (removed) Apple Intelligence experiment, this one is the same code e-Invoicing ships with, so it's worth wiring in properly:

1. After running `flutter create`, copy `native/macos/UiTranslationHandler.swift` into `macos/Runner/`, and `native/ios/UiTranslationHandler.swift` into `ios/Runner/`.
2. In `macos/Runner/MainFlutterWindow.swift`, inside `awakeFromNib()`, after `RegisterGeneratedPlugins(registry: flutterViewController)`, add:
   ```swift
   let uiTranslationRegistrar =
     flutterViewController.registrar(forPlugin: "UiTranslationHandler")
   UiTranslationHandler.register(with: uiTranslationRegistrar)
   ```
3. In `ios/Runner/AppDelegate.swift`, inside `application(_:didFinishLaunchingWithOptions:)`, after the FlutterViewController is available, add:
   ```swift
   if let controller = window?.rootViewController as? FlutterViewController {
     let registrar = controller.registrar(forPlugin: "UiTranslationHandler")
     UiTranslationHandler.register(with: registrar)
   }
   ```
   (If your generated `AppDelegate.swift` uses the newer `FlutterImplicitEngineDelegate` / `didInitializeImplicitFlutterEngine` shape instead, register it the same way e-Invoicing's `ios/Runner/AppDelegate.swift` does — same pattern, same plugin name.)

If you skip this step entirely, the Dart side detects the native channel is missing and falls back straight to Mistral — the app still works, just without the on-device option.

## PDF report

On the results screen, the "Compound Interest Report" card shows a live preview of a formatted PDF (logo, investment details, headline numbers, full year-by-year table) — translated into whatever language is currently active, using the same `PdfGoogleFonts` Unicode-font-loading pattern as e-Invoicing's `PdfFonts`. Tap the card to open a full-screen modal with pinch/scroll zoom and a Print button — same `_PdfPane` / "tap to enlarge" pattern used in e-Invoicing's invoice PDF preview.

Font loading fetches Noto Sans from Google Fonts at runtime over the network, exactly like e-Invoicing does — which is why the network entitlement above is required for the PDF to render with a proper Unicode font (without it, it silently falls back to Helvetica, which has no accented-character support).

## Project structure

```
lib/
  main.dart                     — app entry point, theme, first-launch translation
  calculator.dart                — compound interest math (no UI dependencies)
  config/secrets.dart            — reads MISTRAL_API_KEY from dart-define
  l10n/
    app_strings.dart             — master English UI strings (source of all translations)
    locale_names.dart            — language picker list
    l10n_controller.dart         — language state, first-run OS-language detection
  services/
    on_demand_ui_translator.dart — Apple Translation → Mistral fallback, chunked, placeholder-safe
    ui_translation_store.dart    — on-disk JSON translation cache
    mistral_ai_service.dart      — minimal Mistral client (UI translation only)
    report_pdf_service.dart      — builds the PDF report
  screens/
    home_screen.dart             — the calculator form + results UI
    settings_screen.dart         — language dropdown
  widgets/
    language_dropdown.dart       — dropdown field + searchable picker dialog
    growth_chart.dart            — dependency-free line chart with per-year markers
    pdf_report_modal.dart        — PDF preview card + zoomable/printable modal
    eastmark_footer.dart         — shared EastmarkHK footer (ported from e-Invoicing)
    thousands_input_formatter.dart — live comma-formatting for numeric fields
  utils/
    eastmark_brand.dart          — company name / website
    pdf_fonts.dart                — Unicode font loading for the PDF
native/
  macos/, ios/UiTranslationHandler.swift — Apple Translation framework bridge (ported from e-Invoicing)
assets/
  logo.png             — AppBar wordmark logo
  logo_full.png         — diamond "E" mark, used for the Android 12+ splash icon
  splash_mobile.png     — iOS/Android native splash background
  splash_desktop.png    — desktop boot splash (shown by _DesktopSplash in main.dart)
```

The calculation logic in `calculator.dart` is pure Dart with no Flutter imports, so it's straightforward to unit test if you want to add a `test/` folder later.
