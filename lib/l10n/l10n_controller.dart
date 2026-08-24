import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/on_demand_ui_translator.dart';
import '../services/ui_translation_store.dart';
import 'app_strings.dart';
import 'locale_names.dart';

/// Owns the app's current language: detects the OS language on first
/// launch, lets the user override it, and lazily translates AppStrings.en
/// via OnDemandUiTranslator (Apple Translation, falling back to Mistral) —
/// same mechanism as the EastmarkHK e-Invoicing app. Packs are cached to
/// disk by UiTranslationStore, so each language is only ever translated
/// once per install.
class L10nController extends ChangeNotifier {
  static const _prefLangKey = 'l10n_lang_code';
  static const _prefLangNameKey = 'l10n_lang_name';

  Map<String, String> _strings = AppStrings.en;
  String _languageCode = 'en';
  String _languageName = 'English';
  bool _isTranslating = false;
  String _translatingEngine = '';
  int _translateDone = 0;
  int _translateTotal = 1;
  String? _lastError;

  Map<String, String> get strings => _strings;
  String get languageCode => _languageCode;
  String get languageName => _languageName;
  bool get isTranslating => _isTranslating;
  String get translatingEngine => _translatingEngine;
  int get translateDone => _translateDone;
  int get translateTotal => _translateTotal;
  String? get lastError => _lastError;

  /// Look up a translated string by key, falling back to English (and
  /// finally to the key itself) if something is missing.
  String t(String key) => _strings[key] ?? AppStrings.en[key] ?? key;

  /// The device/OS language, including country when it matters
  /// (e.g. `pt_BR` for Portuguese in Brazil vs `pt` for Portugal).
  static String systemLanguageCode() {
    final loc = WidgetsBinding.instance.platformDispatcher.locale;
    final country = loc.countryCode;
    if (country != null && country.isNotEmpty) {
      final full = '${loc.languageCode}_$country';
      if (languageOptionForCode(full)?.code == full) return full;
    }
    return loc.languageCode;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_prefLangKey);

    if (savedCode != null) {
      final savedName = prefs.getString(_prefLangNameKey) ?? savedCode;
      await _applyLanguage(savedCode, savedName, prefs, persist: false);
      return;
    }

    // First run: no saved preference yet — default to the OS language.
    // English stays English; anything else gets translated right away.
    final systemCode = systemLanguageCode();
    if (systemCode == 'en') {
      _languageCode = 'en';
      _languageName = 'English';
      _strings = AppStrings.en;
      await prefs.setString(_prefLangKey, 'en');
      await prefs.setString(_prefLangNameKey, 'English');
      notifyListeners();
      return;
    }

    final name = languageNameForCode(systemCode) ?? systemCode;
    await _applyLanguage(systemCode, name, prefs, persist: true);
  }

  /// Called when the user explicitly picks a language.
  Future<void> setLanguage(String code, String name, {bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await _applyLanguage(code, name, prefs, persist: true, force: force);
  }

  Future<void> _applyLanguage(
    String code,
    String name,
    SharedPreferences prefs, {
    required bool persist,
    bool force = false,
  }) async {
    _languageCode = code;
    _languageName = name;
    _lastError = null;

    if (UiTranslationStore.isEnglish(code)) {
      _strings = AppStrings.en;
      if (persist) {
        await prefs.setString(_prefLangKey, code);
        await prefs.setString(_prefLangNameKey, name);
      }
      notifyListeners();
      return;
    }

    if (!force && await UiTranslationStore.hasReadyPack(code)) {
      final cached = await UiTranslationStore.load(code);
      if (cached != null) {
        _strings = cached;
        if (persist) {
          await prefs.setString(_prefLangKey, code);
          await prefs.setString(_prefLangNameKey, name);
        }
        notifyListeners();
        return;
      }
    }

    _isTranslating = true;
    _translateDone = 0;
    _translateTotal = AppStrings.en.length;
    _translatingEngine =
        await OnDemandUiTranslator.appleAvailable(code) ? 'Apple Intelligence' : 'Mistral AI';
    notifyListeners();

    try {
      await OnDemandUiTranslator.ensurePack(
        code: code,
        languageName: name,
        force: force,
        onProgress: (done, total, engine) {
          _translateDone = done;
          _translateTotal = total;
          _translatingEngine = engine;
          notifyListeners();
        },
      );
      final pack = await UiTranslationStore.load(code);
      _strings = pack ?? AppStrings.en;
      if (persist) {
        await prefs.setString(_prefLangKey, code);
        await prefs.setString(_prefLangNameKey, name);
      }
    } catch (e) {
      _lastError = _describeTranslationError(e);
      _strings = AppStrings.en; // Graceful fallback — app stays usable.
      if (kDebugMode) {
        debugPrint('Translation failed for $name ($code): $_lastError');
      }
    } finally {
      _isTranslating = false;
      notifyListeners();
    }
  }

  /// Turns a raw exception into a short explanation the user can act on.
  static String _describeTranslationError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('missingpluginexception') ||
        lower.contains('no implementation found')) {
      return 'Apple Translation is not available on this device. '
          'Mistral fallback also failed.\n$raw';
    }
    if (lower.contains('operation not permitted') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable')) {
      return 'Cannot reach Mistral — network blocked or offline.\n$raw';
    }
    if (lower.contains('401') || lower.contains('unauthorized') ||
        lower.contains('invalid api key')) {
      return 'Mistral rejected the API key.\n$raw';
    }
    if (lower.contains('429') || lower.contains('rate limit')) {
      return 'Mistral rate limit reached. Try again in a moment.\n$raw';
    }
    if (lower.contains('api key missing')) {
      return 'Mistral API key is missing from the app configuration.\n$raw';
    }
    return raw;
  }
}
