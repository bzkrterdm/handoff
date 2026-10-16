import 'dart:async';
import 'dart:io';

import 'package:handoff_core/handoff_core.dart';
import 'package:handoff_tui/handoff_tui.dart';

const String _version = '0.2.0';

const String _usage = '''
Handoff — the tasks your coding agents leave you, in the terminal.

Usage: handoff [options] [folder]

  folder            Workspace folder (a .handoff/tasks folder is created
                    inside) or an existing task folder. Remembered for the
                    next start. Without it, the last folder is opened, or
                    you are asked for one.

Options:
  --config <file>   Settings file (default: ~/.config/handoff/tui.json,
                    %APPDATA%\\handoff\\tui.json on Windows)
  -h, --help        Show this help
  -v, --version     Show the version

Environment:
  HANDOFF_TASKS_DIR Task folder to use when none was chosen yet
  EDITOR, VISUAL    Editor for "e" (edit the task file)

Press ? inside the app for the keys.''';

Future<void> main(List<String> arguments) async {
  String? folder;
  String? config;
  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];
    switch (argument) {
      case '-h' || '--help':
        stdout.writeln(_usage);
        return;
      case '-v' || '--version':
        stdout.writeln('handoff $_version');
        return;
      case '--config':
        if (i + 1 >= arguments.length) return _fail('--config needs a file');
        config = arguments[++i];
      default:
        if (argument.startsWith('-')) return _fail('Unknown option $argument');
        folder = argument;
    }
  }

  if (!StdTerminal.isInteractive) {
    return _fail('handoff needs an interactive terminal.');
  }

  final settings = config == null
      ? TuiSettings.standard()
      : TuiSettings(File(config));
  final log = <String>[];
  final store = MarkdownTaskDataSource(
    settings,
    Platform.environment['HANDOFF_TASKS_DIR'] ?? '',
    log.add,
  );
  final terminal = StdTerminal();
  final app = HandoffApp(
    terminal: terminal,
    store: store,
    settings: settings,
    shell: SystemShellImpl(),
    initialFolder: folder,
  );

  Object? failure;
  StackTrace? failureStack;
  await runZonedGuarded(app.run, (error, stack) {
    failure = error;
    failureStack = stack;
    app.quit();
  });
  await terminal.close();
  await store.dispose();
  if (failure != null) {
    stderr
      ..writeln('handoff: $failure')
      ..writeln(failureStack);
    exit(1);
  }
  exit(0);
}

void _fail(String message) {
  stderr
    ..writeln('handoff: $message')
    ..writeln('Run handoff --help for usage.');
  exitCode = 2;
}
