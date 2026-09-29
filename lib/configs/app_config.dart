/// App level constants that are the same in every environment.
/// Whatever differs per environment belongs in `EnvConfig`.
abstract class AppConfig {
  /// Localization key of the app title shown by the OS.
  static const String titleKey = 'title_app';
}
