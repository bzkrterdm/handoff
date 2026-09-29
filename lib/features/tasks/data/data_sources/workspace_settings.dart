import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which folder the owner pointed the app at.
///
/// Plain preferences rather than the stack's encrypted `LocalStorage`: a
/// folder path is not a secret, and the encrypted store needs the keychain,
/// which prompts on an unsigned debug build.
abstract class WorkspaceSettings {
  Future<String?> tasksDirectory();

  Future<void> setTasksDirectory(String path);
}

class WorkspaceSettingsImpl implements WorkspaceSettings {
  static const String _key = 'tasks_directory';

  @override
  Future<String?> tasksDirectory() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_key);
  }

  @override
  Future<void> setTasksDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }
}
