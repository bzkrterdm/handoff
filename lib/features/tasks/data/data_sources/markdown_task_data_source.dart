import 'dart:async';
import 'dart:io';

import 'package:watcher/watcher.dart';

import '../../../../stack/core/logging/logger.dart';
import '../../domain/entities/workspace_layout.dart';
import '../models/task_model.dart';
import 'task_data_source.dart';
import 'task_markdown_parser.dart';
import 'workspace_settings.dart';

/// The local store: one markdown file per task under the workspace's task
/// folder, grouped in sub folders that mirror the project folders
/// (`<workspace>/acme/web/<id>.md`).
///
/// The folder is the source of truth. Agents write files into it, Obsidian
/// may edit them, this app ticks boxes and closes tasks; a directory watcher
/// turns any of those into a [changes] event.
class MarkdownTaskDataSource implements TaskDataSource {
  MarkdownTaskDataSource(this._settings, this._defaultDirectory, this._logger);

  /// Files that are not tasks even though they sit in the folder.
  static const Set<String> _ignoredNames = {'readme.md', 'index.md'};

  /// How many folder levels below a picked folder are searched for tasks.
  static const int _probeDepth = 4;

  /// Quiet period after the last file event before listeners are told, so a
  /// burst of writes (editor save, agent writing two files) reloads once.
  static const Duration _debounce = Duration(milliseconds: 250);

  final WorkspaceSettings _settings;
  final String _defaultDirectory;
  final Logger _logger;

  /// Task id → absolute file path, filled by [readAll].
  final Map<String, String> _paths = {};

  StreamController<void>? _changes;
  StreamSubscription<WatchEvent>? _watch;
  Timer? _debounceTimer;
  String? _watchedDirectory;

  @override
  Future<String> get location async {
    return await _settings.tasksDirectory() ?? _defaultDirectory;
  }

  @override
  Future<void> setLocation(String location) async {
    final directory = resolveTasksDirectory(location);
    await Directory(directory).create(recursive: true);
    await _settings.setTasksDirectory(directory);
    await _restartWatcher(directory);
    _changes?.add(null);
  }

  @override
  Future<List<TaskModel>> readAll() async {
    final directory = await location;
    if (directory.isEmpty) {
      throw const FileSystemException('No workspace folder chosen yet');
    }
    final root = Directory(directory);
    if (!root.existsSync()) {
      throw FileSystemException('Task folder does not exist', directory);
    }
    if (_watchedDirectory != directory && _changes != null) {
      await _restartWatcher(directory);
    }

    final models = <TaskModel>[];
    _paths.clear();
    await for (final entity in root.list(recursive: true)) {
      if (entity is! File || !_isTaskFile(root, entity)) continue;

      final id = _idOf(entity);
      try {
        final model = _resolveCwd(
          root,
          TaskMarkdownParser.parse(
            await entity.readAsString(),
            id: id,
            fallbackProject: _projectOf(root, entity),
            location: entity.path,
          ),
        );
        _paths[model.id] = entity.path;
        models.add(model);
      } on Exception catch (error) {
        // A malformed file is skipped rather than hiding every other task.
        _logger.error(
          'Skipping unreadable task file: ${entity.path} ($error)',
          callerType: runtimeType,
        );
      }
    }

    return models;
  }

  @override
  Stream<void> get changes {
    final controller = _changes ??= StreamController<void>.broadcast(
      onListen: () async => _restartWatcher(await location),
    );

    return controller.stream;
  }

  @override
  Future<TaskModel> setActionDone({
    required String id,
    required int index,
    required bool isDone,
  }) {
    return _rewrite(
      id,
      (content) => TaskMarkdownParser.withActionDone(
        content,
        index: index,
        isDone: isDone,
      ),
    );
  }

  @override
  Future<TaskModel> setStatus({required String id, required String status}) {
    final closedAt = status == 'done' ? DateTime.now() : null;

    return _rewrite(
      id,
      (content) => TaskMarkdownParser.withStatus(
        content,
        status: status,
        closedAt: closedAt,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    _debounceTimer?.cancel();
    await _watch?.cancel();
    _watch = null;
    _watchedDirectory = null;
    await _changes?.close();
    _changes = null;
  }

  // Helpers
  Future<void> _restartWatcher(String directory) async {
    await _watch?.cancel();
    _watch = null;
    _watchedDirectory = directory;
    if (!Directory(directory).existsSync()) return;

    _watch = DirectoryWatcher(directory).events.listen(
      (_) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(_debounce, () => _changes?.add(null));
      },
      onError: (Object error) => _logger.error(
        'Task folder watcher failed: $error',
        callerType: runtimeType,
      ),
    );
  }

  Future<TaskModel> _rewrite(
    String id,
    String Function(String content) edit,
  ) async {
    final path = _paths[id];
    if (path == null) {
      throw StateError('Unknown task id: $id');
    }
    final file = File(path);
    final edited = edit(await file.readAsString());
    await file.writeAsString(edited);
    final root = Directory(await location);

    return _resolveCwd(
      root,
      TaskMarkdownParser.parse(
        edited,
        id: _idOf(file),
        fallbackProject: _projectOf(root, file),
        location: path,
      ),
    );
  }

  /// Turns the task's relative `cwd` (or its project key) into an absolute
  /// folder under the workspace root, so "connect to the agent" starts in
  /// the right place. Falls back to the workspace root when the folder does
  /// not exist.
  TaskModel _resolveCwd(Directory root, TaskModel model) {
    final workspaceRoot = workspaceRootOf(root.absolute.path);
    final relative = model.cwd ?? model.project;
    final candidate = relative.isEmpty
        ? workspaceRoot
        : '$workspaceRoot/$relative';
    final cwd = Directory(candidate).existsSync() ? candidate : workspaceRoot;

    return TaskModel(
      id: model.id,
      project: model.project,
      title: model.title,
      agent: model.agent,
      createdAt: model.createdAt,
      closedAt: model.closedAt,
      status: model.status,
      related: model.related,
      summary: model.summary,
      info: model.info,
      actions: model.actions,
      location: model.location,
      cwd: cwd,
      sessionId: model.sessionId,
    );
  }

  /// See [WorkspaceLayout.taskFolderNames].
  static const List<String> taskFolderNames = WorkspaceLayout.taskFolderNames;

  /// See [WorkspaceLayout.rootOf].
  static String workspaceRootOf(String tasksDirectory) =>
      WorkspaceLayout.rootOf(tasksDirectory);

  /// The task folder for a folder the user picked, which may be a workspace
  /// root or the task folder itself: a known task folder name, or a folder
  /// that already has a task folder below it, or a folder that already holds
  /// task files (front matter, not just any `.md`), is taken as is; any other
  /// folder is a fresh workspace and gets `.handoff/tasks` (created by
  /// [setLocation]).
  static String resolveTasksDirectory(String picked) {
    final path = WorkspaceLayout.trimSlash(picked);
    if (taskFolderNames.any((name) => path.endsWith('/$name'))) return path;
    for (final name in taskFolderNames) {
      if (Directory('$path/$name').existsSync()) return '$path/$name';
    }
    if (_holdsTasks(Directory(path))) return path;

    return '$path/${taskFolderNames.first}';
  }

  /// Whether [directory] already holds at least one real task file. A plain
  /// `.md` does not count: a code repository or notes folder is full of them
  /// and none is a task. The walk skips hidden, `_` and dependency folders
  /// and stops below [_probeDepth], so picking a big folder stays cheap.
  static bool _holdsTasks(Directory directory, [int depth = 0]) {
    if (depth > _probeDepth) return false;

    try {
      for (final entity in directory.listSync(followLinks: false)) {
        final name = entity.uri.pathSegments.lastWhere(
          (segment) => segment.isNotEmpty,
          orElse: () => '',
        );
        if (name.startsWith('.') ||
            name.startsWith('_') ||
            name == 'node_modules') {
          continue;
        }
        if (entity is Directory) {
          if (_holdsTasks(entity, depth + 1)) return true;
        } else if (entity is File &&
            name.toLowerCase().endsWith('.md') &&
            !_ignoredNames.contains(name.toLowerCase()) &&
            TaskMarkdownParser.isTask(entity.readAsStringSync())) {
          return true;
        }
      }
    } on Exception {
      // An unreadable folder or file is not a task folder.
    }

    return false;
  }

  bool _isTaskFile(Directory root, File file) {
    final name = file.uri.pathSegments.last;
    if (!name.toLowerCase().endsWith('.md')) return false;
    if (_ignoredNames.contains(name.toLowerCase())) return false;
    // `_templates/`, `.obsidian/` and the like are not task folders.
    final relative = _relativePath(root, file);

    return !relative
        .split('/')
        .any((segment) => segment.startsWith('_') || segment.startsWith('.'));
  }

  String _idOf(File file) {
    final name = file.uri.pathSegments.last;

    return name.substring(0, name.length - '.md'.length);
  }

  /// The folder path below the task root, i.e. the project key.
  String _projectOf(Directory root, File file) {
    final segments = _relativePath(root, file).split('/')..removeLast();

    return segments.isEmpty ? '' : segments.join('/');
  }

  String _relativePath(Directory root, File file) {
    final rootPath = root.absolute.path.replaceAll(RegExp(r'/+$'), '');
    final path = file.absolute.path;

    return path.startsWith('$rootPath/')
        ? path.substring(rootPath.length + 1)
        : path;
  }

  // - Helpers
}
