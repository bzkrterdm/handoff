import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/features/tasks/domain/entities/handoff_task.dart';
import 'package:handoff/features/tasks/domain/entities/task_snapshot.dart';
import 'package:handoff/features/tasks/domain/repositories/task_repository.dart';
import 'package:handoff/features/tasks/domain/use_cases/watch_tasks.dart';
import 'package:handoff/stack/common/models/failure.dart';
import 'package:handoff/stack/common/models/result.dart';
import 'package:handoff/stack/core/logging/logger.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../fixtures/task_fixtures.dart';

class _MockRepository extends Mock implements TaskRepository {}

void main() {
  late _MockRepository repository;

  setUp(() {
    repository = _MockRepository();
    when(() => repository.onChanged).thenAnswer((_) => const Stream.empty());
  });

  test(
    'a slow load of the old folder cannot overwrite the new folder',
    () async {
      final slow = Completer<Result<List<HandoffTask>, Failure>>();
      final oldTask = task(id: 'old', project: 'a', title: 'Old');
      final newTask = task(id: 'new', project: 'b', title: 'New');
      var calls = 0;
      when(() => repository.getWorkspace()).thenAnswer(
        (_) async => Result.success(value: calls == 0 ? '/a' : '/b'),
      );
      when(() => repository.getAll()).thenAnswer((_) {
        // The first call (folder A) is still reading when folder B is chosen.
        if (calls++ == 0) return slow.future;

        return Future.value(Result.success(value: [newTask]));
      });
      final watch = WatchTasks(LoggerImpl(), repository);
      final seen = <TaskSnapshot>[];

      final first = watch().listen((r) => seen.add(_snapshot(r)));
      await Future<void>.delayed(Duration.zero);
      await first.cancel();
      final second = watch().listen((r) => seen.add(_snapshot(r)));
      await Future<void>.delayed(Duration.zero);
      slow.complete(Result.success(value: [oldTask]));
      await Future<void>.delayed(Duration.zero);
      await second.cancel();

      expect(seen.map((s) => s.workspace), ['/b']);
      expect(seen.single.tasks.map((t) => t.id), ['new']);
    },
  );
}

TaskSnapshot _snapshot(Result<TaskSnapshot, Failure> result) {
  return (result as Success<TaskSnapshot, Failure>).value!;
}
