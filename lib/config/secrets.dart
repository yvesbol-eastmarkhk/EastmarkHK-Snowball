/// Optional compile-time Mistral key for developer / Xcode Cloud builds.
/// Customers add their own key in Settings; that on-device key wins.
///
///   flutter run --dart-define-from-file=dart_defines.json
///   flutter run --dart-define=MISTRAL_API_KEY=your_key_here
///
/// Copy `dart_defines.json.example` to `dart_defines.json` (gitignored).
const String compileTimeMistralApiKey =
    String.fromEnvironment('MISTRAL_API_KEY');
