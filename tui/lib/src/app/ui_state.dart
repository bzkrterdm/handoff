import 'dart:io';

import 'package:handoff_core/handoff_core.dart';
import 'package:path/path.dart' as p;

/// The three panes of the board, left to right.
enum Pane { projects, list, detail }

/// What fills the screen below the header.
enum Screen {
  loading,

  /// No folder chosen yet: the first start.
  welcome,

  /// The folder could not be read; shows which one and why.
  error,
  board,
}

/// Where the cursor and the scroll offsets are, and what is on top. Plain
/// mutable state: the app changes it in response to keys, the painter
/// reads it (and keeps scroll offsets in range while drawing).
class UiState {
  Screen screen = Screen.loading;
  Pane focus = Pane.list;

  /// The task folder being shown (or that failed).
  String workspace = '';
  String errorMessage = '';

  /// Index of the checklist item under the cursor in the details.
  int detailCursor = 0;
  int detailScroll = 0;

  /// The task the cursor and scroll above belong to.
  String? detailTaskId;

  int listScroll = 0;
  int projectScroll = 0;

  /// Keep the cursor's item on screen on the next paint (after a cursor
  /// move, not after a page scroll).
  bool followCursor = true;

  Toast? toast;
  Modal? modal;
}

/// A one-line message in the footer that goes away by itself.
class Toast {
  const Toast(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

/// A dialog over the board.
sealed class Modal {}

class ConfirmModal extends Modal {
  ConfirmModal({required this.message, required this.onConfirm});

  final String message;
  final Future<void> Function() onConfirm;

  /// 0 = confirm, 1 = cancel.
  int choice = 0;
}

class HelpModal extends Modal {
  int scroll = 0;
}

class SettingsModal extends Modal {
  /// 0–2 language (system, en, tr), 3–5 appearance (system, light, dark).
  int cursor = 0;

  static const int rows = 6;
}

/// A small folder browser, since a terminal has no folder dialog.
class FolderModal extends Modal {
  FolderModal(String start) {
    open(start);
  }

  /// Maximum folders listed, so a huge folder stays quick to draw.
  static const int maxEntries = 2000;

  late String directory;
  List<FolderEntry> entries = const [];
  bool showHidden = false;

  /// Row under the cursor: 0 = "use this folder", 1 = "up", then entries.
  int cursor = 0;
  int scroll = 0;

  /// Typing a path instead of browsing.
  bool typing = false;
  String typed = '';
  String? error;

  int get rowCount => 2 + entries.length;

  /// Shows [path]'s sub folders. Returns false (and keeps the current
  /// folder) when it cannot be listed.
  bool open(String path) {
    final normalized = p.normalize(p.absolute(path));
    final listed = _list(normalized);
    if (listed == null) {
      error = normalized;
      return false;
    }
    directory = normalized;
    entries = listed;
    cursor = 0;
    scroll = 0;
    error = null;

    return true;
  }

  void up() {
    final parent = p.dirname(directory);
    if (parent == directory) return;
    final from = p.basename(directory);
    if (open(parent)) {
      final index = entries.indexWhere((entry) => entry.name == from);
      if (index >= 0) cursor = index + 2;
    }
  }

  void toggleHidden() {
    showHidden = !showHidden;
    open(directory);
  }

  /// Completes [typed] to the only sub folder that starts with what was
  /// typed after the last separator, or to their common prefix.
  void complete() {
    final text = typed.isEmpty ? directory : typed;
    final expanded = expandHome(text);
    final endsWithSeparator = expanded.endsWith('/') || expanded.endsWith(r'\');
    final parent = endsWithSeparator ? expanded : p.dirname(expanded);
    final prefix = endsWithSeparator ? '' : p.basename(expanded);
    final names = (_list(parent, hidden: prefix.startsWith('.')) ?? const [])
        .map((entry) => entry.name)
        .where((name) => name.startsWith(prefix))
        .toList();
    if (names.isEmpty) return;

    var common = names.first;
    for (final name in names.skip(1)) {
      var i = 0;
      while (i < common.length && i < name.length && common[i] == name[i]) {
        i++;
      }
      common = common.substring(0, i);
    }
    final completed = p.join(parent, common);
    typed = names.length == 1 ? '$completed${p.separator}' : completed;
  }

  /// Whether [path] is already a Handoff workspace or task folder.
  static bool hasTasks(String path) {
    if (WorkspaceLayout.isTaskFolder(path)) return true;

    return WorkspaceLayout.taskFolderNames.any(
      (name) => Directory(p.joinAll([path, ...name.split('/')])).existsSync(),
    );
  }

  /// `~` at the start of [path] → the home folder.
  static String expandHome(String path) {
    if (path != '~' && !path.startsWith('~/') && !path.startsWith(r'~\')) {
      return path;
    }
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';

    return home + path.substring(1);
  }

  // Helpers
  List<FolderEntry>? _list(String path, {bool? hidden}) {
    final showAll = hidden ?? showHidden;
    try {
      final folders = <FolderEntry>[];
      for (final entity in Directory(path).listSync(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = p.basename(entity.path);
        if (!showAll && name.startsWith('.')) continue;
        folders.add(FolderEntry(name, hasTasks: hasTasks(entity.path)));
        if (folders.length >= maxEntries) break;
      }
      folders.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      return folders;
    } on FileSystemException {
      return null;
    }
  }

  // - Helpers
}

class FolderEntry {
  const FolderEntry(this.name, {this.hasTasks = false});

  final String name;

  /// Already a Handoff workspace (has `.handoff/tasks` or `_hub/tasks`).
  final bool hasTasks;
}
