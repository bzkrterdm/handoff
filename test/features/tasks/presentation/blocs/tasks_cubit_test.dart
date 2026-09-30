import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/features/tasks/domain/entities/task_action.dart';
import 'package:handoff/features/tasks/domain/entities/task_status.dart';
import 'package:handoff/features/tasks/domain/repositories/task_repository.dart';
import 'package:handoff/features/tasks/domain/use_cases/set_action_done.dart';
import 'package:handoff/features/tasks/domain/use_cases/set_task_status.dart';
import 'package:handoff/features/tasks/domain/use_cases/set_workspace.dart';
import 'package:handoff/features/tasks/domain/use_cases/watch_tasks.dart';
import 'package:handoff/features/tasks/presentation/blocs/tasks_cubit.dart';
import 'package:handoff/stack/common/models/failure.dart';
import 'package:handoff/stack/common/models/result.dart';
import 'package:handoff/stack/core/logging/logger.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../fixtures/task_fixtures.dart';

void main() {
  late MockTaskRepository repository;
  late StreamController<void> changes;

  final flutterTask = task(
    id: 'f1',
    project: 'acme/web',
    title: 'Flutter',
    createdAt: DateTime(2026, 9, 29, 10),
    actions: const [TaskAction(text: 'merge')],
  );
  final shiftTask = task(
    id: 's1',
    project: 'acme/api',
    title: 'Shift',
    createdAt: DateTime(2026, 9, 29, 9),
  );
  final doneTask = task(
    id: 'd1',
    project: 'acme/web',
    title: 'Done',
    status: TaskStatus.done,
    createdAt: DateTime(2026, 9, 28),
  );
  final all = [flutterTask, shiftTask, doneTask];
  const ws = '/ws/.handoff/tasks';

  TasksCubit build() {
    final logger = LoggerImpl();

    return TasksCubit(
      WatchTasks(logger, repository),
      SetActionDone(logger, repository),
      SetTaskStatus(logger, repository),
      SetWorkspace(logger, repository),
    );
  }

  setUp(() {
    repository = MockTaskRepository();
    changes = StreamController<void>.broadcast();
    when(() => repository.onChanged).thenAnswer((_) => changes.stream);
    when(
      repository.getWorkspace,
    ).thenAnswer((_) async => Result.success(value: '/ws/.handoff/tasks'));
    when(repository.getAll).thenAnswer((_) async => Result.success(value: all));
  });

  tearDown(() => changes.close());

  group('start', () {
    blocTest<TasksCubit, TasksState>(
      'loads and selects the first open task',
      build: build,
      act: (cubit) => cubit.start(),
      expect: () => [
        const TasksLoading(),
        TasksLoaded(tasks: all, workspace: ws, selectedTaskId: 'f1'),
      ],
    );

    blocTest<TasksCubit, TasksState>(
      'reloads when the store changes and keeps the selection',
      build: build,
      act: (cubit) async {
        await cubit.start();
        await Future<void>.delayed(Duration.zero);
        cubit.selectTask('s1');
        when(
          repository.getAll,
        ).thenAnswer((_) async => Result.success(value: [shiftTask, doneTask]));
        changes.add(null);
        await Future<void>.delayed(Duration.zero);
      },
      skip: 2,
      expect: () => [
        TasksLoaded(tasks: all, workspace: ws, selectedTaskId: 's1'),
        TasksLoaded(
          tasks: [shiftTask, doneTask],
          workspace: ws,
          selectedTaskId: 's1',
        ),
      ],
    );

    blocTest<TasksCubit, TasksState>(
      'reports a failed load',
      build: () {
        when(repository.getAll).thenAnswer(
          (_) async => Result.failure(const Failure(message: 'no folder')),
        );

        return build();
      },
      act: (cubit) => cubit.start(),
      expect: () => const [
        TasksLoading(),
        TasksError(message: 'no folder', workspace: ws),
      ],
    );
  });

  group('selection and filter', () {
    blocTest<TasksCubit, TasksState>(
      'selecting a project lands on its first open task',
      build: build,
      act: (cubit) async {
        await cubit.start();
        await Future<void>.delayed(Duration.zero);
        cubit.selectProject('acme/api');
      },
      skip: 2,
      expect: () => [
        TasksLoaded(
          tasks: all,
          workspace: ws,
          selectedProject: 'acme/api',
          selectedTaskId: 's1',
        ),
      ],
    );

    blocTest<TasksCubit, TasksState>(
      'showing done tasks switches the list and the selection',
      build: build,
      act: (cubit) async {
        await cubit.start();
        await Future<void>.delayed(Duration.zero);
        cubit.showDone(showDone: true);
      },
      skip: 2,
      expect: () => [
        TasksLoaded(
          tasks: all,
          workspace: ws,
          showDone: true,
          selectedTaskId: 'd1',
        ),
      ],
      verify: (cubit) {
        final state = cubit.state as TasksLoaded;
        expect(state.visibleTasks.map((t) => t.id), ['d1']);
        expect(state.projects.map((p) => p.key), ['acme/api', 'acme/web']);
        expect(state.projects.first.openCount, 1);
        expect(state.openCount, 2);
      },
    );
  });

  group('workspace', () {
    blocTest<TasksCubit, TasksState>(
      'changing the folder saves it and reloads',
      build: () {
        when(
          () => repository.setWorkspace('/other'),
        ).thenAnswer((_) async => Result.success(value: '/other'));

        return build();
      },
      act: (cubit) async {
        await cubit.start();
        await Future<void>.delayed(Duration.zero);
        when(
          repository.getWorkspace,
        ).thenAnswer((_) async => Result.success(value: '/other'));
        await cubit.changeWorkspace('/other');
        await Future<void>.delayed(Duration.zero);
      },
      skip: 2,
      expect: () => [
        const TasksLoading(),
        TasksLoaded(tasks: all, workspace: '/other', selectedTaskId: 'f1'),
      ],
      verify: (_) => verify(() => repository.setWorkspace('/other')).called(1),
    );

    blocTest<TasksCubit, TasksState>(
      'a folder that cannot be used shows the error on the first start',
      build: () {
        when(
          repository.getWorkspace,
        ).thenAnswer((_) async => Result.success(value: ''));
        when(repository.getAll).thenAnswer(
          (_) async => Result.failure(const Failure(message: 'No folder')),
        );
        when(() => repository.setWorkspace('/blocked')).thenAnswer(
          (_) async => Result.failure(const Failure(message: 'not permitted')),
        );

        return build();
      },
      act: (cubit) async {
        await cubit.start();
        await Future<void>.delayed(Duration.zero);
        await cubit.changeWorkspace('/blocked');
      },
      skip: 2,
      expect: () => [
        const TasksError(message: 'not permitted', workspace: '/blocked'),
      ],
    );
  });

  group('writes', () {
    blocTest<TasksCubit, TasksState>(
      'applies the stored task right away',
      build: () {
        when(
          () => repository.setActionDone(taskId: 'f1', index: 0, isDone: true),
        ).thenAnswer(
          (_) async => Result.success(
            value: flutterTask.copyWith(
              actions: const [TaskAction(text: 'merge', isDone: true)],
            ),
          ),
        );

        return build();
      },
      act: (cubit) async {
        await cubit.start();
        await Future<void>.delayed(Duration.zero);
        await cubit.setActionDone(taskId: 'f1', index: 0, isDone: true);
      },
      skip: 2,
      verify: (cubit) {
        final state = cubit.state as TasksLoaded;
        expect(state.selectedTask!.areAllActionsDone, isTrue);
      },
    );

    blocTest<TasksCubit, TasksState>(
      'surfaces a failed write without losing the list',
      build: () {
        when(
          () => repository.setStatus(taskId: 'f1', status: TaskStatus.done),
        ).thenAnswer(
          (_) async => Result.failure(const Failure(message: 'read only')),
        );

        return build();
      },
      act: (cubit) async {
        await cubit.start();
        await Future<void>.delayed(Duration.zero);
        await cubit.setStatus(taskId: 'f1', status: TaskStatus.done);
      },
      skip: 2,
      expect: () => [
        TasksLoaded(
          tasks: all,
          workspace: ws,
          selectedTaskId: 'f1',
          lastError: 'read only',
        ),
      ],
    );
  });
}

class MockTaskRepository extends Mock implements TaskRepository {}
