import 'dart:io';

import 'package:handoff_core/handoff_core.dart';
import 'package:path/path.dart' as p;

/// Everything that leaves the app: opening files in other apps, the file
/// manager, an editor or a coding agent in this terminal. One class per
/// concern would be more ceremony than these few calls need.
abstract class SystemShell {
  /// Opens [path] with its default application.
  Future<void> open(String path);

  /// Shows [path] in the file manager (selected, where the platform can).
  Future<void> reveal(String path);

  /// The command that edits [path] in the terminal: `$VISUAL`, `$EDITOR`,
  /// or a platform default.
  List<String> editorCommand(String path);

  /// Runs [command] attached to this terminal and waits for it. Throws a
  /// [ProcessException] when the program cannot be started.
  Future<int> runAttached(List<String> command, {String? workingDirectory});

  /// Whether the app runs inside tmux, where an agent gets its own window
  /// instead of taking over this one.
  bool get inTmux;

  /// Starts [launch] in a new tmux window.
  Future<void> openTmuxWindow(AgentLaunch launch);
}

class SystemShellImpl implements SystemShell {
  SystemShellImpl([Map<String, String>? environment])
    : _env = environment ?? Platform.environment;

  final Map<String, String> _env;

  @override
  bool get inTmux => (_env['TMUX'] ?? '').isNotEmpty;

  @override
  Future<void> open(String path) async {
    if (Platform.isMacOS) return _run('open', [path]);
    // `start` is a cmd built-in; the empty argument is the window title.
    if (Platform.isWindows) return _run('cmd', ['/c', 'start', '', path]);

    return _detached('xdg-open', [path]);
  }

  @override
  Future<void> reveal(String path) async {
    if (Platform.isMacOS) return _run('open', ['-R', path]);
    if (Platform.isWindows) {
      // Explorer exits with 1 even when it worked, so the code is ignored.
      await Process.run('explorer', ['/select,$path']);
      return;
    }
    // There is no portable "select this file" on Linux: open its folder.
    final folder = FileSystemEntity.isDirectorySync(path)
        ? path
        : p.dirname(path);

    return _detached('xdg-open', [folder]);
  }

  @override
  List<String> editorCommand(String path) {
    for (final name in ['VISUAL', 'EDITOR']) {
      final value = (_env[name] ?? '').trim();
      if (value.isNotEmpty) {
        return [...value.split(RegExp(r'\s+')), path];
      }
    }
    if (Platform.isWindows) return ['notepad', path];

    return [_onPath('nano') ? 'nano' : 'vi', path];
  }

  @override
  Future<int> runAttached(
    List<String> command, {
    String? workingDirectory,
  }) async {
    final process = await Process.start(
      command.first,
      command.sublist(1),
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.inheritStdio,
      // `claude` and `codex` are `.cmd` shims on Windows.
      runInShell: Platform.isWindows,
    );

    return process.exitCode;
  }

  @override
  Future<void> openTmuxWindow(AgentLaunch launch) {
    return _run('tmux', [
      'new-window',
      '-c',
      launch.workingDirectory,
      '-n',
      launch.agent,
      AgentCommand.shellLine(launch),
    ]);
  }

  // Helpers
  Future<void> _run(String program, List<String> arguments) async {
    final result = await Process.run(program, arguments);
    if (result.exitCode != 0) {
      throw ProcessException(
        program,
        arguments,
        '${result.stderr}'.trim(),
        result.exitCode,
      );
    }
  }

  Future<void> _detached(String program, List<String> arguments) async {
    await Process.start(program, arguments, mode: ProcessStartMode.detached);
  }

  bool _onPath(String program) {
    final separator = Platform.isWindows ? ';' : ':';
    for (final folder in (_env['PATH'] ?? '').split(separator)) {
      if (folder.isNotEmpty && File(p.join(folder, program)).existsSync()) {
        return true;
      }
    }

    return false;
  }

  // - Helpers
}
