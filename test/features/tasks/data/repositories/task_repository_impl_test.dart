import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/features/tasks/data/data_sources/task_data_source.dart';
import 'package:handoff/features/tasks/data/models/task_model.dart';
import 'package:handoff/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:handoff/features/tasks/domain/entities/task_status.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late MockTaskDataSource dataSource;
  late TaskRepositoryImpl repository;

  final older = TaskModel(
    id: 'a',
    project: 'p',
    title: 'A',
    agent: 'claude',
    createdAt: DateTime(2026, 9, 1),
    status: 'open',
  );
  final newer = TaskModel(
    id: 'b',
    project: 'p',
    title: 'B',
    agent: 'codex',
    createdAt: DateTime(2026, 9, 2),
    status: 'done',
  );

  setUp(() {
    dataSource = MockTaskDataSource();
    repository = TaskRepositoryImpl(dataSource);
  });

  group('getAll', () {
    test('maps models to entities, newest first', () async {
      when(dataSource.readAll).thenAnswer((_) async => [older, newer]);

      final result = await repository.getAll();

      expect(result.value!.map((task) => task.id), ['b', 'a']);
      expect(result.value![0].status, TaskStatus.done);
    });

    test('turns a missing folder into a failure', () async {
      when(dataSource.readAll).thenThrow(
        const FileSystemException('Task folder does not exist', '/nope'),
      );

      final result = await repository.getAll();

      expect(result.isSuccessful, isFalse);
      expect(result.error!.message, 'Task folder does not exist: /nope');
    });
  });

  group('writes', () {
    test('setActionDone returns the stored task', () async {
      when(
        () => dataSource.setActionDone(id: 'a', index: 0, isDone: true),
      ).thenAnswer((_) async => older);

      final result = await repository.setActionDone(
        taskId: 'a',
        index: 0,
        isDone: true,
      );

      expect(result.value!.id, 'a');
    });

    test('setStatus passes the status key and maps errors', () async {
      when(
        () => dataSource.setStatus(id: 'a', status: 'done'),
      ).thenThrow(StateError('Unknown task id: a'));

      final result = await repository.setStatus(
        taskId: 'a',
        status: TaskStatus.done,
      );

      expect(result.isSuccessful, isFalse);
      expect(result.error!.message, contains('Unknown task id'));
    });
  });
}

class MockTaskDataSource extends Mock implements TaskDataSource {}
