import 'dart:async';
import 'dart:io';

import 'package:handoff_core/handoff_core.dart';
import 'package:path/path.dart' as p;

import '../terminal/canvas.dart';
import '../terminal/keys.dart';
import '../terminal/terminal.dart';
import 'board.dart';
import 'settings.dart';
import 'strings.dart';
import 'system.dart';
import 'theme.dart';
import 'ui_state.dart';
import 'views.dart';

/// Handoff in the terminal.
///
/// Same flow as the desktop app: the folder is the source of truth, a
/// watcher reloads on every change, writes go through the shared store
/// (line-level edits) and the store's answer is shown right away. What the
/// desktop app does with a mouse is a key here; what it does in another app
/// (a terminal window, Finder) is done from this terminal.
class HandoffApp {
  HandoffApp({
    required this.terminal,
    required this.store,
    required this.settings,
    required this.shell,
    this.initialFolder,
    this.toastDuration = const Duration(seconds: 4),
  });

  final TerminalIO terminal;
  final TaskDataSource store;
  final TuiSettings settings;
  final SystemShell shell;

  /// A folder given on the command line; picked as if chosen in the app.
  final String? initialFolder;
  final Duration toastDuration;

  final Board board = Board();
  final UiState ui = UiState();
  final FrameWriter _writer = FrameWriter();
  final Completer<void> _done = Completer<void>();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  late Strings strings = Strings.of(settings.language);
  late Palette palette = Palette.of(settings.appearance);

  /// The last frame drawn, for tests.
  Canvas? lastFrame;

  /// Numbers the loads: a slow read of a folder that has since been replaced
  /// must not put its tasks on screen (the desktop app's `WatchTasks` rule).
  int _loads = 0;
  bool _renderScheduled = false;
  bool _suspended = false;
  String _title = '';
  Timer? _toastTimer;

  /// Runs until the owner quits.
  Future<void> run() async {
    terminal.enter();
    _subscriptions
      ..add(terminal.keys.listen(_onKey))
      ..add(terminal.resizes.listen((_) => _redraw()))
      ..add(
        terminal.interrupts.listen((_) {
          // Ctrl-C inside an agent or editor belongs to that program.
          if (!_suspended) quit();
        }),
      )
      ..add(store.changes.listen((_) => _reload()));
    render();

    final folder = initialFolder;
    if (folder != null) {
      await changeWorkspace(folder);
    } else {
      await _reload();
    }
    await _done.future;
  }

  void quit() {
    if (_done.isCompleted) return;
    _toastTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    terminal.leave();
    _done.complete();
  }

  /// Draws the current state (coalesced: many changes, one frame).
  void render() {
    if (_renderScheduled) return;
    _renderScheduled = true;
    scheduleMicrotask(() {
      _renderScheduled = false;
      if (_done.isCompleted || _suspended) return;
      _paintNow();
    });
  }

  /// Points the app at another folder: the workspace root (a
  /// `.handoff/tasks` is created inside) or an existing task folder.
  Future<void> changeWorkspace(String path) async {
    try {
      await store.setLocation(FolderModal.expandHome(path));
    } on Exception catch (error) {
      final message = _describe(error);
      if (ui.screen == Screen.board) {
        _toast(message, isError: true);
      } else {
        // No list to toast over: show the error for the folder just picked
        // instead of swallowing it (the desktop app's D-033 rule).
        ui
          ..screen = Screen.error
          ..workspace = path
          ..errorMessage = message;
        render();
      }
      return;
    }
    board
      ..selectedProject = Board.allProjects
      ..showDone = false
      ..selectedTaskId = null;
    ui
      ..focus = Pane.list
      ..listScroll = 0
      ..projectScroll = 0;
    await _reload();
  }

  // Helpers
  void _paintNow() {
    _syncDetail();
    final painter = Painter(
      board: board,
      ui: ui,
      strings: strings,
      palette: palette,
    )..setChoices(settings.language, settings.appearance);
    final frame = painter.paint(terminal.width, terminal.height);
    lastFrame = frame;
    terminal.write(_writer.diff(frame, terminal.colorMode));
    _updateTitle();
  }

  void _redraw() {
    _writer.invalidate();
    render();
  }

  Future<void> _reload() async {
    final load = ++_loads;
    final String location;
    try {
      location = await store.location;
    } on Exception catch (error) {
      _showError('', _describe(error));
      return;
    }
    if (location.isEmpty) {
      if (load != _loads) return;
      ui
        ..screen = Screen.welcome
        ..workspace = '';
      render();
      return;
    }

    try {
      final tasks = await store.readAll();
      if (load != _loads) return;
      board.load(tasks);
      ui
        ..workspace = location
        ..screen = Screen.board;
    } on Exception catch (error) {
      if (load != _loads) return;
      _showError(location, _describe(error));
      return;
    }
    render();
  }

  void _showError(String workspace, String message) {
    ui
      ..screen = Screen.error
      ..workspace = workspace
      ..errorMessage = message;
    board.tasks = const [];
    render();
  }

  /// Resets the checklist cursor when another task is shown: it lands on
  /// the first item still to do.
  void _syncDetail() {
    final task = board.selectedTask;
    if (task?.id == ui.detailTaskId) {
      if (task != null && task.actions.isNotEmpty) {
        ui.detailCursor = ui.detailCursor.clamp(0, task.actions.length - 1);
      }
      return;
    }
    ui
      ..detailTaskId = task?.id
      ..detailScroll = 0
      ..followCursor = true
      ..detailCursor = task == null
          ? 0
          : task.actions
                .indexWhere((action) => !action.isDone)
                .clamp(0, task.actions.isEmpty ? 0 : task.actions.length - 1);
  }

  void _updateTitle() {
    final open = board.openCount;
    final title = ui.screen == Screen.board && open > 0
        ? '${strings('title_app')} ($open)'
        : strings('title_app');
    if (title == _title) return;
    _title = title;
    terminal.setTitle(title);
  }

  void _toast(String text, {bool isError = false}) {
    ui.toast = Toast(text, isError: isError);
    _toastTimer?.cancel();
    _toastTimer = Timer(toastDuration, () {
      ui.toast = null;
      render();
    });
    render();
  }

  // Keys
  void _onKey(Key key) {
    if (_suspended) return;
    if (ui.toast != null && key.type != KeyType.ctrlC) {
      ui.toast = null;
      _toastTimer?.cancel();
    }
    final modal = ui.modal;
    if (modal != null) {
      _onModalKey(modal, key);
      render();
      return;
    }
    if (key.type == KeyType.ctrlC || key.isChar('q')) {
      quit();
      return;
    }
    if (key.isChar('?')) {
      ui.modal = HelpModal();
    } else if (key.isChar(',') || key.isChar('s')) {
      ui.modal = SettingsModal()
        ..cursor = Language.values.indexOf(settings.language);
    } else if (key.isChar('w')) {
      _pickFolder();
    } else if (key.isChar('r') && ui.screen != Screen.loading) {
      _reload();
    } else {
      switch (ui.screen) {
        case Screen.loading:
          break;
        case Screen.welcome:
          if (key.type == KeyType.enter) _pickFolder();
        case Screen.error:
          if (key.type == KeyType.enter) _pickFolder();
        case Screen.board:
          _onBoardKey(key);
      }
    }
    render();
  }

  void _onBoardKey(Key key) {
    final task = board.selectedTask;
    final mode = BoardLayout.of(
      Rect(0, 1, terminal.width, terminal.height - 2),
      ui.focus,
    ).mode;

    switch (key.type) {
      case KeyType.up:
        _move(-1);
      case KeyType.down:
        _move(1);
      case KeyType.home:
        _move(-100000);
      case KeyType.end:
        _move(100000);
      case KeyType.pageUp:
        _page(-1);
      case KeyType.pageDown:
        _page(1);
      case KeyType.tab:
        _focus(Pane.values[(ui.focus.index + 1) % Pane.values.length]);
      case KeyType.backTab:
        _focus(Pane.values[(ui.focus.index + 2) % Pane.values.length]);
      case KeyType.left:
        _focusStep(-1);
      case KeyType.right:
        _focusStep(1);
      case KeyType.escape || KeyType.backspace:
        if (mode != LayoutMode.wide) _focusStep(-1);
      case KeyType.enter:
        switch (ui.focus) {
          case Pane.projects:
            _focus(Pane.list);
          case Pane.list:
            if (task != null) _focus(Pane.detail);
          case Pane.detail:
            if (task != null) _toggle(task, ui.detailCursor);
        }
      case KeyType.char:
        _onBoardChar(key.char, task);
      default:
        break;
    }
  }

  void _onBoardChar(String char, TaskModel? task) {
    switch (char) {
      case 'k':
        _move(-1);
      case 'j':
        _move(1);
      case 'g':
        _move(-100000);
      case 'G':
        _move(100000);
      case 'h':
        _focusStep(-1);
      case 'l':
        _focusStep(1);
      case 't':
        board.setShowDone(!board.showDone);
        ui.listScroll = 0;
      case 'W':
        _openWorkspace();
      case ' ':
        if (task != null && ui.focus == Pane.detail) {
          _toggle(task, ui.detailCursor);
        } else if (ui.focus == Pane.list && task != null) {
          _focus(Pane.detail);
        }
      default:
        if (task == null) return;
        _onTaskChar(char, task);
    }
  }

  void _onTaskChar(String char, TaskModel task) {
    final digit = int.tryParse(char);
    if (digit != null && digit >= 1 && digit <= 9) {
      if (digit <= task.actions.length) {
        ui
          ..detailCursor = digit - 1
          ..followCursor = true;
        _toggle(task, digit - 1);
      }
      return;
    }
    switch (char) {
      case 'd':
        if (task.isOpen) _setStatus(task, 'done');
      case 'u':
        if (task.isDone) _confirmReopen(task);
      case 'a':
        _connect(task);
      case 'i':
        if (task.actions.isNotEmpty) {
          final index = ui.detailCursor.clamp(0, task.actions.length - 1);
          _connect(task, focus: task.actions[index].text);
        }
      case 'e':
        _edit(task);
      case 'o':
        _openFile(task);
      case 'f':
        _reveal(task);
    }
  }

  void _move(int delta) {
    switch (ui.focus) {
      case Pane.projects:
        final keys = board.projectKeys;
        final index = keys.indexOf(board.selectedProject);
        final next = (index + delta).clamp(0, keys.length - 1);
        if (keys[next] != board.selectedProject) {
          board.selectProject(keys[next]);
          ui.listScroll = 0;
        }
      case Pane.list:
        board.moveSelection(delta);
      case Pane.detail:
        final task = board.selectedTask;
        if (task == null) return;
        if (task.actions.isEmpty) {
          // Nothing to point at: arrows scroll.
          ui
            ..detailScroll = (ui.detailScroll + delta.sign * 3).clamp(
              0,
              1 << 20,
            )
            ..followCursor = false;
          return;
        }
        ui
          ..detailCursor = (ui.detailCursor + delta).clamp(
            0,
            task.actions.length - 1,
          )
          ..followCursor = true;
    }
  }

  void _page(int direction) {
    if (ui.focus != Pane.detail && ui.focus != Pane.list) {
      _move(direction * 10);
      return;
    }
    if (ui.focus == Pane.list) {
      board.moveSelection(direction * 5);
      return;
    }
    final page = (terminal.height - 4).clamp(1, 1 << 20);
    ui
      ..detailScroll = (ui.detailScroll + direction * page).clamp(0, 1 << 20)
      ..followCursor = false;
  }

  void _focus(Pane pane) {
    ui.focus = pane;
    if (pane == Pane.detail) ui.followCursor = true;
  }

  void _focusStep(int delta) {
    final next = (ui.focus.index + delta).clamp(0, Pane.values.length - 1);
    if (Pane.values[next] == Pane.detail && board.selectedTask == null) return;
    _focus(Pane.values[next]);
  }

  // Modals
  void _onModalKey(Modal modal, Key key) {
    switch (modal) {
      case final ConfirmModal confirm:
        _onConfirmKey(confirm, key);
      case final HelpModal help:
        switch (key.type) {
          case KeyType.up:
            help.scroll--;
          case KeyType.down:
            help.scroll++;
          case KeyType.char when key.char == 'k':
            help.scroll--;
          case KeyType.char when key.char == 'j':
            help.scroll++;
          default:
            ui.modal = null;
        }
      case final SettingsModal settingsModal:
        _onSettingsKey(settingsModal, key);
      case final FolderModal folder:
        _onFolderKey(folder, key);
    }
  }

  void _onConfirmKey(ConfirmModal modal, Key key) {
    final confirm =
        key.isChar('y') || (key.type == KeyType.enter && modal.choice == 0);
    final cancel =
        key.isChar('n') ||
        key.type == KeyType.escape ||
        key.isChar('q') ||
        (key.type == KeyType.enter && modal.choice == 1);
    if (confirm) {
      ui.modal = null;
      modal.onConfirm();
    } else if (cancel) {
      ui.modal = null;
    } else if (key.type == KeyType.left ||
        key.type == KeyType.right ||
        key.type == KeyType.tab ||
        key.isChar('h') ||
        key.isChar('l')) {
      modal.choice = 1 - modal.choice;
    }
  }

  void _onSettingsKey(SettingsModal modal, Key key) {
    switch (key.type) {
      case KeyType.up:
        modal.cursor = (modal.cursor - 1).clamp(0, SettingsModal.rows - 1);
      case KeyType.down || KeyType.tab:
        modal.cursor = (modal.cursor + 1).clamp(0, SettingsModal.rows - 1);
      case KeyType.char when key.char == 'k':
        modal.cursor = (modal.cursor - 1).clamp(0, SettingsModal.rows - 1);
      case KeyType.char when key.char == 'j':
        modal.cursor = (modal.cursor + 1).clamp(0, SettingsModal.rows - 1);
      case KeyType.enter:
        _applySetting(modal.cursor);
      case KeyType.char when key.char == ' ':
        _applySetting(modal.cursor);
      case KeyType.escape:
        ui.modal = null;
      case KeyType.char when key.char == 'q' || key.char == ',':
        ui.modal = null;
      default:
        break;
    }
  }

  Future<void> _applySetting(int row) async {
    if (row < 3) {
      final language = Language.values[row];
      await settings.setLanguage(language);
      strings = Strings.of(language);
    } else {
      final appearance = Appearance.values[row - 3];
      await settings.setAppearance(appearance);
      palette = Palette.of(appearance);
      _writer.invalidate();
    }
    _title = '';
    render();
  }

  void _pickFolder() {
    final current = ui.workspace.isEmpty
        ? (Platform.environment['HOME'] ??
              Platform.environment['USERPROFILE'] ??
              Directory.current.path)
        : WorkspaceLayout.rootOf(ui.workspace);
    final modal = FolderModal(current);
    if (modal.error != null) modal.open(Directory.current.path);
    ui.modal = modal;
  }

  void _onFolderKey(FolderModal modal, Key key) {
    if (modal.typing) {
      switch (key.type) {
        case KeyType.escape:
          modal
            ..typing = false
            ..error = null;
        case KeyType.enter:
          final typed = FolderModal.expandHome(modal.typed.trim());
          // A relative path is relative to the folder on screen.
          final path = typed.isEmpty || p.isAbsolute(typed)
              ? typed
              : p.join(modal.directory, typed);
          if (path.isEmpty) {
            modal.typing = false;
          } else if (modal.open(path)) {
            modal.typing = false;
          }
        case KeyType.backspace:
          if (modal.typed.isNotEmpty) {
            final runes = modal.typed.runes.toList()..removeLast();
            modal.typed = String.fromCharCodes(runes);
          }
        case KeyType.tab:
          modal.complete();
        case KeyType.ctrl when key.char == 'u':
          modal.typed = '';
        case KeyType.char:
          modal.typed += key.char;
        default:
          break;
      }
      return;
    }

    switch (key.type) {
      case KeyType.escape:
        ui.modal = null;
      case KeyType.up:
        modal.cursor = (modal.cursor - 1).clamp(0, modal.rowCount - 1);
      case KeyType.down:
        modal.cursor = (modal.cursor + 1).clamp(0, modal.rowCount - 1);
      case KeyType.home:
        modal.cursor = 0;
      case KeyType.end:
        modal.cursor = modal.rowCount - 1;
      case KeyType.pageUp:
        modal.cursor = (modal.cursor - 10).clamp(0, modal.rowCount - 1);
      case KeyType.pageDown:
        modal.cursor = (modal.cursor + 10).clamp(0, modal.rowCount - 1);
      case KeyType.left || KeyType.backspace:
        modal.up();
      case KeyType.right:
        _folderEnter(modal, chooseOnFirst: false);
      case KeyType.enter:
        _folderEnter(modal, chooseOnFirst: true);
      case KeyType.tab:
        modal.toggleHidden();
      case KeyType.char:
        switch (key.char) {
          case 'k':
            modal.cursor = (modal.cursor - 1).clamp(0, modal.rowCount - 1);
          case 'j':
            modal.cursor = (modal.cursor + 1).clamp(0, modal.rowCount - 1);
          case 'h':
            modal.up();
          case 'l':
            _folderEnter(modal, chooseOnFirst: false);
          case '.':
            modal.toggleHidden();
          case '/' || ':' || '~':
            modal
              ..typing = true
              ..error = null
              ..typed = key.char == '~'
                  ? '~/'
                  : '${modal.directory}${Platform.pathSeparator}';
          case 'q':
            ui.modal = null;
        }
      default:
        break;
    }
  }

  void _folderEnter(FolderModal modal, {required bool chooseOnFirst}) {
    if (modal.cursor == 0) {
      if (!chooseOnFirst) return;
      ui.modal = null;
      changeWorkspace(modal.directory);
    } else if (modal.cursor == 1) {
      modal.up();
    } else {
      final entry = modal.entries[modal.cursor - 2];
      modal.open(p.join(modal.directory, entry.name));
    }
  }

  // Task actions
  Future<void> _toggle(TaskModel task, int index) async {
    if (index < 0 || index >= task.actions.length) return;
    await _write(
      () => store.setActionDone(
        id: task.id,
        index: index,
        isDone: !task.actions[index].isDone,
      ),
    );
  }

  Future<void> _setStatus(TaskModel task, String status) {
    return _write(() => store.setStatus(id: task.id, status: status));
  }

  void _confirmReopen(TaskModel task) {
    ui.modal = ConfirmModal(
      message: strings('text_confirm_reopen'),
      onConfirm: () => _setStatus(task, 'open'),
    );
  }

  /// Runs a write and shows the stored task at once; the watcher's reload
  /// follows. A failure is shown in the footer (the desktop app's toast).
  Future<void> _write(Future<TaskModel> Function() write) async {
    try {
      final stored = await write();
      board.replace(stored);
      // A closed task leaves the open list (and the other way round): land
      // on the next one, as the desktop app does after its reload.
      if (board.visibleTasks.every((task) => task.id != stored.id)) {
        board.load(board.tasks);
      }
    } on Object catch (error) {
      _toast(_describe(error), isError: true);
    }
    render();
  }

  /// Starts the task's agent in its folder with the English first message
  /// that points at the task file; with [focus], about that one item only.
  Future<void> _connect(TaskModel task, {String? focus}) async {
    final cwd = task.cwd;
    if (cwd == null) return;

    final path = task.location ?? task.id;
    final launch = AgentLaunch(
      agent: task.agent,
      workingDirectory: cwd,
      prompt: focus == null
          ? AgentPrompt.forTask(title: task.title, path: path)
          : AgentPrompt.forItem(title: task.title, path: path, item: focus),
      sessionId: task.sessionId,
    );
    final command = AgentCommand.arguments(launch);

    if (shell.inTmux) {
      try {
        await shell.openTmuxWindow(launch);
        _toast(strings('text_agent_window', {'agent': command.first}));
      } on Object catch (error) {
        _toast(_describe(error), isError: true);
      }
      return;
    }
    try {
      await _attached(() => shell.runAttached(command, workingDirectory: cwd));
      _toast(strings('text_agent_returned', {'agent': command.first}));
    } on ProcessException {
      _toast(
        strings('text_agent_missing', {'agent': command.first}),
        isError: true,
      );
    }
  }

  Future<void> _edit(TaskModel task) async {
    final location = task.location;
    if (location == null) return;
    final command = shell.editorCommand(location);
    try {
      await _attached(() => shell.runAttached(command));
    } on ProcessException {
      _toast(
        strings('text_editor_failed', {'editor': command.first}),
        isError: true,
      );
    }
    // Editors that write in place may not wake the watcher everywhere.
    await _reload();
  }

  Future<void> _openFile(TaskModel task) async {
    final location = task.location;
    if (location != null) await _external(() => shell.open(location), location);
  }

  Future<void> _reveal(TaskModel task) async {
    final location = task.location;
    if (location != null) {
      await _external(() => shell.reveal(location), location);
    }
  }

  Future<void> _openWorkspace() async {
    final workspace = ui.workspace;
    if (workspace.isEmpty) return;
    await _external(() => shell.open(workspace), workspace);
  }

  Future<void> _external(Future<void> Function() action, String path) async {
    try {
      await action();
    } on Object {
      _toast(strings('text_open_failed', {'path': path}), isError: true);
    }
  }

  /// Hands the terminal to a child process and redraws after it.
  Future<T> _attached<T>(Future<T> Function() body) async {
    _suspended = true;
    try {
      return await terminal.suspend(body);
    } finally {
      _suspended = false;
      _writer.invalidate();
      _title = '';
      render();
    }
  }

  /// A readable message for a store error. EPERM / EACCES on macOS is the
  /// privacy protection of Desktop, Documents and the like, which is granted
  /// to the terminal app, not to Handoff.
  String _describe(Object error) {
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      final where = error.path == null ? '' : ': ${error.path}';
      final base = '${error.message}$where';
      if (Platform.isMacOS && (code == 1 || code == 13)) {
        return '$base — macOS blocked access to this folder. Allow your '
            'terminal app under System Settings > Privacy & Security > Files '
            'and Folders (or Full Disk Access), then choose the folder again.';
      }
      return base;
    }
    if (error is ProcessException) {
      return error.message.isEmpty
          ? '${error.executable} failed'
          : error.message;
    }

    return '$error';
  }

  // - Helpers
}
