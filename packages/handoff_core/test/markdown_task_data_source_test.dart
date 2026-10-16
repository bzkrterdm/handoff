import 'dart:io';

import 'package:handoff_core/handoff_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _Settings implements WorkspaceSettings {
  String? value;

  @override
  Future<void> setTasksDirectory(String path) async => value = path;

  @override
  Future<String?> tasksDirectory() async => value;
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('handoff_core'));
  tearDown(() => root.deleteSync(recursive: true));

  test('project keys use "/" and the working folder is resolved', () async {
    final tasks = Directory(
      p.join(root.path, '.handoff', 'tasks', 'acme', 'web'),
    )..createSync(recursive: true);
    Directory(p.join(root.path, 'acme', 'web')).createSync(recursive: true);
    File(p.join(tasks.path, 't1.md')).writeAsStringSync(
      '---\nstatus: open\nagent: claude\n---\n## Actions\n- [ ] a\n',
    );
    final log = <String>[];
    final store = MarkdownTaskDataSource(_Settings(), '', log.add);
    await store.setLocation(root.path);

    final models = await store.readAll();

    expect(models.single.project, 'acme/web');
    expect(models.single.cwd, p.join(root.absolute.path, 'acme', 'web'));
    expect(log, isEmpty);
    await store.dispose();
  });

  test('reports an unreadable file to the log and keeps the rest', () async {
    final tasks = Directory(p.join(root.path, '.handoff', 'tasks'))
      ..createSync(recursive: true);
    File(
      p.join(tasks.path, 'ok.md'),
    ).writeAsStringSync('---\nstatus: open\nagent: codex\n---\n');
    File(p.join(tasks.path, 'bad.md')).writeAsBytesSync([0xC3, 0x28]);
    final log = <String>[];
    final store = MarkdownTaskDataSource(_Settings(), tasks.path, log.add);

    final models = await store.readAll();

    expect(models.map((m) => m.id), ['ok']);
    expect(log.single, contains('bad.md'));
    await store.dispose();
  });
}
