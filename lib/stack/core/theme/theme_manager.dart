import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';

/// A tool to handle theming over the course of the app lifecycle.
abstract class ThemeManager {
  /// Gets the currently saved theme mode.
  Future<ThemeMode?> getThemeMode();

  /// The mode in effect for [context], `system` when no theme wrapper is
  /// above it.
  ThemeMode currentThemeMode(BuildContext context);

  /// Changes the current theme mode with the given [newThemeMode].
  void changeThemeMode(BuildContext context, ThemeMode newThemeMode);

  /// Toggles the current theme mode between light and dark.
  void toggleThemeMode(BuildContext context);
}

/// ThemeManager Implementation
class ThemeManagerImpl implements ThemeManager {
  @override
  Future<ThemeMode?> getThemeMode() async {
    try {
      final mode = await AdaptiveTheme.getThemeMode();
      return mode != null
          ? ThemeMode.values.byName(mode.name)
          : ThemeMode.system;
    } catch (e) {
      // Log the error and return default theme mode
      return ThemeMode.system;
    }
  }

  @override
  ThemeMode currentThemeMode(BuildContext context) {
    final mode = AdaptiveTheme.maybeOf(context)?.mode;

    return mode == null ? ThemeMode.system : ThemeMode.values.byName(mode.name);
  }

  @override
  void changeThemeMode(BuildContext context, ThemeMode newThemeMode) {
    AdaptiveTheme.of(
      context,
    ).setThemeMode(AdaptiveThemeMode.values.byName(newThemeMode.name));
  }

  @override
  void toggleThemeMode(BuildContext context) {
    final currentThemeMode = AdaptiveTheme.of(context).mode;
    if (currentThemeMode == AdaptiveThemeMode.system) {
      // Get the current system brightness to decide the theme to switch.
      final brightness = PlatformDispatcher.instance.platformBrightness;
      if (brightness == Brightness.light) {
        AdaptiveTheme.of(context).setDark();
      } else {
        AdaptiveTheme.of(context).setLight();
      }
    } else if (currentThemeMode == AdaptiveThemeMode.light) {
      AdaptiveTheme.of(context).setDark();
    } else {
      AdaptiveTheme.of(context).setLight();
    }
  }
}
