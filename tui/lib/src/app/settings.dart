import 'dart:convert';
import 'dart:io';

import 'package:handoff_core/handoff_core.dart';
import 'package:path/path.dart' as p;

import 'strings.dart';
import 'theme.dart';

/// The terminal app's preferences in one small JSON file: the workspace
/// folder (the desktop app keeps it in macOS preferences), the language and
/// the appearance.
///
/// `$XDG_CONFIG_HOME/handoff/tui.json` (default `~/.config/handoff`) on macOS
/// and Linux, `%APPDATA%\handoff\tui.json` on Windows.
class TuiSettings implements WorkspaceSettings {
  TuiSettings(this.file);

  factory TuiSettings.standard([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    final String folder;
    if (Platform.isWindows) {
      folder = p.join(env['APPDATA'] ?? env['USERPROFILE'] ?? '.', 'handoff');
    } else {
      final xdg = env['XDG_CONFIG_HOME'];
      folder = xdg != null && xdg.isNotEmpty
          ? p.join(xdg, 'handoff')
          : p.join(env['HOME'] ?? '.', '.config', 'handoff');
    }

    return TuiSettings(File(p.join(folder, 'tui.json')));
  }

  static const String _tasksDirectoryKey = 'tasks_directory';
  static const String _languageKey = 'language';
  static const String _appearanceKey = 'appearance';

  final File file;
  Map<String, Object?>? _cache;

  @override
  Future<String?> tasksDirectory() async {
    final value = _read()[_tasksDirectoryKey];

    return value is String && value.isNotEmpty ? value : null;
  }

  @override
  Future<void> setTasksDirectory(String path) =>
      _write(_tasksDirectoryKey, path);

  Language get language => Language.parse(_read()[_languageKey]);

  Future<void> setLanguage(Language value) =>
      _write(_languageKey, value == Language.system ? null : value.name);

  Appearance get appearance => Appearance.parse(_read()[_appearanceKey]);

  Future<void> setAppearance(Appearance value) =>
      _write(_appearanceKey, value == Appearance.system ? null : value.name);

  // Helpers
  Map<String, Object?> _read() {
    final cached = _cache;
    if (cached != null) return cached;

    var values = <String, Object?>{};
    try {
      if (file.existsSync()) {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is Map<String, Object?>) values = decoded;
      }
    } on Object {
      // A broken file means defaults; the next write replaces it.
    }

    return _cache = values;
  }

  /// Stores [value] under [key]; null removes it ("follow the system").
  Future<void> _write(String key, Object? value) async {
    final values = Map<String, Object?>.of(_read());
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
    _cache = values;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(values),
    );
  }

  // - Helpers
}
