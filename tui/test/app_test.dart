import 'dart:async';
import 'dart:io';

import 'package:handoff_core/handoff_core.dart';
import 'package:handoff_tui/handoff_tui.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fake_terminal.dart';

/// Drives the whole app against a copy of the repository's example
/// workspace, through a fake terminal and a fake operating system.
void main() {
  late Directory root;
  late String workspace;
  late TuiSettings settings;
  late MarkdownTaskDataSource store;
  late FakeTerminal terminal;
  late FakeShell shell;
  late HandoffApp app;
  late Future<void> running;

  String taskFile(String name) =>
      p.join(workspace, '.handoff', 'tasks', 'acme', 'api', name);
  const rateLimiting = '20260929-1420-api-rate-limiting.md';

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 120));

  Future<void> start({String? folder, int width = 140, int height = 40}) async {
    terminal = FakeTerminal(width: width, height: height);
    app = HandoffApp(
      terminal: terminal,
      store: store,
      settings: settings,
      shell: shell,
      initialFolder: folder,
      toastDuration: const Duration(seconds: 30),
    );
    running = app.run();
    await settle();
  }

  String screen() => app.lastFrame!.toPlainText();

  setUp(() async {
    root = Directory.systemTemp.createTempSync('handoff_tui');
    workspace = p.join(root.path, 'example');
    _copy(Directory(p.join('..', 'example')), Directory(workspace));
    Directory(p.join(workspace, 'acme', 'api')).createSync(recursive: true);
    settings = TuiSettings(File(p.join(root.path, 'tui.json')));
    await settings.setLanguage(Language.en);
    store = MarkdownTaskDataSource(settings, '');
    shell = FakeShell();
  });

  tearDown(() async {
    app.quit();
    await running;
    await store.dispose();
    root.deleteSync(recursive: true);
  });

  test('first start asks for a folder, then shows its tasks', () async {
    await start();
    expect(screen(), contains('Welcome to Handoff'));

    await app.changeWorkspace(workspace);
    await settle();
    expect(screen(), contains('Rate limiting for the public API'));
    expect(await settings.tasksDirectory(), endsWith('tasks'));
    expect(terminal.title, 'Handoff (4)');
  });

  test('a folder on the command line is remembered', () async {
    await start(folder: workspace);
    expect(screen(), contains('All projects'));
    expect(
      await settings.tasksDirectory(),
      p.join(workspace, '.handoff', 'tasks'),
    );
  });

  test('space ticks the item under the cursor in the file', () async {
    await start(folder: workspace);
    terminal.press(KeyType.tab); // list → details
    await settle();
    terminal.type(' ');
    await settle();

    final content = File(taskFile(rateLimiting)).readAsStringSync();
    expect(content, contains('- [x] Apply the migration to staging'));
    expect(screen(), contains('2/4 done'));
  });

  test('a digit ticks that item from the list', () async {
    await start(folder: workspace);
    terminal.type('1');
    await settle();

    final content = File(taskFile(rateLimiting)).readAsStringSync();
    expect(content, contains('- [ ] Review PR #212'));
  });

  test('d closes the task, u reopens it after a confirmation', () async {
    await start(folder: workspace);
    terminal.type('d');
    await settle();
    expect(
      File(taskFile(rateLimiting)).readAsStringSync(),
      contains('status: done'),
    );
    expect(screen(), isNot(contains('▌ Rate limiting')));

    terminal.type('t'); // done list
    await settle();
    final done = app.board.visibleTasks.map((t) => t.id);
    expect(done, contains('20260929-1420-api-rate-limiting'));
    app.board.selectTask('20260929-1420-api-rate-limiting');
    terminal.type('u');
    await settle();
    expect(screen(), contains('Reopen this task?'));
    terminal.type('y');
    await settle();
    expect(
      File(taskFile(rateLimiting)).readAsStringSync(),
      contains('status: open'),
    );
  });

  test(
    'a connects the agent in the task folder, resuming its session',
    () async {
      await start(folder: workspace);
      terminal.type('a');
      await settle();

      expect(terminal.suspends, 1);
      final command = shell.attached.single;
      expect(command.take(3), ['claude', '--resume', isNotEmpty]);
      expect(command.last, startsWith('We are continuing a Handoff task'));
      expect(command.last, contains(rateLimiting));
      expect(shell.attachedIn.single, p.join(workspace, 'acme', 'api'));
    },
  );

  test('i asks about the item under the cursor only', () async {
    await start(folder: workspace);
    terminal.press(KeyType.tab);
    await settle();
    terminal.type('i');
    await settle();

    expect(
      shell.attached.single.last,
      contains('this one checklist item only: "Apply the migration'),
    );
  });

  test('inside tmux the agent gets its own window', () async {
    shell.tmux = true;
    await start(folder: workspace);
    terminal.type('a');
    await settle();

    expect(terminal.suspends, 0);
    expect(shell.calls.single, startsWith("tmux cd '"));
  });

  test('a missing agent is reported, not a crash', () async {
    shell.failAttach = true;
    await start(folder: workspace);
    terminal.type('a');
    await settle();

    expect(screen(), contains('is not installed or not on PATH'));
  });

  test('e edits, o opens, f reveals the task file', () async {
    await start(folder: workspace);
    terminal.type('e');
    await settle();
    terminal.type('o');
    await settle();
    terminal.type('f');
    await settle();

    expect(shell.attached.single, ['editor', taskFile(rateLimiting)]);
    expect(shell.calls, [
      'open ${taskFile(rateLimiting)}',
      'reveal ${taskFile(rateLimiting)}',
    ]);
  });

  test('a file an agent writes shows up without a key press', () async {
    await start(folder: workspace);
    // The watcher scans the folder before it reports changes.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    File(taskFile('20261001-0900-new.md')).writeAsStringSync(
      '---\ntitle: Freshly written\nagent: codex\nstatus: open\n'
      'created: 2026-10-01T09:00:00+02:00\n---\n',
    );
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    expect(screen(), contains('Freshly written'));
  });

  test('an unreadable folder shows the error with its path', () async {
    final file = File(p.join(root.path, 'not-a-folder'))..writeAsStringSync('');
    await start();
    await app.changeWorkspace(file.path);
    await settle();

    expect(screen(), contains('Could not read the tasks'));
  });

  test('settings switch the language and are kept', () async {
    await start(folder: workspace);
    terminal.type(',');
    await settle();
    expect(screen(), contains('Settings'));
    // The cursor starts on the current language (English): one down is
    // Türkçe.
    terminal
      ..press(KeyType.down)
      ..press(KeyType.enter);
    await settle();
    terminal.press(KeyType.escape);
    await settle();

    expect(screen(), contains('Senden beklenenler'));
    expect(settings.language, Language.tr);
  });

  test('a narrow window shows one pane and Esc goes back', () async {
    await start(folder: workspace, width: 60, height: 24);
    expect(screen(), contains('Open 4'));
    terminal.press(KeyType.enter);
    await settle();
    expect(screen(), contains('Expected from you'));
    expect(screen(), isNot(contains('Open 4')));
    terminal.press(KeyType.escape);
    await settle();
    expect(screen(), contains('Open 4'));
  });

  test('the folder picker opens a typed path and uses it', () async {
    await start();
    terminal.press(KeyType.enter);
    await settle();
    expect(screen(), contains('Use this folder'));
    terminal.type('/');
    terminal.keyController.add(const Key(KeyType.ctrl, 'u'));
    terminal.type('$workspace\r');
    await settle();
    terminal.press(KeyType.enter);
    await settle();

    expect(screen(), contains('Rate limiting for the public API'));
  });

  test('q leaves full-screen mode', () async {
    await start(folder: workspace);
    terminal.type('q');
    await running;
    expect(terminal.active, isFalse);
  });
}

/// Copies a folder tree (no `cp -R` on Windows).
void _copy(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final entity in from.listSync()) {
    final target = p.join(to.path, p.basename(entity.path));
    if (entity is Directory) {
      _copy(entity, Directory(target));
    } else if (entity is File) {
      entity.copySync(target);
    }
  }
}
