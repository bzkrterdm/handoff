import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';

/// Wrapper widget that remembers the theme mode the user picked and rebuilds
/// [builder] whenever it changes. Wrap the widget that creates the app:
///
/// ```dart
/// void main() async {
///   runApp(
///     MyApp(themeMode: await locator<ThemeManager>().getThemeMode()),
///   );
/// }
///
/// class MyApp extends StatelessWidget {
///   const MyApp({super.key, this.themeMode});
///
///   final ThemeMode? themeMode;
///
///   @override
///   Widget build(BuildContext context) {
///     return DynamicTheme(
///       initialMode: themeMode ?? ThemeMode.system,
///       builder: (mode) => MaterialApp(
///         theme: lightTheme,
///         darkTheme: darkTheme,
///         themeMode: mode,
///         home: MyHomePage(),
///       ),
///     );
///   }
/// }
/// ```
///
/// Note that [initialMode] only works at first run after installation. After
/// that, the last saved theme mode will be used. Getting the current mode in
/// main before runApp prevents flashing at start.
///
/// Only the *mode* goes through [AdaptiveTheme]: the themes themselves stay
/// with the app and go straight to `MaterialApp`, which already resolves them
/// against the mode. [AdaptiveTheme] is left holding a placeholder it never
/// renders — nothing here reads its theme getters, only its mode.
class DynamicTheme extends StatelessWidget {
  const DynamicTheme({
    super.key,
    required this.initialMode,
    required this.builder,
  });

  /// Never rendered. [AdaptiveTheme] requires a theme and this stack does not
  /// let it own one — see the class doc.
  static final ThemeData _placeholderTheme = ThemeData();

  final ThemeMode initialMode;
  final DynamicThemeBuilder builder;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: _placeholderTheme,
      dark: _placeholderTheme,
      initial: AdaptiveThemeMode.values.byName(initialMode.name),
      // The Builder is what makes this work: AdaptiveTheme wraps whatever the
      // builder returns in its InheritedAdaptiveTheme, so a lookup made from
      // inside that subtree finds the manager and re-runs on a mode change.
      // Reading it in this builder directly would not — the widget is built
      // before the inherited widget is in place.
      builder: (_, _) => Builder(builder: _buildForCurrentMode),
    );
  }

  // Helpers
  Widget _buildForCurrentMode(BuildContext context) {
    final mode = AdaptiveTheme.of(context).mode;
    return builder(ThemeMode.values.byName(mode.name));
  }

  // - Helpers
}

/// Builds the app for the theme mode currently in effect.
typedef DynamicThemeBuilder = Widget Function(ThemeMode mode);
