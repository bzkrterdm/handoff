/// Where the task files live below a workspace root, and how to get from
/// one to the other. Pure path arithmetic, shared by the store (which
/// creates and resolves the folder) and the UI (which names the workspace).
///
/// Paths may use either separator: `/` on macOS and Linux, `\` (or a mix)
/// on Windows. The well-known folder names are written with `/` and matched
/// against either.
abstract class WorkspaceLayout {
  /// Task folder names below a workspace root. The first is what a fresh
  /// workspace gets; the second is accepted for existing setups.
  static const List<String> taskFolderNames = ['.handoff/tasks', '_hub/tasks'];

  /// The folder the projects live under. The task folder is a well-known
  /// sub folder of it; anything else is treated as a direct child of the
  /// root.
  static String rootOf(String tasksDirectory) {
    final path = trimSlash(tasksDirectory);
    final name = taskFolderNameOf(path);
    if (name != null) {
      return path.substring(0, path.length - name.length - 1);
    }
    final cut = _lastSeparator(path);

    return cut <= 0 ? path : path.substring(0, cut);
  }

  /// The last segment of the workspace root, for display.
  static String rootNameOf(String tasksDirectory) {
    final segments = rootOf(tasksDirectory).split(_separators);

    return segments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
  }

  /// Which of [taskFolderNames] [path] ends with, or null.
  static String? taskFolderNameOf(String path) {
    final posix = trimSlash(path).replaceAll(r'\', '/');
    for (final name in taskFolderNames) {
      if (posix.endsWith('/$name')) return name;
    }

    return null;
  }

  /// Whether [path] is itself a task folder (`…/.handoff/tasks`).
  static bool isTaskFolder(String path) => taskFolderNameOf(path) != null;

  /// [path] without trailing separators. A bare root (`/`, `C:\`) is kept.
  static String trimSlash(String path) {
    final trimmed = path.replaceAll(RegExp(r'[/\\]+$'), '');
    if (trimmed.isEmpty && path.isNotEmpty) return path.substring(0, 1);
    if (RegExp(r'^[A-Za-z]:$').hasMatch(trimmed)) return path;

    return trimmed;
  }

  // Helpers
  static final RegExp _separators = RegExp(r'[/\\]');

  static int _lastSeparator(String path) {
    final slash = path.lastIndexOf('/');
    final backslash = path.lastIndexOf(r'\');

    return slash > backslash ? slash : backslash;
  }

  // - Helpers
}
