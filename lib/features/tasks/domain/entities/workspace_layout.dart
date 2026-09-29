/// Where the task files live below a workspace root, and how to get from
/// one to the other. Pure path arithmetic, shared by the store (which
/// creates and resolves the folder) and the UI (which names the workspace).
abstract class WorkspaceLayout {
  /// Task folder names below a workspace root. The first is what a fresh
  /// workspace gets; the second is accepted for existing setups.
  static const List<String> taskFolderNames = ['.handoff/tasks', '_hub/tasks'];

  /// The folder the projects live under. The task folder is a well-known
  /// sub folder of it; anything else is treated as a direct child of the
  /// root.
  static String rootOf(String tasksDirectory) {
    final path = trimSlash(tasksDirectory);
    for (final name in taskFolderNames) {
      if (path.endsWith('/$name')) {
        return path.substring(0, path.length - name.length - 1);
      }
    }
    final cut = path.lastIndexOf('/');

    return cut <= 0 ? path : path.substring(0, cut);
  }

  /// The last segment of the workspace root, for display.
  static String rootNameOf(String tasksDirectory) {
    final segments = rootOf(tasksDirectory).split('/');

    return segments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
  }

  static String trimSlash(String path) => path.replaceAll(RegExp(r'/+$'), '');
}
