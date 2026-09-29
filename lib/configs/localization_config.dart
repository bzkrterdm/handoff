import 'package:flutter/widgets.dart';

/// Localization setup handed to `DynamicLocalization`.
abstract class LocalizationConfig {
  /// Directory holding the translation files, declared in pubspec assets.
  static const String assetsPath = 'assets/translations';

  /// Whether a translation file is named after the language code only
  /// (`en.json`) rather than language and country (`en-US.json`).
  static const bool useOnlyLangCode = true;

  /// Locale to fall back to for a missing locale or key.
  static const Locale fallbackLocale = Locale('en');

  /// Locales the app ships translations for. The app starts in the device
  /// language when it is one of these, otherwise in [fallbackLocale]; the
  /// user can pick another one from the settings menu.
  static const List<Locale> supportedLocales = [fallbackLocale, Locale('tr')];

  /// Display name of each supported locale, in that language.
  static const Map<String, String> languageNames = {
    'en': 'English',
    'tr': 'Türkçe',
  };
}
