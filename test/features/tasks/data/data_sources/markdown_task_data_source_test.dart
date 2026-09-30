import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/features/tasks/data/data_sources/markdown_task_data_source.dart';
import 'package:handoff/features/tasks/data/data_sources/workspace_settings.dart';
import 'package:handoff/stack/core/logging/logger.dart';

import '../../../../fixtures/task_fixtures.dart';

void main() {
  late Directory parent;
  late Directory root;
  late MarkdownTaskDataSource source;

  setUp(() async {
    parent = await Directory.systemTemp.createTemp('handoff_tasks_');
    root = await Directory(
      '${parent.path}/.handoff/tasks',
    ).create(recursive: true);
    source = MarkdownTaskDataSource(_MemorySettings(), root.path, LoggerImpl());
    await _write(root, 'README.md', '# not a task');
    await _write(root, '_templates/task.md', '# template, not a task');
    await _write(
      root,
      'acme/api/20260929-1500-api-hiz-siniri.md',
      sampleTaskFile,
    );
    await _write(
      root,
      'acme/web/20260928-1000-flutter-pr64.md',
      '# PR 64\n\n## Senden beklenenler\n\n- [ ] merge\n',
    );
    await _write(root, 'broken/empty.md', '');
  });

  tearDown(() async {
    await source.dispose();
    await parent.delete(recursive: true);
  });

  test(
    'reads every task file and derives the project from the folder',
    () async {
      final models = await source.readAll();
      final byId = {for (final model in models) model.id: model};

      expect(byId.keys, {
        '20260929-1500-api-hiz-siniri',
        '20260928-1000-flutter-pr64',
        'empty',
      });
      expect(byId['20260928-1000-flutter-pr64']!.project, 'acme/web');
      expect(byId['20260928-1000-flutter-pr64']!.title, 'PR 64');
      expect(byId['empty']!.project, 'broken');
      expect(
        byId['20260929-1500-api-hiz-siniri']!.location,
        endsWith('/acme/api/20260929-1500-api-hiz-siniri.md'),
      );
    },
  );

  group('outside a task folder', () {
    late Directory raw;
    late MarkdownTaskDataSource rawSource;

    setUp(() async {
      // A folder picked by an older version: a repository, not `.handoff/tasks`.
      raw = await Directory.systemTemp.createTemp('handoff_raw_');
      await _write(raw, 'api/docs/guide.md', '# guide\n');
      await _write(raw, 'api/CHANGELOG.md', '# changes\n');
      await _write(raw, 'api/real.md', sampleTaskFile);
      await _write(raw, 'web/node_modules/pkg/task.md', sampleTaskFile);
      await _write(raw, 'web/build/out/task.md', sampleTaskFile);
      await _write(raw, 'web/.git/notes.md', sampleTaskFile);
      rawSource = MarkdownTaskDataSource(
        _MemorySettings(),
        raw.path,
        LoggerImpl(),
      );
    });

    tearDown(() async {
      await rawSource.dispose();
      await raw.delete(recursive: true);
    });

    test('only files with task front matter are tasks', () async {
      final models = await rawSource.readAll();

      expect(models.map((m) => m.id), ['20260929-1500-api-hiz-siniri']);
    });
  });

  test('does not read below the depth limit or into skipped folders', () async {
    await _write(root, 'a/b/c/d/e/f/g/h/i/deep.md', '# too deep\n');
    await _write(root, 'node_modules/pkg/dep.md', '# a dependency\n');

    final ids = (await source.readAll()).map((m) => m.id);

    expect(ids, isNot(contains('deep')));
    expect(ids, isNot(contains('dep')));
  });

  test(
    'picking one project folder after its parent shows only that one',
    () async {
      // A holds B and C, both repositories full of markdown; only B has tasks.
      final a = await Directory.systemTemp.createTemp('handoff_a_');
      addTearDown(() => a.delete(recursive: true));
      for (final project in ['b', 'c']) {
        await _write(a, '$project/README.md', '# readme\n');
        await _write(a, '$project/docs/guide.md', '# guide\n');
        await _write(a, '$project/node_modules/x/readme.md', '# dep\n');
      }
      await _write(a, 'b/.handoff/tasks/b/mine.md', sampleTaskFile);
      final settings = _MemorySettings();
      final picking = MarkdownTaskDataSource(settings, '', LoggerImpl());
      addTearDown(picking.dispose);

      await picking.setLocation(a.path);
      expect(settings.path, '${a.path}/.handoff/tasks');
      expect(await picking.readAll(), isEmpty);

      await picking.setLocation('${a.path}/b');
      expect(settings.path, '${a.path}/b/.handoff/tasks');
      expect((await picking.readAll()).map((m) => m.id), [
        '20260929-1500-api-hiz-siniri',
      ]);
    },
  );

  test('resolves the agent folder under the workspace root', () async {
    // Workspace layout: <root>/_hub/tasks; the project folder exists for one task.
    final ws = await Directory.systemTemp.createTemp('handoff_ws_');
    addTearDown(() => ws.delete(recursive: true));
    final tasksDir = Directory('${ws.path}/_hub/tasks');
    await Directory('${ws.path}/acme/api').create(recursive: true);
    await _write(tasksDir, 'acme/api/a.md', sampleTaskFile);
    await _write(tasksDir, 'acme/web/b.md', '# b\n');
    final wsSource = MarkdownTaskDataSource(
      _MemorySettings(),
      tasksDir.path,
      LoggerImpl(),
    );
    addTearDown(wsSource.dispose);

    final byId = {for (final m in await wsSource.readAll()) m.id: m};

    expect(MarkdownTaskDataSource.workspaceRootOf(tasksDir.path), ws.path);
    // The sample's front matter carries its own id.
    final sample = byId['20260929-1500-api-hiz-siniri']!;
    expect(sample.cwd, '${ws.path}/acme/api');
    expect(sample.sessionId, '8c1f0d3e-1111-4222-8333-444455556666');
    // Missing project folder falls back to the root.
    expect(byId['b']!.cwd, ws.path);
  });

  test('throws when the folder is missing', () async {
    final missing = MarkdownTaskDataSource(
      _MemorySettings(),
      '${root.path}/nope',
      LoggerImpl(),
    );

    expect(missing.readAll, throwsA(isA<FileSystemException>()));
  });

  test('ticks a box on disk and returns the updated task', () async {
    await source.readAll();

    final model = await source.setActionDone(
      id: '20260929-1500-api-hiz-siniri',
      index: 0,
      isDone: true,
    );

    expect(model.actions[0].isDone, isTrue);
    final onDisk = await File(
      '${root.path}/acme/api/'
      '20260929-1500-api-hiz-siniri.md',
    ).readAsString();
    expect(onDisk, contains("- [x] Migration'ı v2'ye uygula"));
  });

  test('closes a task on disk', () async {
    await source.readAll();

    final model = await source.setStatus(
      id: '20260928-1000-flutter-pr64',
      status: 'done',
    );

    expect(model.status, 'done');
    expect(model.closedAt, isNotNull);
    final reread = await source.readAll();
    expect(
      reread.firstWhere((m) => m.id == '20260928-1000-flutter-pr64').status,
      'done',
    );
  });

  test('rejects an unknown id', () async {
    await source.readAll();

    expect(
      () => source.setStatus(id: 'nope', status: 'done'),
      throwsStateError,
    );
  });

  test('a saved location wins over the default and can be changed', () async {
    final otherParent = await Directory.systemTemp.createTemp('handoff_other_');
    addTearDown(() => otherParent.delete(recursive: true));
    final other = Directory('${otherParent.path}/.handoff/tasks');
    await _write(other, 'p/only.md', '# only\n');
    final settings = _MemorySettings()..path = other.path;
    final switching = MarkdownTaskDataSource(settings, root.path, LoggerImpl());
    addTearDown(switching.dispose);

    expect(await switching.location, other.path);
    expect((await switching.readAll()).single.id, 'only');

    await switching.setLocation(root.path);
    expect(settings.path, root.path);
    expect((await switching.readAll()).length, 3);
  });

  test('an empty location is a first start, not a missing folder', () async {
    final fresh = MarkdownTaskDataSource(_MemorySettings(), '', LoggerImpl());
    addTearDown(fresh.dispose);

    await expectLater(
      fresh.readAll,
      throwsA(
        isA<FileSystemException>().having(
          (e) => e.message,
          'message',
          contains('No workspace folder'),
        ),
      ),
    );
  });

  group('resolveTasksDirectory', () {
    late Directory ws;

    setUp(() async {
      ws = await Directory.systemTemp.createTemp('handoff_ws_');
    });

    tearDown(() => ws.delete(recursive: true));

    test('keeps a task folder that is named as one', () {
      for (final name in MarkdownTaskDataSource.taskFolderNames) {
        final picked = '${ws.path}/$name/';
        expect(
          MarkdownTaskDataSource.resolveTasksDirectory(picked),
          '${ws.path}/$name',
        );
      }
    });

    test('finds an existing task folder under a workspace root', () async {
      await Directory('${ws.path}/_hub/tasks').create(recursive: true);

      expect(
        MarkdownTaskDataSource.resolveTasksDirectory(ws.path),
        '${ws.path}/_hub/tasks',
      );
    });

    test('keeps a folder that already holds task files', () async {
      await _write(ws, 'api/one.md', sampleTaskFile);

      expect(MarkdownTaskDataSource.resolveTasksDirectory(ws.path), ws.path);
    });

    test(
      'does not mistake a folder of plain notes for a task folder',
      () async {
        await _write(ws, 'docs/guide.md', '# a guide\n');
        await _write(ws, 'notes/todo.md', '# todo\n\n- [ ] something\n');
        await _write(ws, 'node_modules/pkg/task.md', sampleTaskFile);

        expect(
          MarkdownTaskDataSource.resolveTasksDirectory(ws.path),
          '${ws.path}/.handoff/tasks',
        );
      },
    );

    test('gives a fresh workspace .handoff/tasks and creates it', () async {
      await Directory('${ws.path}/api/src').create(recursive: true);
      final settings = _MemorySettings();
      final fresh = MarkdownTaskDataSource(settings, '', LoggerImpl());
      addTearDown(fresh.dispose);

      await fresh.setLocation(ws.path);

      expect(settings.path, '${ws.path}/.handoff/tasks');
      expect(Directory('${ws.path}/.handoff/tasks').existsSync(), isTrue);
      expect(await fresh.readAll(), isEmpty);
      expect(MarkdownTaskDataSource.workspaceRootOf(settings.path!), ws.path);
    });
  });

  test('reports a change after a file is written', () async {
    final first = source.changes.first;
    // The watcher needs a moment to arm on macOS before it sees events.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _write(root, 'handoff/new.md', '# new\n');

    await expectLater(first.timeout(const Duration(seconds: 10)), completes);
  });
}

class _MemorySettings implements WorkspaceSettings {
  String? path;

  @override
  Future<String?> tasksDirectory() async => path;

  @override
  Future<void> setTasksDirectory(String path) async => this.path = path;
}

Future<void> _write(Directory root, String relative, String content) async {
  final file = File('${root.path}/$relative');
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
