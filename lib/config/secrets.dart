/// API keys for this app.
///
/// The Mistral key is a build-time value, not committed:
///   flutter run --dart-define-from-file=dart_defines.json
///   flutter run --dart-define=MISTRAL_API_KEY=your_key_here
///
/// Copy `dart_defines.json.example` to `dart_defines.json` (gitignored).
/// Xcode Cloud can inject the same define as a workflow secret later.
const String mistralApiKey = String.fromEnvironment('MISTRAL_API_KEY');
