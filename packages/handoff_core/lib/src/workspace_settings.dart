/// Remembers which folder the owner pointed the app at. Each app keeps it
/// in its own place: the desktop app in its preferences, the terminal app in
/// a config file.
abstract class WorkspaceSettings {
  Future<String?> tasksDirectory();

  Future<void> setTasksDirectory(String path);
}
